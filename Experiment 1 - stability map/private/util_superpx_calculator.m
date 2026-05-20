function [W_spx, H_spx, n_x, n_y, W_new, H_new] = util_superpx_calculator(W_ROI, H_ROI, third_arg)
%   Unified interface for computing superpixel layout.
%
%   If third_arg is a scalar (N_spx_total), it determines the superpixel size
%   and layout that tiles the ROI almost completely.
%
%   If third_arg is a 2-element vector [W_spx, H_spx], it adjusts the ROI
%   to fit an even number of full superpixels of the specified size.
%
%   Inputs:
%       W_ROI     - Width of the ROI (pixels)
%       H_ROI     - Height of the ROI (pixels)
%       third_arg - Either total number of superpixels (scalar) or
%                   superpixel size as [W_spx, H_spx]
%
%   Outputs:
%       W_spx  - Superpixel width (pixels)
%       H_spx  - Superpixel height (pixels)
%       n_x    - Number of superpixels along width
%       n_y    - Number of superpixels along height
%       W_new  - Adjusted width of the ROI
%       H_new  - Adjusted height of the ROI

    if isscalar(third_arg)
        % Case: total number of superpixels
        N_spx_total = third_arg;
        [W_spx, H_spx, n_x, n_y, W_new, H_new] = find_layout_by_number(W_ROI, H_ROI, N_spx_total);

    elseif isvector(third_arg) && numel(third_arg) == 2
        % Case: superpixel size given
        W_spx = third_arg(1);
        H_spx = third_arg(2);

        [W_new, H_new, n_x, n_y] = find_layout_by_spxside(W_ROI, H_ROI, W_spx, H_spx);

    else
        error('Third argument must be either a scalar or a 2-element vector.');
    end
end

% ========== LOCAL FUNCTION: Layout by total number of superpixels ==========
function [W_spx, H_spx, n_x, n_y, W_new, H_new] = find_layout_by_number(W_ROI, H_ROI, N_spx_total)

    best_error = inf;

    n_x_opt = sqrt(N_spx_total * (W_ROI / H_ROI));
    search_range = round(n_x_opt) - 10 : round(n_x_opt) + 10;

    for n_x_try = search_range
        if n_x_try <= 0
            continue;
        end
        if mod(N_spx_total, n_x_try) ~= 0
            continue;
        end

        n_y_try = N_spx_total / n_x_try;

        W_spx_try = floor(W_ROI / n_x_try);
        H_spx_try = floor(H_ROI / n_y_try);

        if W_spx_try <= 0 || H_spx_try <= 0
            continue;
        end

        W_used = W_spx_try * n_x_try;
        H_used = H_spx_try * n_y_try;
        unused_area = (W_ROI * H_ROI) - (W_used * H_used);

        aspect_ratio = W_spx_try / H_spx_try;
        squareness_penalty = abs(log(aspect_ratio));
        error = unused_area + 1000 * squareness_penalty;

        if error < best_error
            best_error = error;
            best_W_spx = W_spx_try;
            best_H_spx = H_spx_try;
            best_n_x   = n_x_try;
            best_n_y   = n_y_try;
            best_W_new = W_used;
            best_H_new = H_used;
        end
    end

    if best_error == inf
        error('No valid layout found within search window.');
    end

    % Assign best values to output
    W_spx = best_W_spx;
    H_spx = best_H_spx;
    n_x   = best_n_x;
    n_y   = best_n_y;
    W_new = best_W_new;
    H_new = best_H_new;

    % Assertion
    assert(n_x * n_y == N_spx_total, 'n_x * n_y ≠ N_spx_total — logic error.');

    fprintf('✅ Superpixel size: %d × %d px\n', W_spx, H_spx);
    fprintf('🧱 Superpixel grid: %d × %d (%d total)\n', n_x, n_y, n_x * n_y);
    fprintf('📐 Adjusted ROI: %d × %d px (loss: %d px)\n', ...
        W_new, H_new, W_ROI * H_ROI - W_new * H_new);
end


% ========== LOCAL FUNCTION: Adjust ROI for given superpixel size ==========
function [W_adj, H_adj, n_superpixels_x, n_superpixels_y] = find_layout_by_spxside(W_ROI, H_ROI, W_spx, H_spx)

    if any([W_ROI, H_ROI, W_spx, H_spx] <= 0)
        error('All dimensions must be positive.');
    end

    n_superpixels_x = floor(W_ROI / W_spx);
    n_superpixels_y = floor(H_ROI / H_spx);

    if mod(n_superpixels_x, 2) ~= 0
        n_superpixels_x = n_superpixels_x - 1;
    end
    if mod(n_superpixels_y, 2) ~= 0
        n_superpixels_y = n_superpixels_y - 1;
    end

    if n_superpixels_x < 2 || n_superpixels_y < 2
        error('ROI too small to fit at least 2x2 even superpixels.');
    end

    W_adj = n_superpixels_x * W_spx;
    H_adj = n_superpixels_y * H_spx;

    fprintf('✅ Adjusted ROI: %d x %d px (superpixels: %d x %d)\n', ...
        W_adj, H_adj, n_superpixels_x, n_superpixels_y);
end
