function chess = util_chessboard(N_x, N_y, n_x, n_y)
% GENERATE_CHESSBOARD
%   Create a ±1 checkerboard for a superpixelized pattern.
%   Step 1: base chessboard  (-1)^(row+col)
%   Step 2: correction by superpixel blocks:
%           if n_x is odd, multiply by (-1)^(Column_x)
%           if n_y is odd, multiply by (-1)^(Column_y)
%           if both odd,  multiply by (-1)^(Column_x + Column_y)
%
%   INPUTS
%     N_x : number of columns of the input matrix X
%     N_y : number of rows    of the input matrix X
%     n_x : superpixel width  (columns per input element)
%     n_y : superpixel height (rows per input element)
%
%   OUTPUT
%     chess : (N_y*n_y) × (N_x*n_x) matrix with entries in {-1,+1}
%             and top-left element = +1.

    arguments
        N_x (1,1) {mustBeInteger, mustBePositive}
        N_y (1,1) {mustBeInteger, mustBePositive}
        n_x (1,1) {mustBeInteger, mustBePositive}
        n_y (1,1) {mustBeInteger, mustBePositive}
    end

    % Pixel dimensions
    W = N_x * n_x;   % columns
    H = N_y * n_y;   % rows

    % --- 1) Base chessboard: (-1)^(row+col) with 1-based indices
    [rr, cc] = ndgrid(1:H, 1:W);
    chess = (-1).^(rr + cc);   % top-left = +1

    % --- 2) Block correction using superpixel block indices
    % Column_x(j) = floor((j-1)/n_x) -> 1 x W vector
    % Column_y(i) = floor((i-1)/n_y) -> H x 1 vector
    % Use them only when the corresponding n_x or n_y is odd.
    if mod(n_x, 2) == 1
        col_blocks = floor((0:W-1) / n_x);   % 1 x W
    else
        col_blocks = zeros(1, W);            % no correction along x
    end

    if mod(n_y, 2) == 1
        row_blocks = floor((0:H-1)' / n_y);  % H x 1
    else
        row_blocks = zeros(H, 1);            % no correction along y
    end

    % Correction factor: (-1)^(Column_x + Column_y)
    % (Implicit expansion combines Hx1 + 1xW into HxW)
    correction = (-1).^(row_blocks + col_blocks);

    % Apply correction
    chess = chess .* correction;
end
