function [mask, first_row, last_row] = util_roi_mask(W_DMD, H_DMD, W_ROI, H_ROI, x_shift, y_shift)
% UTIL_ROI_MASK Creates a logical mask for a centered (or shifted) ROI inside the DMD,
% and returns the first and last rows containing nonzero elements.
%
%   [mask, first_row, last_row] = util_roi_mask(W_DMD, H_DMD, W_ROI, H_ROI)
%       --> ROI is centered in the DMD.
%
%   [mask, first_row, last_row] = util_roi_mask(W_DMD, H_DMD, W_ROI, H_ROI, x_shift, y_shift)
%       --> ROI is shifted from center by x_shift and y_shift (in pixels).
%
%   OUTPUT:
%       mask       : logical matrix [H_DMD × W_DMD] with 'true' inside ROI
%       first_row  : first row index containing any true element
%       last_row   : last  row index containing any true element

    % Default to zero shift if not provided
    if nargin < 5, x_shift = 0; end
    if nargin < 6, y_shift = 0; end

    % Validate ROI size
    if W_ROI > W_DMD || H_ROI > H_DMD
        error('ROI size must be smaller than or equal to DMD size.');
    end

    % Compute max shift and clip if needed
    max_x_shift = floor((W_DMD - W_ROI) / 2);
    max_y_shift = floor((H_DMD - H_ROI) / 2);
    x_shift = max(min(x_shift, max_x_shift), -max_x_shift);
    y_shift = max(min(y_shift, max_y_shift), -max_y_shift);

    % Compute top-left corner (1-based indexing)
    X1 = floor((W_DMD - W_ROI)/2) + x_shift + 1; % +1 for MATLAB indexing
    Y1 = floor((H_DMD - H_ROI)/2) + y_shift + 1;

    % Compute bottom-right corner
    X2 = X1 + W_ROI - 1;
    Y2 = Y1 + H_ROI - 1;

    % Create mask
    mask = false(H_DMD, W_DMD);
    mask(Y1:Y2, X1:X2) = true;

    % Return first and last nonzero rows (trivial for rectangular ROI)
    first_row = Y1;
    last_row  = Y2;
end
