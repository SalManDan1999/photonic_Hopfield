%% simulation_retrieval_limits.m 
% Flow of the code:
% 1> Generates random patterns to try and retrieve.
% 2> Generate a random transmission matrix and interference Electric field
% 3> Compute effective matrix through which local fields are calculated by the machine.
%    You know that I_{(j)}(s)-I{(j)}(-s)=4Re(E_{(j)}\sum_k t_{(j)}^ks_k), this gives
%    you the effective matrix.
% 4> Select the output modes you want to look at. This gives the coupling matrix that
%    will actually rule the dynamics as: W_jk=4 \sum_l Re(E_{(j_l)}\sum_k t_{(j_l)}^ks_k)
% 5> Try retrieval with this matrix as well as with the hebbian and see what happens

clearvars -except hdevice dll_name
clc;

%% ============ Creating the folder to save files =========================
timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
run_dir = fullfile('runs', ['run_' timestamp]);
mkdir(run_dir);
fprintf('\nAll outputs will be saved in: %s\n', run_dir);

%% ============ USER KNOBS: NEURON ARRAY and CAMERA parameters =========== 
% === Define neuron params ===
N_x=20; N_y=20;
NNN=N_x*N_y;
cam_x=200; cam_y=200; 
pattern_set='random';
improve_map_weights=true;
% Parametri 
alpha = [
    0.003 0.006 0.016 0.024 0.032 0.038 0.042 0.048 0.052 0.054 0.060 0.064 0.072 0.16;
    0.003 0.006 0.016 0.024 0.032 0.038 0.042 0.048 0.052 0.054 0.060 0.064 0.072 0.16;
    0.003 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.11 0.12 0.13 0.14 0.15 0.16;
    0.003 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.11 0.12 0.13 0.14 0.15 0.16;
    0.003 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.11 0.12 0.13 0.14 0.15 0.16;
    0.003 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.11 0.12 0.13 0.14 0.15 0.16;
    0.003 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.11 0.12 0.13 0.14 0.15 0.16;
    0.003 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.11 0.12 0.13 0.14 0.15 0.16;
    0.003 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.11 0.12 0.13 0.14 0.15 0.16;
    0.003 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.11 0.12 0.13 0.14 0.15 0.16;
    0.003 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.11 0.12 0.13 0.14 0.15 0.16;
    0.003 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.11 0.12 0.13 0.14 0.15 0.16;
    0.003 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.11 0.12 0.13 0.14 0.15 0.16;
    0.003 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.11 0.12 0.13 0.14 0.15 0.16;
    0.003 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.11 0.12 0.13 0.14 0.15 0.16;
    0.003 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.11 0.12 0.13 0.14 0.15 0.16;
    0.003 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.11 0.12 0.13 0.14 0.15 0.16;
    0.003 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.11 0.12 0.13 0.14 0.15 0.16;
    0.003 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.11 0.12 0.13 0.14 0.15 0.16;
    0.003 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.11 0.12 0.13 0.14 0.15 0.16;
    0.003 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.11 0.12 0.13 0.14 0.15 0.16;
    ];
alpha = [
    0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.22 0.24 0.26 0.28 0.3;
    0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.22 0.24 0.26 0.28 0.3;
    0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.22 0.24 0.26 0.28 0.3;
    0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.22 0.24 0.26 0.28 0.3;
    0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.22 0.24 0.26 0.28 0.3;
    0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.22 0.24 0.26 0.28 0.3;
    0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.22 0.24 0.26 0.28 0.3;
    0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.22 0.24 0.26 0.28 0.3;
    0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.22 0.24 0.26 0.28 0.3;
    0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.22 0.24 0.26 0.28 0.3;
    0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.22 0.24 0.26 0.28 0.3;
    0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.22 0.24 0.26 0.28 0.3;
    0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.22 0.24 0.26 0.28 0.3;
    0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.22 0.24 0.26 0.28 0.3;
];
PPP=floor(alpha*NNN);                                     % number of patterns to generate
num_copies = 0;                                 % how many noisy copies per pattern (to try emergent learning)
flip_frac  = 0.03;                              % fraction of spins to flip in each copy (e.g. 2%)
cam_spx=[1,5,13,21,30,40,50,60,70,80,90,100,120,150];  % m: how many output modes are considered when giving output
pattern_variations=3;
retrieval_attempts=2;

mean_mag=zeros(size(PPP));                      % avg overlap with pattern with optical weights
std_mag=zeros(size(PPP));
mean_mag_hebbs=zeros(size(PPP));                % avg overlap with pattern with hebbian weights
std_mag_hebbs=zeros(size(PPP));
gpu_warm_up(PPP,NNN);

%% ==== Generate the transmission matrix and reference field ====
sigma_transmission=10;  % stdv of real and im components of transmission matrix
fprintf("\nGenerating the transmission matrix.\nThis may take a while, it's a %d x %d matrix.",cam_x*cam_y,N_x*N_y);
t=generate_transmission_matrix(N_x,N_y,cam_x,cam_y,sigma_transmission, 'Class', 'single');
fprintf("\nDone.\n")
[E,B]=generate_complex_field(cam_x,cam_y,1,0.3);

for iii=1:length(cam_spx)
    cam_spx_i=cam_spx(iii);
    for jjj=1:length(PPP(1,:))
        P_j=PPP(iii,jjj);
        fprintf('\nNow working on n_spx=%d, P=%d',cam_spx_i,P_j)
        m_tot=0;
        m_squared_tot=0;
        m_tot_hebbs=0;
        m_squared_tot_hebbs=0;
        patterns_to_start_from=min(5,P_j);
        for vvv=1:pattern_variations
            %% ==== Load MNIST or random patterns
            if  strcmp(pattern_set, 'MNIST')
                % --- Load the subset train set ---
                S = load('subset_1to9_1sample/mnist_train_123456789classes1samples.mat');
                
                % --- Extract only the frames (28x28xN logical array) ---
                train_X_bin = S.train_X_bin;
                train_y     = S.train_y;       % N×1 labels
                base_patterns = 2*train_X_bin - 1;  % {-1,1} version of the patterns
                patterns=mnist_noise_generator(base_patterns,P_j,num_copies,flip_frac);
                
            elseif strcmp(pattern_set, 'random')
                [base_patterns,patterns]=util_pattern_generator(N_x,N_y,P_j,num_copies,flip_frac);
            end
            % Computing the analytical coupling matrix
            hebbs_matrix=util_hebbian_from_frames(base_patterns);
            
            % Stampa dimensioni come prima
            sz = size(base_patterns);
            txt = sprintf('%dx', sz);
            txt(end) = [];
            fprintf('\nPatterns size is %s\n', txt);
                      
            %% ====== Learning section ========
            
            patterns_local_fields = zeros(cam_x,cam_y,size(base_patterns,3),'int8');  % preallocate 
            fprintf('\nSending patterns. Please wait.')
            
            for kkk = 1:size(base_patterns,3)
                pattern = base_patterns(:,:,kkk);
                frame   = local_fields_calculator(pattern, E, t, false);
                patterns_local_fields(:,:,kkk) = reshape(frame, size(E));                  
            end
            waitbar=false; %display or not waitbar
            
            [map_idx,map_weights]=util_learn_mapping_weighted(patterns_local_fields,base_patterns,cam_spx_i,improve_map_weights,waitbar);
            optical_weights=util_optical_hopfield_weights(t,E,map_idx,map_weights);
        
            %% ===== TEST: are patterns fixed points? ==========
            if ~isempty(map_idx)
                fixed_pct = zeros(P_j,1);  % percentage of aligned signs per pattern 
                fprintf('\n\n[Fixed-point test]\n');
                for kkk = 1:P_j
                    s = base_patterns(:,:,kkk);                     % ±1 memory (N_x x N_y)
                    s_vec = s(:);
                    % Get ONLY the signs of local fields at the mapped output pixels:
                    lf_signs = sign(optical_weights*s_vec);  
                    % Compare with the memory spins (vectorized):
                    agree = mean(lf_signs(:) == s_vec(:));       % fraction in [0,1]
                    fixed_pct(kkk) = 100 * agree;              % percentage
            
                    fprintf('Pattern %d: %.6f%% of local-field signs aligned.\n', kkk, fixed_pct(kkk));
                end
                fprintf('Average alignment over all patterns: %.2f%%\n', mean(fixed_pct));
            else
                warning('map_idx is empty or has wrong size; skipping fixed-point test.');
            end
            
            %% ================ Retrieval study begins ===========================
            for kkk=1:patterns_to_start_from
                for aaa=1:retrieval_attempts
                    orig = base_patterns(:,:,kkk);      
                    % build noisy initial condition
                    noisy_initial_condition = orig;                    
                    % run retrieval
                    [m_fin, final_state, avg_step_time, info] = run_hopfield(noisy_initial_condition, orig, optical_weights);
                    [m_fin_hebbs, final_state, avg_step_time, info] = run_hopfield(noisy_initial_condition, orig, hebbs_matrix);
                    m_tot=m_tot+abs(m_fin);
                    m_squared_tot=m_squared_tot+m_fin*m_fin;
                    m_tot_hebbs=m_tot_hebbs+abs(m_fin_hebbs);
                    m_squared_tot_hebbs=m_squared_tot_hebbs+m_fin_hebbs*m_fin_hebbs;
                end
            end
        end
        attempts=retrieval_attempts*patterns_to_start_from*pattern_variations;
        
        mean_mag(iii,jjj)=m_tot/attempts;
        mean_mag_hebbs(iii,jjj)=m_tot_hebbs/attempts;
        fprintf('\nStep ended with m_mean=%.2f, m_mean_hebbs=%.2f\n.',mean_mag(iii,jjj),mean_mag_hebbs(iii,jjj));
        fprintf('\nStopped by: %s.',info.stoppedBy);
        std_mag(iii,jjj)=m_squared_tot/attempts-mean_mag(iii,jjj)*mean_mag(iii,jjj);
        std_mag_hebbs(iii,jjj)=m_squared_tot_hebbs/attempts-mean_mag_hebbs(iii,jjj)*mean_mag_hebbs(iii,jjj);
    end
end
fname = fullfile(run_dir, 'results.mat');
fname2 = fullfile(run_dir, 'experiment_config.mat');
save(fname, 'mean_mag', 'std_mag','mean_mag_hebbs','std_mag_hebbs');
save(fname2,'alpha','NNN','cam_spx','cam_x','cam_y','improve_map_weights');

function s = symmetry_deg(A)
    A_lin=A(:);
    A_transp=A.';
    A_transp_lin=A_transp(:);
    s = dot(A_lin, A_transp_lin) / (norm(A_lin) * norm(A_transp_lin));
end
