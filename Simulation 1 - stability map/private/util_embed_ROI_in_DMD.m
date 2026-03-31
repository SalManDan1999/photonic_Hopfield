function frame = util_embed_ROI_in_DMD(img, ul_corner, br_corner, W_DMD, H_DMD)
% EMBED_PATTERN_IN_DMD_FRAME embeds a binary image into a DMD frame.
%
%   Inputs:
%       img       - Binary image (output of util_bin_to_superpx)
%       ul_corner - [x_ul, y_ul] upper-left corner (1-based indexing)
%       br_corner - [x_br, y_br] bottom-right corner (inclusive)
%       W_DMD     - Width of the DMD (pixels)
%       H_DMD     - Height of the DMD (pixels)
%
%   Output:
%       frame - H_DMD x W_DMD binary array with img embedded in ROI

    % Input validation
    assert(all(size(img) == [br_corner(2) - ul_corner(2) + 1, br_corner(1) - ul_corner(1) + 1]), ...
        'Size of img must match ROI dimensions.');
    assert(all(ul_corner >= 1), 'ROI corner indices must be >= 1.');
    assert(br_corner(1) <= W_DMD && br_corner(2) <= H_DMD, 'ROI exceeds DMD bounds.');

    % Initialize blank DMD frame
    frame = zeros(H_DMD, W_DMD);

    % Insert image into frame at ROI location
    y_range = ul_corner(2):br_corner(2);
    x_range = ul_corner(1):br_corner(1);
    frame(y_range, x_range) = img;
end
