function out = local_fields_calculator(state_in, E, T, returnSigns, n_spx)
% LOCAL_FIELDS_CALCULATOR, only valid for SIMULATIONS.
% Computes local fields as given by the difference on the camera plane:
%   h_j = Re( E_j * sum_k conj(T_{j,k}) * s_k )
% Optionally returns only their signs. Optionally groups them in
% superpixels (whose pixels are not neighbours in general) provided that E
% and T have already been remapped and reordered.
%
% Zero-handling (only if returnSigns=true):
%   - If any field equals 0, its sign is drawn uniformly from {-1,+1}.

    if nargin < 5
        n_spx = 1;
    end

    % ---- Sizes & checks
    [Nx, Ny] = size(state_in);
    N_neur     = Nx * Ny;

    Evec  = E(:);
    N_out = numel(Evec);

    [Tr, Tc] = size(T);
    if Tr ~= N_out || Tc ~= N_neur
        error('T must be (cam_x*cam_y) x (N_x*N_y). Got %dx%d, expected %dx%d.', ...
              Tr, Tc, N_out, N_neur);
    end

    % ---- Vectorize spins and compute camera-plane local fields once
    s     = state_in(:);                               % N_in x 1
    z_cam = conj(T) * s;                               % N_out x 1
    h_cam = real(Evec .* z_cam);                       % N_out x 1

    if n_spx==1
        h=h_cam;
    else 
        h = sum(reshape(h_cam, n_spx, []), 1);
    end

    % ---- Signs or raw fields
    if ~returnSigns
        out = h(:);
    else
        out = sign(h);
        zero_idx = (out == 0);
        if any(zero_idx)
            out(zero_idx) = 2*(rand(sum(zero_idx),1) > 0.5) - 1;  % random ±1
        end
        out = out(:);
    end
end
