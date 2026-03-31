function [m_final, info] = run_mcpitts_with_dmd_demo(initial_state, clean_pattern, attempt, small_frame, full_frame, vid, cfg, map_idx, varargin)
% RUN_HOPFIELD_EVOLUTION_WITH_DMD  (AVI video + live GUI demo)
% Evolves a binary state with synchronous McCulloch–Pitts updates. Local fields
% are computed by DMD+camera via local_fields_calculator(..., fast=true).
%
% - Max steps: default 100 (change with 'MaxSteps')
% - Stop when m(t) > m0 for 'StreakTarget' consecutive steps
% - m_final = average of last 10 magnetizations (or fewer if <10 steps)
% - If 'Video'==true, saves an AVI (Motion JPEG) of the evolution.
% - If 'LivePreview'==true, shows a lightweight GUI updated each step.
%
% INPUT
%   initial_state : [Ny x Nx] in {-1,+1} (noisy pattern)
%   clean_pattern : [Ny x Nx] in {-1,+1} (reference pattern)
%   vid, cfg      : camera/DMD setup
%   map_idx       : [Ny*Nx x 1] neuron->camera pixel (used by local_fields_calculator)
%
% NAME-VALUE
%   'MaxSteps'       (default 100)
%   'StreakTarget'   (default 30)
%   'Video'          (default false)
%   'VideoRoot'      (default 'hopfield_evol')
%   'GifRoot'        (legacy alias for VideoRoot)
%   'P'              (default NaN)              % included in filename
%   'kkk'            (default NaN)              % included in filename
%   'Verbose'        (default true)
%   'VideoFrameRate' (default 3)
%   'VideoQuality'   (default 95)
%   'LivePreview'    (default true)             % NEW: show the demo GUI
%   'PreviewPause'   (default 0.5)              % NEW: seconds between steps
%   'PreviewScale'   (default [])               % NEW: if empty, show Ny×Nx; otherwise upscales by this integer
%
% DEPENDS ON
%   local_fields_calculator(stateMat, vid, cfg, bckgrnd, keep_idx, fast)
%   % with fast=true returns SIGN of local fields as Ny×Nx matrix.

    % ---------- Parse options ----------
    p = inputParser;
    p.addParameter('MaxSteps',       100,  @(x)isnumeric(x) && isscalar(x) && x>0);
    p.addParameter('StreakTarget',   30,   @(x)isnumeric(x) && isscalar(x) && x>=1);
    p.addParameter('Video',          false,@(x)islogical(x) && isscalar(x));
    p.addParameter('VideoRoot',      'hopfield_evol', @(x)ischar(x) || isstring(x));
    p.addParameter('GifRoot',        '', @(x)ischar(x) || isstring(x));
    p.addParameter('P',              NaN,  @(x)isnumeric(x) && isscalar(x));
    p.addParameter('kkk',            NaN,  @(x)isnumeric(x) && isscalar(x));
    p.addParameter('Verbose',        true, @(x)islogical(x) && isscalar(x));
    p.addParameter('VideoFrameRate', 3,   @(x)isnumeric(x) && isscalar(x) && x>0);
    p.addParameter('VideoQuality',   95,   @(x)isnumeric(x) && isscalar(x) && x>=0 && x<=100);
    % NEW
    p.addParameter('LivePreview',    true, @(x)islogical(x) && isscalar(x));
    p.addParameter('PreviewPause',   0.5,  @(x)isnumeric(x) && isscalar(x) && x>=0);
    p.addParameter('PreviewScale',   [],   @(x)isnumeric(x) && (isempty(x) || (isscalar(x)&&x>=1)));
    p.parse(varargin{:});

    MaxSteps       = p.Results.MaxSteps;
    StreakTarget   = p.Results.StreakTarget;
    makeVideo      = p.Results.Video;
    Pnum           = p.Results.P;
    kkk_index      = p.Results.kkk;
    Verbose        = p.Results.Verbose;
    fps            = p.Results.VideoFrameRate;
    vidQuality     = p.Results.VideoQuality;

    LivePreview    = p.Results.LivePreview;
    dt_preview     = p.Results.PreviewPause;
    scale_preview  = p.Results.PreviewScale;

    % Choose base filename root (prefer VideoRoot; fall back to legacy GifRoot if provided)
    videoRoot = char(p.Results.VideoRoot);
    if ~isempty(p.Results.GifRoot)
        videoRoot = char(p.Results.GifRoot);
    end

    % ---------- Checks ----------
    state = sign(initial_state);
    ref   = sign(clean_pattern);
    [Ny, Nx] = size(state);
    if any(size(ref) ~= [Ny, Nx])
        error('clean_pattern must have size [%d x %d].', Ny, Nx);
    end
    N = Ny * Nx;
    if size(map_idx,1) ~= N
        error('map_idx must have N=%d elements', N);
    end

    % ---------- Initial overlap ----------
    m_hist = zeros(MaxSteps,1);
    m0 = mean(state(:) .* ref(:));
    m_hist(1) = m0;
    if Verbose
        fprintf('[Hopfield] N=%d, m0=%.4f, target: m(t)>m0 per %d iter consecutive (max %d passi)\n', ...
            N, m0, StreakTarget, MaxSteps);
    end

    % ---------- AVI setup (optional) ----------
    v = [];
    video_path = '';
    if makeVideo
        out_dir = char(videoRoot);
        if ~isfolder(out_dir)
            mkdir(out_dir);
        end
        ts = datestr(now,'yyyymmdd_HHMMSS');
        if isnan(Pnum)
            base_name = sprintf('N%d_%s', N, ts);
        else
            base_name = sprintf('N%d_P%d_pattern%d_%s', N, Pnum, kkk_index, ts);
        end
        video_path = fullfile(out_dir, [base_name '.avi']);

        v = VideoWriter(video_path, 'Motion JPEG AVI');
        v.FrameRate = round(fps);
        v.Quality   = vidQuality;
        % fixed shaping for crisp squares and frame-hold
        pixScale = 8;            % each neuron becomes an 8x8 block
        repeatN  = 3;            % hold each state for 3 frames
        open(v);

        % Write INITIAL frame (scaled + repeated)
        write_bw_frame(state);
    end

    % ---------- Live preview (optional, lightweight) ----------
    % We keep this as small Ny×Nx image to minimize graphics overhead.
    fprev = [];
    axprev = [];
    imprev = [];
    if LivePreview
        % Prepare optional upscaling via kron only once per frame if requested.
        if isempty(scale_preview), scale_preview = 1; end

        fprev = figure('Name',sprintf('McCulloch-Pitts demo, attempt %d', attempt), 'NumberTitle','off', ...
                       'Color',[1 1 1], 'MenuBar','none', 'ToolBar','none', ...
                       'Renderer','opengl', 'Units','pixels', 'Position', centerFigPos(Nx*10*scale_preview, Ny*10*scale_preview));
        axprev = axes('Parent',fprev); 
        imprev = image(axprev, to_uint8(state, scale_preview)); % 0/255
        colormap(axprev, gray(256)); axis(axprev,'image','off');
        title(axprev, sprintf('Iteration %d / %d   m=%.3f', 1, MaxSteps, m_hist(1)), 'FontWeight','normal');
        drawnow limitrate nocallbacks;
    end

    % ---------- Evolution loop ----------
    better_streak = 0;
    kkk = 1;
    nochange_window = 5;
    m_tol = 0;               % or e.g. 1e-12 if you prefer a tiny tolerance
    stop_reason = 'max_steps';

    while kkk < MaxSteps
        kkk = kkk + 1;

        % Get SIGN of local fields as Ny×Nx
        h_sign = local_fields_calculator(state,small_frame,full_frame,vid,cfg,map_idx,true);
        if ~isequal(size(h_sign), [Ny, Nx])
            error('local_fields_calculator deve restituire una matrice %dx%d (invece ha %dx%d).', ...
                Ny, Nx, size(h_sign,1), size(h_sign,2));
        end

        % Synchronous update; keep state where h=0
        new_state = state;
        new_state(h_sign > 0) = +1;
        new_state(h_sign < 0) = -1;
        state = new_state;

        % Overlap with reference
        m_hist(kkk) = mean(state(:) .* ref(:));

        % Update streak
        if m_hist(kkk) > m0
            better_streak = better_streak + 1;
        else
            better_streak = 0;
        end

        % Append video frame
        if makeVideo
            write_bw_frame(state);
        end

        % Live preview update (lightweight)
        if LivePreview && isvalid(imprev)
            set(imprev, 'CData', to_uint8(state, scale_preview));
            if isvalid(axprev)
                title(axprev, sprintf('Iteration %d / %d   m=%.3f', kkk, MaxSteps, m_hist(kkk)));
            end
            drawnow limitrate nocallbacks;
            if dt_preview > 0
                pause(dt_preview);
            end
        end
        
        if better_streak >= StreakTarget || abs(m_hist(kkk))>0.99 
            stop_reason = 'improved_streak';
            break;
        end

        % Early-stop 2: magnetization stalled for the last 5 iterations
        if kkk >= nochange_window
            recent = m_hist(kkk-nochange_window+1 : kkk);
            % "No change" if all consecutive differences are within tolerance
            if max(abs(diff(recent))) <= m_tol
                stop_reason = 'magnetization_stalled';
                break;
            end
        end
    end

    steps_done = kkk;

    % ---------- Final magnetization (avg of last up to 10 steps) ----------
    lastK   = min(1, steps_done);
    m_final = mean( m_hist( max(1,steps_done-lastK+1) : steps_done ) );

    % ---------- Close video ----------
    if makeVideo
        close(v);
    end

    % ---------- Live preview finalization ----------
    if LivePreview && ~isempty(axprev) && isvalid(axprev)
        title(axprev, sprintf('Finished: %s   steps=%d   m_{final}=%.3f', stop_reason, steps_done, m_final), ...
              'FontWeight','bold');
        drawnow limitrate nocallbacks;
        pause(3.0); % leave result visible before next run starts
        % (Do not close the figure automatically; let the user keep it if desired)
    end

    % ---------- Info struct ----------
    info = struct();
    info.m0          = m0;
    info.m_hist      = m_hist(1:steps_done);
    info.steps_done  = steps_done;
    info.stop_reason = stop_reason;
    info.N           = N;
    info.Nx          = Nx;
    info.Ny          = Ny;
    info.video       = video_path;

    if Verbose
        fprintf('[Hopfield] stop=%s, steps=%d, m_final(avg last %d)=%.4f\n', ...
            stop_reason, steps_done, lastK, m_final);
        if makeVideo
            fprintf('Video saved: %s\n', video_path);
        end
    end

    % ========= nested helpers =========

    % helper to write one scaled, repeated BW frame
    function write_bw_frame(state_mat)
        frame_img = uint8(255 * ((state_mat+1)/2));          % [0,255]
        frame_img = kron(frame_img, ones(pixScale,'uint8')); % nearest-neighbor upscale
        frame_rgb = repmat(frame_img, [1 1 3]);              % to RGB
        for rr = 1:repeatN
            writeVideo(v, frame_rgb);
        end
    end

    % convert ±1 matrix to uint8 0/255; optionally upscale by integer factor
    function out = to_uint8(mat, s)
        if s==1
            out = uint8(255*((mat+1)/2));
        else
            out = uint8(255*((mat+1)/2));
            out = kron(out, ones(s, 'uint8')); % very fast nearest-neighbor
        end
    end

    % center figure on screen with given size
    function pos = centerFigPos(w, h)
        % fallback if root units weird
        oldUnits = get(0,'Units'); set(0,'Units','pixels');
        scr = get(0,'ScreenSize'); set(0,'Units',oldUnits);
        x = max(50, round((scr(3)-w)/2));
        y = max(50, round((scr(4)-h)/2));
        pos = [x y max(300,w) max(300,h)];
    end
end
