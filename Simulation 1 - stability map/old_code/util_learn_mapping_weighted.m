function [map_idx,map_weights] = util_learn_mapping_weighted(local_fields, patterns, n_spx, use_weights,use_waitbar,use_gpu)
% Function to map neurons to groups of camera pixels
% -------------------------
% For each neuron pixel (from PATTERNS), pick exactly n_spx camera pixels
% (from LOCAL_FIELDS) whose sign time-series best match the neuron's series,
% across P frames. Camera zeros are ignored.

% Strategy (fast + memory-light)
% ------------------------------
% 1) Process camera pixels in blocks and compute agreement scores with GEMM (GPU if available):
%       score(j,i) = ( nonzeros_in_cam(j) + dot(sign(cam_j), sign(neur_i)) ) / 2
%    Add a tiny confidence tiebreak: rank = score + eps * norm_confidence(j),
%    where confidence(j) = min_mu |local_field_j(mu)|.
% 2) For each neuron, keep only the top-n_spx camera candidates (rank + index).
%
% Inputs
%   local_fields : [H_cam x W_cam x P] real-valued local fields
%   patterns     : [N_x x N_y x P] strictly in {-1,+1}
%   n_spx        : positive integer, #camera pixels to assign per neuron
%   use_gpu      : (optional, default true) compute GEMMs on GPU if available
%
% Output
%   map_idx      : [N_x*N_y x n_spx]  Linear indices into LOCAL_FIELDS
%
% Notes
%   - For strict feasibility under global uniqueness, you typically need
%       N_cam >= n_spx * N_neur
%     (otherwise some neurons may not reach n_spx assignments).
%   - Memory stays small: we never build the full [N_cam x N_neur] score matrix.

    if nargin < 6, use_gpu = true; end
    if ~(isscalar(n_spx) && n_spx>=1 && n_spx==floor(n_spx))
        error('n_spx must be a positive integer.');
    end

    % -------- Dimensions --------
    [Hcam, Wcam, P]    = size(local_fields);
    [N_y, N_x, P2] = size(patterns);
    if P ~= P2, error('Mismatch in frame count: %d vs %d.', P, P2); end

    Ncam  = Hcam  * Wcam;     % # camera pixels
    Nneur = N_x * N_y;    % # neuron pixels

    % Feasibility checks (soft and hard)
    if Ncam < Nneur
        error('Mapping impossible: N_cam (%d) < N_neur (%d).', Ncam, Nneur);
    end
    if Ncam < Nneur * n_spx
        warning('N_cam (%d) < N_neur * n_spx (%d): strict global uniqueness may be impossible.', ...
                Ncam, Nneur*n_spx);
    end

    % -------- Flatten stacks : time is 2nd dim now. --------
    camFields = reshape(local_fields, [], P);   % [Ncam  x P]
    neurSigns = reshape(patterns,     [], P);   % [Nneur x P]

    % -------- Precompute camera signs and per-camera stats --------
    camSign = int8(sign(camFields));                 % [-1,0,+1]
    camNZ   = sum(camSign ~= 0, 2, 'native');        % [Ncam x 1] counting nonzero values over P patterns for each pixel
    camConf = min(abs(camFields), [], 2);            % [Ncam x 1] min|local_field| over P patterns. This is the margin

    % Confidence normalization for tiny tie-break term
    maxConf = max(camConf);
    if maxConf == 0
        confNorm = single(zeros(Ncam,1));
    else
        confNorm = single(camConf ./ maxConf);       % in [0,1]
    end
    epsTie = single(1e-4);                           % tiny weight to break exact score ties

    % -------- Pattern signs (strictly ±1) --------
    neurSigns  = int8(neurSigns);
    neurSignsT = single(neurSigns');                 % [P x Nneur]
    if use_gpu
        try
            neurSignsT = gpuArray(neurSignsT);
        catch
            use_gpu = false; % fallback to CPU
        end
    end

    % -------- Keep top-n_spx candidates per neuron ---------
    if use_gpu
        topRank   = -inf(n_spx, Nneur, 'single', 'gpuArray');   % [n_spx x Nneur]
        topCamIdx = zeros(n_spx, Nneur, 'uint32', 'gpuArray');  % [n_spx x Nneur]
    else
        topRank   = -inf(n_spx, Nneur, 'single');
        topCamIdx = zeros(n_spx, Nneur, 'uint32');
    end

    % -------- Progress UI --------
    if use_waitbar
        hwb = waitbar(0, 'Mapping (vectorized)... 0%', 'Name', 'Pixel mapping progress');
        cleanupObj = onCleanup(@() safeCloseWaitbar(hwb));
    end
    % -------- Blocked scan over camera pixels --------
    camBlockRows = 10000;  % tune if needed
    
    % We now iterate over blocks of camera pixels. Blocks are large camBlockRows and start at camStart.
    % 

    for camStart = 1:camBlockRows:Ncam
        camEnd   = min(camStart + camBlockRows - 1, Ncam);
        B        = camEnd - camStart + 1;

        % Current camera block
        camSign_blk = camSign(camStart:camEnd, :);   % [B x P]
        camNZ_blk   = single(camNZ(camStart:camEnd));
        conf_blk    = confNorm(camStart:camEnd);

        % Cast & move to GPU if needed
        if use_gpu
            camSign_blk = gpuArray(single(camSign_blk)); % [B x P]
            camNZ_blk   = gpuArray(camNZ_blk);
            conf_blk    = gpuArray(conf_blk);
        else
            camSign_blk = single(camSign_blk);
        end

        % Dot products across frames (GEMM): agreements - disagreements = d
        d_blk = camSign_blk * neurSignsT;             % [B x Nneur]
        % For each pixel in the block, you get their performance on each neuron. d_blk must be large
        % and positive: you want to associate the right sign to each pattern for each neuron.

        % Agreement score with optimal global flip: (nz + d) / 2
        score_blk = (camNZ_blk + d_blk) / 2;          % [B x Nneur]

        % Tiny confidence tie-break
        rank_blk  = score_blk + epsTie .* conf_blk;   % [B x Nneur]

        % For each neuron, take top-n_spx within this block
        [rank_topB, idx_topB] = maxk(rank_blk, n_spx, 1);         % [n_spx x Nneur]
        camIdx_topB = uint32(camStart - 1) + uint32(idx_topB);  % global indices

        % Merge with running global top-K
        rank_cand = [topRank;   rank_topB];   % [2*n_spx x Nneur]
        idx_cand  = [topCamIdx; camIdx_topB]; % [2*n_spx x Nneur]
        [rank_new, pos] = maxk(rank_cand, n_spx, 1); 
        % rank_new and pos are now [n_spx x Nneur]; only the best have survived. 
        
        % pos are indices over 2*n_spx values. We need to convert into actual camera pixels
        lin = sub2ind(size(idx_cand), pos, repmat(uint32(1:Nneur), n_spx, 1));
        idx_new = idx_cand(lin);

        topRank   = rank_new;
        topCamIdx = reshape(idx_new, n_spx, Nneur);

        % Progress
        if use_waitbar
            frac = camEnd / Ncam;
            waitbar(frac, hwb, sprintf('Mapping... %d%%', round(100*frac)));
        end

        % Free block temporaries on GPU
        if use_gpu
            clear d_blk score_blk rank_blk rank_topB idx_topB camIdx_topB rank_cand idx_cand rank_new pos lin idx_new
        end
    end

    % -------- Multi-assignment with global uniqueness --------
    topCamIdx = gather(topCamIdx); % Porta su CPU
    map_idx   = topCamIdx';        % Trasponi per ottenere [Nneur x n_spx]
    map_idx   = uint32(map_idx);   % Assicura tipo corretto
   
    % ---------------------------------------------------------------------
    % Phase 2: weights optimization
    % ---------------------------------------------------------------------
    if use_waitbar
        waitbar(0.9, hwb, 'Ottimizzazione dei pesi...');
    end

    map_weights = ones(Nneur, n_spx, 'single');
    
    if use_weights
        % Optimizer options
        % 'SpecifyObjectiveGradient': true makes execution way faster
        optOptions = optimoptions('fminunc', ...
            'Display', 'off', ...
            'Algorithm', 'quasi-newton', ...
            'SpecifyObjectiveGradient', true, ...
            'MaxFunctionEvaluations', 100); 
    
        % Slope of tanh (the sharper, the more similar to sign function)
        gamma = 4.0; 

        % Loop sui neuroni (questo può essere parallelizzato con parfor se disponibile)
        % Nota: Se si usa parfor, bisogna gestire 'waitbar' e le variabili broadcast
        for i = 1:Nneur
            % 1. Recupera i dati per questo neurone
            idx_cols = map_idx(i, :);           % Indici dei pixel camera scelti
            
            % Matrice X: [P frames x n_spx pixels]
            % Trasponiamo camFields per avere i frame sulle righe
            X = double(camFields(idx_cols, :).'); 
            
            % Target y: [P frames x 1] (Il pattern del neurone i)
            y = double(neurSigns(i, :).'); 
            
            % 2. Inizializzazione rapida con Minimi Quadrati (Regressione Ridge leggera)
            w_init = ones(n_spx, 1, 'double'); 
            
            % 3. Ottimizzazione non lineare
            % Obiettivo: Massimizzare Somma( tanh(gamma * X * w) .* y )
            % Ovvero Minimizzare il negativo di tale somma.
            fun = @(w) objective_smooth_sign(w, X, y, gamma);
            
            try
                w_opt = fminunc(fun, w_init, optOptions);
            catch
                % Fallback se fminunc fallisce (es. matrice mal condizionata)
                w_opt = w_init;
            end
            if any(isnan(w_opt)) || any(w_opt == -inf)
                w_opt = ones(n_spx, 1, 'double');
            end
            
            map_weights(i, :) = single(w_opt);
            
            if use_waitbar && mod(i, 1000) == 0
                 waitbar(0.9 + 0.1*(i/Nneur), hwb);
            end
        end
        % Cleanup
        if use_waitbar, safeCloseWaitbar(hwb); end
    end
end

% ---------------------------------------------------------
% Funzione Obiettivo Locale (Cost Function + Gradient)
% ---------------------------------------------------------
function [f, grad] = objective_smooth_sign(w, X, y, gamma)
    % Calcolo intermedio
    % X: [P x M], w: [M x 1], y: [P x 1]
    
    linear_comb = X * w;           % [P x 1]
    arg_tanh    = gamma * linear_comb; 
    
    T = tanh(arg_tanh);            % Approssimazione del segno [-1, 1]
    
    % La funzione da MASSIMIZZARE è: sum( T .* y )
    % La funzione da MINIMIZZARE è l'opposto:
    similarity = sum(T .* y);
    f = -similarity;
    
    if nargout > 1
        % Calcolo del Gradiente Analitico per fminunc
        % d/dw ( - sum( tanh(gamma * x_i * w) * y_i ) )
        % derivata tanh(u) = 1 - tanh^2(u) = 1 - T.^2
        
        dtanh = gamma * (1 - T.^2);  % [P x 1] derivata interna scalare
        
        % Regola della catena: 
        % grad = - sum_over_frames ( dtanh * y * x_row )
        % Vettorializzato: - X' * (dtanh .* y)
        
        grad = - X' * (dtanh .* y);  % [M x 1]
    end
end

function safeCloseWaitbar(h)
    if ~isempty(h) && isvalid(h)
        try, close(h); catch, end
    end
end
