function map_idx = util_learn_mapping(local_fields, patterns, n_spx, use_gpu)
% Function to map neurons to groups of camera pixels
% -------------------------
% For each neuron pixel (from PATTERNS), pick exactly n_spx UNIQUE camera pixels
% (from LOCAL_FIELDS) whose sign time-series best match the neuron's series,
% across P frames. Camera zeros are ignored.
% Global uniqueness: a camera pixel cannot be assigned to two different neurons.
% If multiple neurons want the same camera pixel in the same round, break ties
% by the current rank (score + tiny confidence).
%
% Strategy (fast + memory-light)
% ------------------------------
% 1) Process camera pixels in blocks and compute agreement scores with GEMM (GPU if available):
%       score(j,i) = ( nonzeros_in_cam(j) + dot(sign(cam_j), sign(neur_i)) ) / 2
%    Add a tiny confidence tiebreak: rank = score + eps * norm_confidence(j),
%    where confidence(j) = min_mu |local_field_j(mu)|.
% 2) For each neuron, keep only the top-K camera candidates (rank + index).
% 3) Greedy multi-assignment loop over the top-K lists until each neuron has n_spx pixels,
%    always enforcing global uniqueness (no camera reuse).
%
% Inputs
%   local_fields : [H_cam x W_cam x P] real-valued local fields
%   patterns     : [H_neur x W_neur x P] strictly in {-1,+1}
%   n_spx        : positive integer, #camera pixels to assign per neuron
%   use_gpu      : (optional, default true) compute GEMMs on GPU if available
%
% Output
%   map_idx      : [H_neur*W_neur x n_spx]  UNIQUE linear indices into LOCAL_FIELDS
%
% Notes
%   - For strict feasibility under global uniqueness, you typically need
%       N_cam >= n_spx * N_neur
%     (otherwise some neurons may not reach n_spx assignments).
%   - Memory stays small: we never build the full [N_cam x N_neur] score matrix.

    if nargin < 4, use_gpu = true; end
    if ~(isscalar(n_spx) && n_spx>=1 && n_spx==floor(n_spx))
        error('n_spx must be a positive integer.');
    end

    % -------- Dimensions --------
    [Hcam, Wcam, P]    = size(local_fields);
    [Hneur, Wneur, P2] = size(patterns);
    if P ~= P2, error('Mismatch in frame count: %d vs %d.', P, P2); end

    Ncam  = Hcam  * Wcam;     % # camera pixels
    Nneur = Hneur * Wneur;    % # neuron pixels

    % Feasibility checks (soft and hard)
    if Ncam < Nneur
        error('Mapping impossible: N_cam (%d) < N_neur (%d).', Ncam, Nneur);
    end
    if Ncam < Nneur * n_spx
        warning('N_cam (%d) < N_neur * n_spx (%d): strict global uniqueness may be impossible.', ...
                Ncam, Nneur*n_spx);
    end

    % -------- Flatten stacks : time - namely pattern index - is 2dim now. --------
    camFields = reshape(local_fields, [], P);   % [Ncam  x P]
    neurSigns = reshape(patterns,     [], P);   % [Nneur x P]

    % -------- Precompute camera signs and per-camera stats --------
    camSign = int8(sign(camFields));                 % [-1,0,+1]
    camNZ   = sum(camSign ~= 0, 2, 'native');        % [Ncam x 1]
    camConf = min(abs(camFields), [], 2);            % [Ncam x 1] min|field|

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

    % -------- Keep top-K candidates per neuron --------
    KKK = min( Nneur*n_spx, Ncam ); % I keep for each neuron a list long KKK of the best cam px to associate

    if use_gpu
        topRank   = -inf(KKK, Nneur, 'single', 'gpuArray');   % [K x Nneur]
        topCamIdx = zeros(KKK, Nneur, 'uint32', 'gpuArray');  % [K x Nneur]
    else
        topRank   = -inf(KKK, Nneur, 'single');
        topCamIdx = zeros(KKK, Nneur, 'uint32');
    end

    % -------- Progress UI --------
    hwb = waitbar(0, 'Mapping (vectorized)... 0%', 'Name', 'Pixel mapping progress');
    cleanupObj = onCleanup(@() safeCloseWaitbar(hwb));

    % -------- Blocked scan over camera pixels --------
    camBlockRows = 10000;  % tune if needed
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

        % Agreement score with optimal global flip: (nz + d) / 2
        score_blk = (camNZ_blk + d_blk) / 2;          % [B x Nneur]

        % Tiny confidence tie-break
        rank_blk  = score_blk + epsTie .* conf_blk;   % [B x Nneur]

        % For each neuron, take top-K within this block
        [rank_topB, idx_topB] = maxk(rank_blk, KKK, 1);         % [K x Nneur]
        camIdx_topB = uint32(camStart - 1) + uint32(idx_topB);  % global indices

        % Merge with running global top-K
        rank_cand = [topRank;   rank_topB];   % [2K x Nneur]
        idx_cand  = [topCamIdx; camIdx_topB]; % [2K x Nneur]
        [rank_new, pos] = maxk(rank_cand, KKK, 1);

        lin = sub2ind(size(idx_cand), pos, repmat(uint32(1:Nneur), KKK, 1));
        idx_new = idx_cand(lin);

        topRank   = rank_new;
        topCamIdx = reshape(idx_new, KKK, Nneur);

        % Progress
        if isvalid(hwb)
            frac = camEnd / Ncam;
            waitbar(frac, hwb, sprintf('Mapping... %d%%', round(100*frac)));
        end

        % Free block temporaries on GPU
        if use_gpu
            clear d_blk score_blk rank_blk rank_topB idx_topB camIdx_topB rank_cand idx_cand rank_new pos lin idx_new
        end
    end

    % -------- Multi-assignment with global uniqueness --------
    topRank   = gather(topRank);    % [K x Nneur] on CPU
    topCamIdx = gather(topCamIdx);  % [K x Nneur] on CPU

    isCamUsed   = false(Ncam,1);                 % camera pixel already assigned to some neuron?
    choicePtr   = ones(Nneur,1,'uint32');        % per neuron: which candidate (1..K) we are considering now
    takenCount  = zeros(Nneur,1,'uint32');       % how many camera pixels each neuron has received
    neededTotal = uint32(Nneur) * uint32(n_spx);

    map_idx = zeros(Nneur, n_spx, 'uint32');     % OUTPUT: row i lists the n_spx camera indices

    assignedTotal = uint32(0);

    while assignedTotal < neededTotal
        % Build one proposed camera per *still-needing* neuron
        proposedCam = zeros(Nneur,1,'uint32');
        for i = 1:Nneur
            if takenCount(i) < n_spx
                p = choicePtr(i);
                % Skip already-used camera pixels
                while p <= KKK && isCamUsed( topCamIdx(p,i) )
                    p = p + 1;
                end
                if p > KKK
                    error(['Cannot complete unique multi-assignment for neuron %d: ' ...
                           'increase K or verify inputs (N_cam may be too small).'], i);
                end
                choicePtr(i)  = p;
                proposedCam(i)= topCamIdx(p,i);
            end
        end

        activeMask      = (takenCount < n_spx) & (proposedCam > 0);
        if ~any(activeMask)
            error('No valid candidates remaining; increase K or verify inputs.');
        end

        proposedCam_act = proposedCam(activeMask);
        neurIdx_act     = find(activeMask);
        [uniqueCam, ~, camGroupId] = unique(proposedCam_act, 'stable');

        % Resolve conflicts: if several neurons want the same camera pixel,
        % assign it to the one with highest current rank for that pixel
        for g = 1:numel(uniqueCam)
            cam = uniqueCam(g);
            if isCamUsed(cam)
                continue; % already given in a previous iteration
            end

            groupNeurs = neurIdx_act(camGroupId == g);   % neurons competing for 'cam'
            if numel(groupNeurs) == 1
                ii = groupNeurs(1);
                % Assign this camera to neuron ii
                takenCount(ii) = takenCount(ii) + 1;
                map_idx(ii, takenCount(ii)) = cam;
                isCamUsed(cam) = true;
                assignedTotal = assignedTotal + 1;
            else
                % Choose winner by rank at current candidate slot
                p_vec   = choicePtr(groupNeurs);
                linRank = sub2ind(size(topRank), p_vec, groupNeurs);
                rvals   = topRank(linRank);
                [~, relBest] = max(rvals);
                ii_win = groupNeurs(relBest);

                takenCount(ii_win) = takenCount(ii_win) + 1;
                map_idx(ii_win, takenCount(ii_win)) = cam;
                isCamUsed(cam) = true;
                assignedTotal = assignedTotal + 1;
                % Others will advance to their next candidate in subsequent rounds
            end
        end
    end

    % Ensure column-major consistent output shape (Nneur x n_spx)
    map_idx = uint32(map_idx);

end

function safeCloseWaitbar(h)
    if ~isempty(h) && isvalid(h)
        try, close(h); catch, end
    end
end
