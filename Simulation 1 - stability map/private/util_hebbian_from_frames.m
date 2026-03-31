function W = util_hebbian_from_frames(frames)
% UTIL_HEBBIAN_FROM_FRAMES
%   Compute the Hebbian coupling matrix from an array of P frames.
%
%   W = util_hebbian_from_frames(frames)
%
%   INPUT:
%       frames : [Nx x Ny x P] array of patterns, entries ±1 (or any real values)
%
%   OUTPUT:
%       W : [N x N] Hebbian matrix, where N = Nx*Ny
%
%   DEFINITION:
%       If x_p is the vectorized p-th frame, the matrix is
%           W = sum_p x_p * x_p'
%
%   NOTE:
%       No self-interaction removal is done here. Add diag set to zero if needed.

    % Extract dimensions
    [Nx, Ny, P] = size(frames);
    N = Nx * Ny;

    % Reshape all frames into a matrix X = [x1 x2 ... xP]
    X = reshape(frames, [N, P]);

    % Compute Hebbian matrix W = X * X'
    W = X * X.'/N;
    % CRUCIAL FIX: Zero out the diagonal to remove self-connections
    W(1:N+1:end) = 0;
end
