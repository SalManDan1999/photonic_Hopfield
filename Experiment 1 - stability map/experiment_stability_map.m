%% experiment_retrieval_threshold.m 
% In this experiment we test how many patterns we can store before they become unstable
% states. We do so for different load fractions and different values of the emergent 
% parameter M.

clearvars -except hdevice dll_name
clc;

%% ========================== OUTPUT FOLDER =====================================================
timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
run_dir = fullfile('runs', ['run_' timestamp]);
mkdir(run_dir);                                     % this is the directory where we save results
results_file = fullfile(run_dir, 'results.mat');

fprintf('\nAll outputs will be saved in: %s\n', run_dir);

%% ===============================================================================================
%% ====================== EXPERIMENT PARAMETERS ==========================================
%% ==============================================================================

N_x=14; N_y=14;             % 1. Define number of neurons along x and y directions
Nneur=N_x*N_y;
ref_disk_diameter = 70;     % 2. Fix diameter of DMD reference disk; this will also define the size
                            % of small_frame, which carries the disk+mnist square in the 

if ref_disk_diameter < N_x || ref_disk_diameter < N_y
    error("\nERROR! Reference disk diameter must be larger than the neuron square.")
end

alpha = [
    0.006 0.016 0.024 0.032 0.038 0.042 0.048 0.052 0.054 0.060 0.064 0.072 0.08 0.1 0.15 0.2 0.25 0.3;
    0.006 0.016 0.024 0.032 0.038 0.042 0.048 0.052 0.054 0.060 0.064 0.072 0.08 0.1 0.15 0.2 0.25 0.3;
    0.01 0.03 0.05 0.07 0.09 0.11 0.13 0.15 0.17 0.19 0.21 0.23 0.25 0.26 0.27 0.28 0.29 0.3;
    0.01 0.03 0.05 0.07 0.09 0.11 0.13 0.15 0.17 0.19 0.21 0.23 0.25 0.26 0.27 0.28 0.29 0.3;
    0.01 0.03 0.05 0.07 0.09 0.11 0.13 0.15 0.17 0.19 0.21 0.23 0.25 0.26 0.27 0.28 0.29 0.3;
    0.01 0.03 0.05 0.07 0.09 0.11 0.13 0.15 0.17 0.19 0.21 0.23 0.25 0.26 0.27 0.28 0.29 0.3;
    0.01 0.03 0.05 0.07 0.09 0.11 0.13 0.15 0.17 0.19 0.21 0.23 0.25 0.26 0.27 0.28 0.29 0.3;
    0.01 0.03 0.05 0.07 0.09 0.11 0.13 0.15 0.17 0.19 0.21 0.23 0.25 0.26 0.27 0.28 0.29 0.3;
    0.01 0.03 0.05 0.07 0.09 0.11 0.13 0.15 0.17 0.19 0.21 0.23 0.25 0.26 0.27 0.28 0.29 0.3;
    0.01 0.03 0.05 0.07 0.09 0.11 0.13 0.15 0.17 0.19 0.21 0.23 0.25 0.26 0.27 0.28 0.29 0.3;
    0.01 0.03 0.05 0.07 0.09 0.11 0.13 0.15 0.17 0.19 0.21 0.23 0.25 0.26 0.27 0.28 0.29 0.3;
    0.01 0.03 0.05 0.07 0.09 0.11 0.13 0.15 0.17 0.19 0.21 0.23 0.25 0.26 0.27 0.28 0.29 0.3;
    0.01 0.03 0.05 0.07 0.09 0.11 0.13 0.15 0.17 0.19 0.21 0.23 0.25 0.26 0.27 0.28 0.29 0.3;
    0.01 0.03 0.05 0.07 0.09 0.11 0.13 0.15 0.17 0.19 0.21 0.23 0.25 0.26 0.27 0.28 0.29 0.3;
    0.01 0.03 0.05 0.07 0.09 0.11 0.13 0.15 0.17 0.19 0.21 0.23 0.25 0.26 0.27 0.28 0.29 0.3;
    0.01 0.03 0.05 0.07 0.09 0.11 0.13 0.15 0.17 0.19 0.21 0.23 0.25 0.26 0.27 0.28 0.29 0.3;
    0.01 0.03 0.05 0.07 0.09 0.11 0.13 0.15 0.17 0.19 0.21 0.23 0.25 0.26 0.27 0.28 0.29 0.3;
    ];

PPP=double(floor(alpha*Nneur));                % 3. Scanning for values of P, number of paterns
num_copies = 0;                                % 4. Decide how many noisy copies of the patterns you want to generate and learn
flip_frac  = 0.05;                             % 5. Fix the fraction of spins to flip in the noisy copies (meaningless if num_copies is 0)
cam_spx = [1,5,13,21,30,40,50,60,70,80,90,100,110,120,130,140,150]; % 6. How many pixels on the camera you assign to a neuron; M, emergent parameter
exposure_time = 3000;                          % 7. Set the exposure time of the camera
pattern_variations=3;                          % 8. How many realizations of P patterns you want to consider
retrieval_attempts=2;                          % 9. How many attempts to retrieve a pattern starting from different initial cond
improve_weights = true ;

mean_mag = zeros(size(PPP));  % preallocate result array
std_mag = zeros(size(PPP));   % preallocate result array
save(results_file, 'mean_mag', 'std_mag'); 

%% ========================= DMD initialization ===========================
global hdevice dll_name      % create global handles for dmd and library
if isempty(hdevice) || isempty(dll_name)
    % First time → really start the DMD
    [hdevice, dll_name] = dmd_start();
else
    disp('Reusing existing DMD handles (not calling dmd_start again).');
    dmd_clear(dll_name,hdevice); % Resetting the device
end
%% ============ USER KNOBS: DMD and CAMERA parameters =========== 
% Define cfg struct ===
cfg = struct();

% DMD parameters
cfg.W_DMD       = 1024;                                 % DMD width in px
cfg.H_DMD       = 768;                                  % DMD height in px
cfg.dmd_super_w = 2;                                    % DMD superpixel width
cfg.dmd_super_h = 2;                                    % DMD superpixel height
cfg.W_ROI       = ref_disk_diameter*cfg.dmd_super_w;    % DMD ROI width
cfg.H_ROI       = ref_disk_diameter*cfg.dmd_super_h;    % DMD ROI height
cfg.X_SHIFT     = 50;                                   % Horizontal ROI shift
cfg.Y_SHIFT     = -30;                                  % Vertical ROI shift
cfg.cam_size_spx= cam_spx;                              % How many px in a cam spx
cfg.cam_pause   = 0.02;                                 % Cam waits before taking snapshot of dmd
cfg.dll_name = dll_name;                                % API handle
cfg.hdevice  = hdevice;                                 % DMD pointer
cfg.waitbar = false;                                    % Show waitbars when learning

% This frame has the size of the DMD. It is the canvas where we will paint our full picture to send on dmd
full_frame = zeros(cfg.H_DMD,cfg.W_DMD,'uint8');        

% Here we write the nontrivial, non superpixeled image, storing the state of the neurons
% and the reference background disk.
small_frame = zeros(ref_disk_diameter);

% With this you get DMD ROI mask (where we are going to actively write) as well as its first and last row 
[mask_ROI,first_row,last_row] = util_roi_definition(cfg.W_DMD, cfg.H_DMD, cfg.W_ROI, cfg.H_ROI, -cfg.X_SHIFT, cfg.Y_SHIFT);
cfg.mask_ROI = mask_ROI;

% Limit rows on the DMD. You may choose to set them equal to ROI boundaries.
cfg.first_row   = first_row;                
cfg.last_row    = last_row;    

% Now we create a chessboard to translate binary patterns into superpixelled patterns.  
cfg.chessboard = util_chessboard(ref_disk_diameter,ref_disk_diameter,cfg.dmd_super_w,cfg.dmd_super_h);

%% ====== Creating the reference disk masks ========
% With these masks you can selectively control the neurons or the reference pixels
[mask_reference,mask_neurons] = util_masks_generator(ref_disk_diameter,N_x,N_y);
cfg.mask_reference = mask_reference;
cfg.mask_neurons = mask_neurons;
% These indices work on the small_frame, unsuperpixelled.

%% ======= Camera preview ==========
imaqreset
% Create video input object
vid = videoinput('gentl', 1, 'Mono8');  % Adjust adapter/device ID as needed
% Configure the video source object (camera features)
src = getselectedsource(vid);
sensorSize = vid.VideoResolution;
W_cam  = sensorSize(1); cfg.W_cam=W_cam;
H_cam = sensorSize(2); cfg.H_cam=H_cam;

cam_settings = struct();
cam_settings.ExposureTime    = exposure_time;       % in microseconds
cam_settings.Gain            = 0;                   % camera gain
cam_settings.UiFpsCap        = 10;                  % limit UI update to 10 fps

% Send a random frame to the DMD. Here you get an idea of what the DMD broadcast
% procedure looks like (inner working of util_speckle_from_state)
[base_patterns,patterns]=util_pattern_generator(N_x,N_y,3,num_copies,flip_frac); % generate random patterns
pat = patterns(:,:,1);                                      % choose one pattern
small_frame(mask_neurons)=pat(:);                           % set neurons to reproduce pattern
small_frame(mask_reference)=1;                              % set disk mask to all 1
figure('Color','w'); imagesc(small_frame); colormap(gray); axis image off;
title('Binary pattern');
imgROI = util_bin_to_superpixel(small_frame, cfg.dmd_super_w, cfg.dmd_super_h, cfg.chessboard);
full_frame(mask_ROI)=imgROI(:);                             % embed image in full DMD frame
% Enforce DMD image contract
assert(isequal(size(full_frame), [768, 1024]), 'DMD image must be 768x1024 (rows x cols).');
ref_frame_dmd = full_frame';                                % transpose image for correct DMD broadcasting
cfg.pointer = libpointer('uint8Ptr', ref_frame_dmd);        % Pointer to the image
set(cfg.pointer, 'Value', ref_frame_dmd);                   % This is how you update what pointer points at

% Send image on DMD
dmd_display(dll_name, hdevice, cfg.pointer, first_row, last_row);

figure('Color','w'); imagesc(full_frame); colormap(gray); axis image off;
title('Pattern sent to DMD');

[background,proceed]=cam_preview_gui(vid,cam_settings);     % Opens camera GUI. Code starts when GUI gets closed.
cfg.background = background;

fprintf("\nCamera preview closed. Now taking a snapshot:");
start(vid);
if isprop(src,'AcquisitionFrameRateEnable')
    src.AcquisitionFrameRateEnable = 'false';
end
src.ExposureTime = exposure_time;
fprintf('Reported FPS: %.2f\n', src.ResultingFrameRate);
[test1,meta]=take_snapshot(vid,cfg.cam_pause,background);   % Modifies snapshot function waiting for DMD
fprintf("\nSnapshot taken!");
save(fullfile(run_dir, 'test_frame_start.mat'), 'test1');
pause(10);
%% ========= Save experiment configuration ==============================
save(fullfile(run_dir, 'experiment_config.mat'), 'cfg', 'alpha','Nneur', 'cam_spx', 'num_copies', ...
    'flip_frac', 'N_x','N_y', 'exposure_time', 'timestamp');

logfile = fullfile(run_dir, 'console_output.txt');
diary(logfile); diary on;
flushdata(vid);

gpu_warm_up(PPP,Nneur);  % Just like a real sportsperson the gpu needs to wake up a bit.

%% ================================= Experiment begins ======================================
% For different values of the emergent parameter MMM, try storing ppp patterns and see if dynamics
% takes you away from them. Use overlaps m = mean(\xi * state) as observable.

for iii=1:length(cam_spx)
    MMM=cam_spx(iii);
    cfg.cam_size_spx=MMM;
    for jjj=1:length(PPP(iii, :))
        ppp=PPP(iii,jjj);
        m_tot = 0;              % Here we store the magnetizations obtained for each iteration
        m_square_tot = 0;
        patterns_to_start_from=min(5,ppp);
        for lll=1:pattern_variations
            [base_patterns,patterns]=util_pattern_generator(N_x,N_y,ppp,num_copies,flip_frac);  %generate random patterns
            fprintf("\n == New experiment begins with M=%d, P=%d; pattern variation %d =========\n",MMM,ppp,lll);        
            %% ============= Learning section ============================
            set(cfg.pointer, 'Value', ref_frame_dmd); 
            dmd_display(dll_name, hdevice, cfg.pointer, first_row, last_row);
            [test1,meta]=take_snapshot(vid,cfg.cam_pause,background);
            
            if proceed
                [map_idx,weights]=learning(base_patterns,small_frame,full_frame,improve_weights,vid,cfg);
            else
                error('\nError: no authorization to proceed.');
            end
            
            c=util_correlation_with_reference(background, cfg, vid, ref_frame_dmd, test1);
            fprintf("After learning phase, correlation with initial frame is: %.4f\n",c);
            pause(0.1);
            
            %% ===== TEST: are patterns fixed points? ==========
            if ~isempty(map_idx)
                fprintf('\n\n[Fixed-point test]\n');
                testing(base_patterns,small_frame,full_frame,vid,cfg,map_idx,weights);
            else
                warning('map_idx is empty or has wrong size; skipping fixed-point test.');
            end
            
            
            %% ================ Retrieval begins ===========================
            if ~isempty(map_idx) && all(all(isfinite(map_idx)))
                %% Generate noisy versions of patterns
                flip_percent = 0; % Percentage of spins to flip  
                rng('shuffle');  % randomizza il seed               
                for kkk = randi(ppp, patterns_to_start_from, 1)'  % try random starting points
                    orig = base_patterns(:,:,kkk);
                    Nspins = numel(orig);
                    % collecting magnetizations here
                    %% Here retrieval code actually begins
                    % Quanti spin flippare
                    Nflip = round(Nspins * flip_percent/100);
                    for aaa = 1:retrieval_attempts
                        % Indici casuali da flippare
                        idx = randperm(Nspins, Nflip);    
                        % Copia e flip
                        noisy_initial_condition = orig;
                        noisy_initial_condition(idx) = -noisy_initial_condition(idx); %flippa random spins
                        % === Richiamo funzione con Video abilitato ===
                        [m_fin, info] = run_mcpitts_with_dmd( ...
                            noisy_initial_condition, ...     % stato iniziale rumoroso
                            orig, ...                        % pattern di riferimento
                            small_frame, full_frame, ...     % where we write images
                            vid, cfg, map_idx, weights, ...           % setup HW
                            'Video', false, ...              % salva evoluzione in AVI
                            'Verbose', true);                % log a schermo
                        if m_fin==0
                            fprintf("zero mag. final mags were: \n");
                            disp(info.m_hist);
                        end
                        m_tot = m_tot + abs(m_fin);          % salva risultato
                        m_square_tot = m_square_tot + m_fin*m_fin;
                    end
                end
            end
        end
        attempts=retrieval_attempts*pattern_variations*patterns_to_start_from;
        m_mean = m_tot/attempts;
        mean_mag(iii,jjj) = m_mean;
        std_mag(iii,jjj)= m_square_tot/attempts - m_mean*m_mean;
        save(fullfile(run_dir, 'results.mat'), 'mean_mag', 'std_mag','-append');
        c=util_correlation_with_reference(background, cfg, vid, ref_frame_dmd, test1);
        fprintf("At the end of the experiment, correlation with initial frame is: %.4f\n",c);
   end
end

fprintf("\n Results saved.")
diary off;
stop(vid);