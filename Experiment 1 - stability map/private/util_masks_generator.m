function [mask_disk_hole, mask_rect] = util_masks_generator(diameter, N_x, N_y)
% UTIL_MASK_GENERATOR
%   [mask_disk_hole, mask_rect] = util_mask_generator(diameter, N_x, N_y)
%   returns two logical masks of size (diameter × diameter):
%     - mask_disk_hole : centered disk of diameter "diameter" with a centered
%                        rectangular hole of size N_x × N_y removed
%     - mask_rect      : centered rectangle mask of size N_x × N_y
%
%   Notes:
%     - N_x is width (columns), N_y is height (rows).
%     - Values are clipped to the image bounds.
%     - For linear indices, use find(mask_disk_hole) / find(mask_rect).

    % --- sanitize inputs ---
    diameter = round(diameter);
    if diameter < 1, error('diameter must be >= 1'); end
    N_x = max(1, min(round(N_x), diameter));
    N_y = max(1, min(round(N_y), diameter));

    % --- coordinate grid centered at (cx, cy) ---
    [X, Y] = meshgrid(1:diameter, 1:diameter);
    cx = (diameter + 1) / 2;  % column center
    cy = (diameter + 1) / 2;  % row center

    % --- pure disk mask ---
    R = diameter / 2;
    mask_disk = ( (X - cx).^2 + (Y - cy).^2 ) <= R^2;

    % --- centered rectangle bounds (robust for odd/even) ---
    x1 = ceil(cx - (N_x - 1)/2);
    x2 = floor(cx + (N_x - 1)/2);
    y1 = ceil(cy - (N_y - 1)/2);
    y2 = floor(cy + (N_y - 1)/2);

    % clip to array
    x1 = max(1, x1); x2 = min(diameter, x2);
    y1 = max(1, y1); y2 = min(diameter, y2);

    % --- rectangle mask ---
    mask_rect = false(diameter, diameter);
    mask_rect(y1:y2, x1:x2) = true;

    % --- disk with rectangular hole ---
    mask_disk_hole = mask_disk & ~mask_rect;
end
