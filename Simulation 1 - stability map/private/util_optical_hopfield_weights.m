function W = util_optical_hopfield_weights(T, E, map_idx, map_weights)
%% === Function to compute weights of the Hopfield dynamics === 
% USE THIS ONLY FOR SIMULATIONS. It builds the coupling matrix photonic computer
% sees assuming to know the electric field of the reference and the transmission matrix.
%
% W(j,k) = sum_{i in superpixel j} map_weights(i,j) * E(i) * T(i,k)
%
% Inputs:
%   T           : [Ncam x Nneur]  (real or complex)
%   E           : [Ncam x 1] OR [cam_x x cam_y] (complex)
%   map_idx     : {Nneur x 1} cell of index vectors OR numeric [Nneur x n_spx]
%   map_weights : {Nneur x 1} cell of weight vectors OR numeric [Nneur x n_spx]
%                 Must have the same shape as map_idx.
% Output:
%   W           : [Nneur x Nneur] (always real)

    % ---- Normalize E to a column vector [Ncam x 1]
    Evec = E(:);
    [Ncam_T, Nneur] = size(T);
    if numel(Evec) ~= Ncam_T
        error('Length(E) = %d does not match size(T,1) = %d.', numel(Evec), Ncam_T);
    end

    % ---- Normalize map_idx and map_weights to cells {Nneur x 1}
    if iscell(map_idx)
        if ~iscell(map_weights)
            error('If map_idx is a cell array, map_weights must also be a cell array.');
        end
        if numel(map_idx) ~= Nneur || numel(map_weights) ~= Nneur
            error('map_idx and map_weights cells must be {Nneur x 1}.');
        end
        MI = map_idx(:);
        MW = map_weights(:);
    else
        % Numeric case
        if iscell(map_weights)
             error('If map_idx is numeric, map_weights must also be numeric.');
        end
        if ~(isnumeric(map_idx) && size(map_idx,1) == Nneur && ndims(map_idx)==2)
            error('map_idx must be numeric [Nneur x n_spx] or cell {Nneur x 1}.');
        end
        if ~all(size(map_idx) == size(map_weights))
             error('map_weights must have the same size as map_idx.');
        end

        Mnum = double(map_idx);
        Wnum = double(map_weights);
        
        Mnum(~isfinite(Mnum)) = 0;            % allow NaN placeholders
        MI = cell(Nneur,1);
        MW = cell(Nneur,1);
        
        for j = 1:Nneur
            v_idx = Mnum(j,:);
            v_wgt = Wnum(j,:);
            
            % Identify valid indices
            mask = (v_idx >= 1 & v_idx <= Ncam_T);
            
            % Keep only valid indices and corresponding weights
            MI{j} = uint32(v_idx(mask)'); 
            MW{j} = double(v_wgt(mask)');
        end
    end

    % ---- Build sparse selection matrix Msel: [Ncam x Nneur]
    % Msel(i,j) = weight if pixel i is in superpixel j, else 0
    counts = cellfun(@numel, MI);
    total  = sum(counts);
    
    if total == 0
        W = zeros(Nneur, Nneur, 'like', T);
        return;
    end
    
    I = zeros(total,1,'uint32'); % Row indices (Pixels)
    J = zeros(total,1,'uint32'); % Col indices (Neurons)
    V = zeros(total,1,'double'); % Values (Weights)
    
    pos = 1;
    for j = 1:Nneur
        v_idx = MI{j};
        v_wgt = MW{j};
        n = numel(v_idx);
        
        if numel(v_wgt) ~= n
            error('Mismatch in number of elements between index and weight vectors for neuron %d.', j);
        end
        
        if n
            I(pos:pos+n-1) = v_idx;
            J(pos:pos+n-1) = j;
            V(pos:pos+n-1) = v_wgt; % Assign weights to values
            pos = pos + n;
        end
    end

    % Construct sparse matrix using the weights V instead of ones
    Msel = sparse(double(I), double(J), V, Ncam_T, Nneur);

    % ---- Compute W = Msel' * (diag(E) * T) without forming diag(E)
    % Element-wise multiply T rows by E (broadcast across columns)
    % Then multiply by weighted selection matrix Msel' to sum over superpixels
    
    X = real(double(conj(T)) .* double(Evec));   % [Ncam x Nneur]
    W = full(Msel' * X);      % [Nneur x Nneur]
end