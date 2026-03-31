function [X_CORN1_ROI, Y_CORN1_ROI, X_CORN2_ROI, Y_CORN2_ROI] = util_roi_definition(W_DMD, H_DMD, W_ROI, H_ROI, x_shift, y_shift)
% UTIL_ROI_DEFINITION Computes the top-left and bottom-right corner coordinates of a centered (or shifted) ROI inside the DMD.
%
%   [X1, Y1, X2, Y2] = util_roi_definition(W_DMD, H_DMD, W_ROI, H_ROI)
%       --> ROI is centered in the DMD.
%
%   [X1, Y1, X2, Y2] = util_roi_definition(W_DMD, H_DMD, W_ROI, H_ROI, x_shift, y_shift)
%       --> ROI is shifted from center by x_shift and y_shift (in pixels).
%
%   All coordinates are 1-based and inclusive.
%
%   Outputs:
%       X_CORN1_ROI - x of top-left corner
%       Y_CORN1_ROI - y of top-left corner
%       X_CORN2_ROI - x of bottom-right corner
%       Y_CORN2_ROI - y of bottom-right corner

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
    X_CORN1_ROI = floor((W_DMD - W_ROI)/2) + x_shift;
    Y_CORN1_ROI = floor((H_DMD - H_ROI)/2) + y_shift;

    % Compute bottom-right corner
    X_CORN2_ROI = X_CORN1_ROI + W_ROI - 1;
    Y_CORN2_ROI = Y_CORN1_ROI + H_ROI - 1;
end
