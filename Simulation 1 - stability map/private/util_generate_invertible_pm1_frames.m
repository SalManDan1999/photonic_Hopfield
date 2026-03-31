function frames = util_generate_invertible_pm1_frames(Nx, Ny)
% UTIL_GENERATE_INVERTIBLE_PM1_FRAMES
%   Generate N = Nx*Ny random ±1 frames of size Nx x Ny such that the
%   matrix X (N x N) whose columns are the vectorized frames is invertible.
%
%   frames = util_generate_invertible_pm1_frames(Nx, Ny)
%
%   OUTPUT:
%     frames : [Nx x Ny x N] array, each frames(:,:,k) is a ±1 frame
%              and the matrix X built as:
%                 X(:,k) = frames(:,:,k)(:)
%              is numerically invertible.
%
%   NOTES:
%     - Uses random Rademacher entries (±1) via sign(randn).
%     - Repeats drawing until rcond(X) is above a small threshold.

    N = Nx * Ny;
    maxTries = 100;     % just in case (practically you'll hit on try 1)
    tol = 1e-12;         % conditioning threshold

    for attempt = 1:maxTries
        % Random ±1 matrix (each column is a probe vector)
        X = sign(randn(N, N));

        % Check if X is numerically invertible
        if rcond(X) > tol
            % Reshape columns into frames:
            % X is [N x N] with N = Nx*Ny.
            % reshape(X, [Nx, Ny, N]) makes frames(:,:,k)
            % from column k of X.
            frames = reshape(X, [Nx, Ny, N]);
            return;
        end
    end

    error('Failed to generate an invertible ±1 matrix after %d attempts.', maxTries);
end
