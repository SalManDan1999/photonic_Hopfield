function frame = util_embed_ROI_in_DMD(img, ul_corner, br_corner, W_DMD, H_DMD, backdrop)
% UTIL_EMBED_ROI_IN_DMD embeds a binary image into a DMD frame.
%
%   frame = UTIL_EMBED_ROI_IN_DMD(img, ul_corner, br_corner, W_DMD, H_DMD)
%   embeds the binary image 'img' into a blank (zero) DMD frame.
%
%   frame = UTIL_EMBED_ROI_IN_DMD(..., backdrop)
%   uses the provided 'backdrop' as the initial DMD pattern instead of zeros.
%
%   Inputs:
%       img       - Binary image (output of util_bin_to_superpx)
%       ul_corner - [x_ul, y_ul] upper-left corner (1-based indexing)
%       br_corner - [x_br, y_br] bottom-right corner (inclusive)
%       W_DMD     - Width of the DMD (pixels)
%       H_DMD     - Height of the DMD (pixels)
%       backdrop  - (optional) H_DMD x W_DMD array used as initialization
%
%   Output:
%       frame - H_DMD x W_DMD binary array with 'img' embedded in ROI.
    
    % Input validation
    assert(all(size(img) == [br_corner(2) - ul_corner(2) + 1, ...
                             br_corner(1) - ul_corner(1) + 1]), ...
        'Size of img must match ROI dimensions.');
    assert(all(ul_corner >= 1), 'ROI corner indices must be >= 1.');
    assert(br_corner(1) <= W_DMD && br_corner(2) <= H_DMD, ...
        'ROI exceeds DMD bounds.');

    % Initialize DMD frame
    if nargin >= 6 && ~isempty(backdrop)
        assert(all(size(backdrop) == [H_DMD, W_DMD]), ...
            'Backdrop must match DMD dimensions.');
        frame = backdrop;
    else
        frame = zeros(H_DMD, W_DMD);
    end

    % Embed image into ROI
    y_range = ul_corner(2):br_corner(2);
    x_range = ul_corner(1):br_corner(1);
    frame(y_range, x_range) = img;
end

