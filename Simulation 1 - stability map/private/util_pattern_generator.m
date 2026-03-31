function [bases, patterns] = util_pattern_generator(N_x, N_y, P, M, flip_frac)
%UTIL_PATTERN_GENERATOR  Build base patterns and an augmented noisy set.
%
% [bases, patterns] = util_pattern_generator(N_x, N_y, P, M, flip_frac)
%
% Inputs
%   N_x, N_y  : spatial size of each pattern (rows, cols)
%   P         : number of distinct base patterns to generate
%   M         : number of noisy copies per base pattern
%   flip_frac : fraction (0..1) of spins flipped inside each noisy copy
%
% Outputs
%   bases     : N_x x N_y x P array of ±1 (only the clean base patterns)
%   patterns  : N_x x N_y x (2*(M+1)*P) array of ±1
%               For each base pattern p, frames are ordered as:
%                 1. Clean base
%                 2. Global flip of base
%                 3. M noisy copies
%                 4. M global flips of the noisy copies
%
% Example
%   [B, A] = util_pattern_generator(28,28,2,3,0.05);
%   size(B)  % -> [28  28   2]
%   size(A)  % -> [28  28  16], since 2*(M+1)*P = 16

    % ---- preallocate ----
    bases = zeros(N_x, N_y, P, 'double');
    total_frames = 2 * (M + 1) * P;
    patterns = zeros(N_x, N_y, total_frames, 'double');

    write_pos = 1;  % cursor for 3rd dimension of 'patterns'

    for p = 1:P
        % Base pattern in {-1, +1}
        base = 2*(rand(N_x, N_y) > 0.5) - 1;
        bases(:, :, p) = base;

        % --- clean base ---
        patterns(:, :, write_pos) = base;
        write_pos = write_pos + 1;

        % --- global flip of base ---
        patterns(:, :, write_pos) = -base;
        write_pos = write_pos + 1;

        if M > 0
            % --- noisy copies ---
            % flip_mask: +1 (keep) or -1 (flip) with prob(flip)=flip_frac
            flip_mask = 1 - 2*(rand(N_x, N_y, M) < flip_frac);  % [N_x x N_y x M]
            noisy = base .* flip_mask;

            patterns(:, :, write_pos : write_pos + M - 1) = noisy;
            write_pos = write_pos + M;

            % --- global flips of noisy copies ---
            patterns(:, :, write_pos : write_pos + M - 1) = -noisy;
            write_pos = write_pos + M;
        end
    end
end
