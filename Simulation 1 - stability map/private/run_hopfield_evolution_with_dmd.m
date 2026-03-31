function [m_final, info] = run_hopfield_evolution_with_dmd(initial_state, clean_pattern, vid, cfg, background, map_idx, varargin)
% RUN_HOPFIELD_EVOLUTION_WITH_DMD  (AVI video)
% Evolves a binary state with synchronous McCulloch–Pitts updates. Local fields
% are computed by DMD+camera via local_fields_calculator(..., fast=true).
%
% - Max steps: default 100 (change with 'MaxSteps')
% - Stop when m(t) > m0 for 'StreakTarget' consecutive steps
% - m_final = average of last 10 magnetizations (or fewer if <10 steps)
% - If 'Video'==true, saves an AVI (Motion JPEG) of the evolution.
%
% INPUT
%   initial_state : [Ny x Nx] in {-1,+1} (noisy pattern)
%   clean_pattern : [Ny x Nx] in {-1,+1} (reference pattern)
%   vid, cfg, background : camera/DMD setup
%   map_idx       : [Ny*Nx x 1] neuron->camera pixel (used by local_fields_calculator)
%
% NAME-VALUE
%   'MaxSteps'       (default 100)
%   'StreakTarget'   (default 20)
%   'Video'          (default false)
%   'VideoRoot'      (default 'hopfield_evol')  % root name for the AVI file
%   'GifRoot'        (legacy alias for VideoRoot)
%   'P'              (default NaN)              % included in filename
%   'Verbose'        (default true)
%   'VideoFrameRate' (default 14)               % integer fps
%   'VideoQuality'   (default 95)               % 0..100 for Motion JPEG
%
% DEPENDS ON
%   local_fields_calculator(stateMat, vid, cfg, bckgrnd, keep_idx, fast)
%   % with fast=true returns SIGN of local fields as Ny×Nx matrix.

    % ---------- Parse options ----------
    p = inputParser;
    p.addParameter('MaxSteps',       100,  @(x)isnumeric(x) && isscalar(x) && x>0);
    p.addParameter('StreakTarget',   20,   @(x)isnumeric(x) && isscalar(x) && x>=1);
    p.addParameter('Video',          false,@(x)islogical(x) && isscalar(x));
    p.addParameter('VideoRoot',      'hopfield_evol', @(x)ischar(x) || isstring(x));
    p.addParameter('GifRoot',        '', @(x)ischar(x) || isstring(x)); % legacy alias
    p.addParameter('P',              NaN,  @(x)isnumeric(x) && isscalar(x));
    p.addParameter('Verbose',        true, @(x)islogical(x) && isscalar(x));
    p.addParameter('VideoFrameRate', 14,   @(x)isnumeric(x) && isscalar(x) && x>0);
    p.addParameter('VideoQuality',   95,   @(x)isnumeric(x) && isscalar(x) && x>=0 && x<=100);
    p.parse(varargin{:});

    MaxSteps       = p.Results.MaxSteps;
    StreakTarget   = p.Results.StreakTarget;
    makeVideo      = p.Results.Video;
    Pval           = p.Results.P;
    Verbose        = p.Results.Verbose;
    fps            = p.Results.VideoFrameRate;
    vidQuality     = p.Results.VideoQuality;

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
        error('clean_pattern deve avere dimensioni [%d x %d].', Ny, Nx);
    end
    N = Ny * Nx;
    if numel(map_idx) ~= N
        error('map_idx deve essere lungo N=%d.', N);
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
        ts = datestr(now,'yyyymmdd_HHMMSS');
        if isnan(Pval)
            baseName = sprintf('%s_N%d_PNA_%s', videoRoot, N, ts);
        else
            baseName = sprintf('%s_N%d_P%d_%s',  videoRoot, N, Pval, ts);
        end
        video_path = [baseName '.avi'];

        v = VideoWriter(video_path, 'Motion JPEG AVI');
        v.FrameRate = round(fps);
        v.Quality   = vidQuality;
        open(v);

        % Write INITIAL frame (RGB uint8)
        frame_img = uint8(255 * ((state+1)/2));   % [0,255] grayscale
        frame_rgb = repmat(frame_img, [1 1 3]);   % to RGB
        writeVideo(v, frame_rgb);
    end

    % ---------- Evolution loop ----------
    better_streak = 0;
    k = 1;
    stop_reason = 'max_steps';

    while k < MaxSteps
        k = k + 1;

        % Get SIGN of local fields as Ny×Nx
        h_sign = local_fields_calculator(state, vid, cfg, background, map_idx, true);

        % Safety check on size
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
        m_hist(k) = mean(state(:) .* ref(:));

        % Update streak
        if m_hist(k) > m0
            better_streak = better_streak + 1;
        else
            better_streak = 0;
        end

        % Append video frame
        if makeVideo
            frame_img = uint8(255 * ((state+1)/2));
            frame_rgb = repmat(frame_img, [1 1 3]);
            writeVideo(v, frame_rgb);
        end

        if better_streak >= StreakTarget
            stop_reason = 'improved_streak';
            break;
        end
    end

    steps_done = k;

    % ---------- Final magnetization (avg of last up to 10 steps) ----------
    lastK   = min(10, steps_done);
    m_final = mean( m_hist( max(1,steps_done-lastK+1) : steps_done ) );

    % ---------- Close video ----------
    if makeVideo
        close(v);
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
end
