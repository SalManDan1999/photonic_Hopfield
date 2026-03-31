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
% 3) Assign initial weights (+1 or -1) based on the sign of the dot product.
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
    % We now also track topSign (The sign of the dot product for the best pixels)
    if use_gpu
        topRank   = -inf(n_spx, Nneur, 'single', 'gpuArray');   
        topCamIdx = zeros(n_spx, Nneur, 'uint32', 'gpuArray');  
        topSign   = ones(n_spx, Nneur, 'single', 'gpuArray');   % Tracks +1/-1
    else
        topRank   = -inf(n_spx, Nneur, 'single');
        topCamIdx = zeros(n_spx, Nneur, 'uint32');
        topSign   = ones(n_spx, Nneur, 'single');
    end
    
    if use_waitbar
        hwb = waitbar(0, 'Mapping (vectorized)... 0%', 'Name', 'Pixel mapping progress');
        cleanupObj = onCleanup(@() safeCloseWaitbar(hwb));
    end
    
    % -------- Blocked scan over camera pixels --------
    camBlockRows = 10000; 
    
    for camStart = 1:camBlockRows:Ncam
        camEnd   = min(camStart + camBlockRows - 1, Ncam);
        B        = camEnd - camStart + 1;
        
        % Current camera block
        camSign_blk = camSign(camStart:camEnd, :);   
        camNZ_blk   = single(camNZ(camStart:camEnd));
        conf_blk    = confNorm(camStart:camEnd);
        
        if use_gpu
            camSign_blk = gpuArray(single(camSign_blk)); 
            camNZ_blk   = gpuArray(camNZ_blk);
            conf_blk    = gpuArray(conf_blk);
        else
            camSign_blk = single(camSign_blk);
        end
        
        % 1. Compute Raw Dot Product (contains sign info)
        d_blk = camSign_blk * neurSignsT;             % [B x Nneur]
        
        % 2. Compute Score based on Absolute Correlation
        %    We want high magnitude correlation, regardless of sign.
        score_blk = (camNZ_blk + abs(d_blk)) / 2;     % [B x Nneur]
        
        % Tiny confidence tie-break
        rank_blk  = score_blk + epsTie .* conf_blk;   
        
        % 3. Select best local candidates
        [rank_topB, idx_topB] = maxk(rank_blk, n_spx, 1);  % [n_spx x Nneur]
        camIdx_topB = uint32(camStart - 1) + uint32(idx_topB);  
        
        % 4. Extract SIGNS safely using sub2ind
        % rank_blk and d_blk have size [B x Nneur]
        cols_sub_blk = repmat(1:Nneur, n_spx, 1);
        lin_idx_blk  = sub2ind(size(d_blk), idx_topB, cols_sub_blk);
        
        raw_vals = d_blk(lin_idx_blk); 
        sign_topB = sign(raw_vals);
        
        sign_topB(sign_topB == 0) = 1;
        
        % 5. Merge with running global top-K
        rank_cand = [topRank;   rank_topB];   % [2*n_spx x Nneur]
        idx_cand  = [topCamIdx; camIdx_topB]; 
        sign_cand = [topSign;   sign_topB];   % Merge signs too
        
        [rank_new, pos] = maxk(rank_cand, n_spx, 1); 
        
        % pos contains row indices (1..2*n_spx). 
        % We need linear indices to extract from idx_cand and sign_cand.
        % We revert to sub2ind for safety against precision loss on GPU.
        
        % Create column subscripts: 1 repeated down, 2 repeated down, etc.
        cols_sub = repmat(1:Nneur, n_spx, 1);
        
        % Calculate linear indices safely
        % size(idx_cand) is [2*n_spx, Nneur]
        lin = sub2ind(size(idx_cand), pos, cols_sub);
        
        % Extract and Reshape
        topRank   = rank_new;
        topCamIdx = reshape(idx_cand(lin), n_spx, Nneur);
        topSign   = reshape(sign_cand(lin), n_spx, Nneur);
        
        if use_waitbar
            frac = camEnd / Ncam;
            waitbar(frac, hwb, sprintf('Mapping... %d%%', round(100*frac)));
        end
        
        if use_gpu
            clear d_blk score_blk rank_blk rank_topB idx_topB camIdx_topB ...
                  rank_cand idx_cand sign_cand rank_new pos lin raw_vals sign_topB col_offset col_offset_cand
        end
    end
    
    % -------- Final Output Generation --------
    topCamIdx = gather(topCamIdx);
    topSign   = gather(topSign);
    map_idx     = uint32(topCamIdx');    % [Nneur x n_spx]
    
    % Directly use the tracked signs as initial weights
    map_weights = single(topSign');      % [Nneur x n_spx]
    % ---------------------------------------------------------------------
    % Phase 2: weights optimization
    % ---------------------------------------------------------------------
    if use_waitbar
        waitbar(0.9, hwb, 'Ottimizzazione dei pesi...');
    end
    
    if use_weights
        % Optimizer options
        % 'SpecifyObjectiveGradient': true makes execution way faster
        optOptions = optimoptions('fminunc', ...
            'Display', 'off', ...
            'Algorithm', 'quasi-newton', ...
            'SpecifyObjectiveGradient', true, ...
            'MaxFunctionEvaluations', 100); 
    
        % FIXING SLOPE OF tanh (the sharper, the more similar to sign function)
        % Dynamically determine gamma based on global field variance
        % We want gamma * X * w to be roughly around 1.0 initially.
        % Assuming w has magnitude sqrt(n_spx) initially (since it's +/- 1):
        std_fields = std(double(camFields(:)), 'omitnan'); 
        if std_fields > 0
            % Scale so the initial dot product standard deviation is ~1.0
            gamma = 1.0 / (std_fields * sqrt(n_spx));
        else
            gamma = 1.0; % Fallback
        end

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
            
            % 2. Inizializzazione 
            w_init = map_weights(i,:); 
            
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
                w_opt = w_init;
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
    % Hyperparameter for L2 regularization (tune if necessary, usually a small value works)
    lambda = 0.01; 

    linear_comb = X * w;           % [P x 1]
    arg_tanh    = gamma * linear_comb; 
    
    T = tanh(arg_tanh);            % Approximation of sign [-1, 1]
    
    % The function to MINIMIZE is the negative similarity + L2 penalty
    similarity = sum(T .* y);
    penalty = lambda * sum(w.^2);
    f = -similarity + penalty;
    
    if nargout > 1
        % Gradient of the tanh part
        dtanh = gamma * (1 - T.^2);  % [P x 1] scalar inner derivative
        grad_sim = - X' * (dtanh .* y);  % [M x 1]
        
        % Gradient of the penalty part
        grad_penalty = 2 * lambda * w;
        
        % Total gradient
        grad = grad_sim + grad_penalty;
    end
end

function safeCloseWaitbar(h)
    if ~isempty(h) && isvalid(h)
        try, close(h); catch, end
    end
end
