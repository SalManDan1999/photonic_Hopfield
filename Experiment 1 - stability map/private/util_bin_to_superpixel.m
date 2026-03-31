function img = util_bin_to_superpixel(X, n_x, n_y, chess)
% UTIL_BIN_TO_SUPERPIXEL
%   Expands a {-1,+1} matrix X by (n_y × n_x) into superpixels and
%   multiplies by a provided checkerboard 'chess' (also in {-1,+1}).
%   Maps result from {-1,0,+1} to {0,1} and returns uint8.
%
%   INPUT
%     X      : a×b matrix with entries in {-1,+1}
%     n_x    : superpixel width  (columns per element)
%     n_y    : superpixel height (rows per element)
%     chess  : (a*n_y)×(b*n_x) checkerboard in {-1,+1}, top-left +1
%
%   OUTPUT
%     img    : (a*n_y)×(b*n_x) uint8 matrix with entries {0,1}

    arguments
        X {mustBeNumeric, mustBeReal}
        n_x (1,1) {mustBeInteger, mustBePositive}
        n_y (1,1) {mustBeInteger, mustBePositive}
        chess {mustBeNumeric, mustBeReal}
    end

    % Validate X values
    if ~all(X(:) == -1 | X(:) == 1 | X(:) == 0)
        error('X must contain only 0, -1 or +1.');
    end

    % Target size and chessboard checks
    a = size(X,1); b = size(X,2);
    H = a*n_y; W = b*n_x;

    if ~isequal(size(chess), [H, W])
        error('chess must be of size %d×%d.', H, W);
    end
    if ~all(chess(:) == -1 | chess(:) == 1)
        error('chess must contain only -1 or +1.');
    end

    % Upsample X to superpixels
    X_up = repelem(X, n_y, n_x);   % same as kron(X, ones(n_y,n_x))

    % Multiply by checkerboard and map {-1,0,+1} -> {0,255} as DMD wants
    img = uint8(floor((double(X_up) .* chess + 1) / 2)*255);
end
