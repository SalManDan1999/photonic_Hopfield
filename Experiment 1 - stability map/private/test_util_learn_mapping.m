% test_util_learn_mapping.m
clear; clc;

% -------- local_fields : [H_cam x W_cam x P] = 3 x 3 x 3 --------
L1 = [  2  -5 -20;
       40  -7 -10;
      -12  -4   8];

L2 = [ -5   2  -7;
        3  10  -8;
        9  12  -4];

L3 = [ 31 -17  -7;
        3  10  -8;
       74  12 -24];

local_fields = cat(3, L1, L2, L3);

% -------- patterns : [H_neur x W_neur x P] = 2 x 2 x 3 --------
P1 = [ 1 -1;
      -1  1];

P2 = [-1 -1;
       1 -1];

P3 = [ 1 -1;
       1 -1];

patterns = cat(3, P1, P2, P3);

% Sanity check
[Hcam, Wcam, P]    = size(local_fields);
[Hneur, Wneur, P2] = size(patterns);
assert(P == P2, 'Frame count mismatch.');

% -------- Call your function (CPU to avoid GPU dependency here) --------
use_gpu = false;  % set true if you have GPU available and want to test it
map_idx = util_learn_mapping(local_fields, patterns, use_gpu);

% -------- Show results --------
disp('Linear indices into camera (3x3) for each neuron (2x2 order):');
disp(reshape(map_idx, Hneur, Wneur));

% Also show (row, col) for readability
[rr, cc] = ind2sub([Hcam, Wcam], double(map_idx));
fprintf('\nMapping (row,col) per neuron in row-major neuron order:\n');
for i = 1:numel(map_idx)
    fprintf('Neuron %d -> cam (%d, %d)\n', i, rr(i), cc(i));
end

% Optional: quick visualization of chosen camera pixels per neuron position
% (purely illustrative)
% chosen = zeros(Hcam, Wcam); chosen(map_idx) = 1;
% figure; imagesc(chosen); axis image; colorbar; title('Chosen camera pixels');
% set(gca,'XTick',1:Wcam,'YTick',1:Hcam);