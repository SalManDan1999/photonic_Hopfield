%% plot_mag_colormap.m
clear; clc;
%% ---- Load data ----
cfg_file = 'experiment_config.mat';
res_file = 'results.mat';
load(cfg_file,'alpha','cam_spx','timestamp'); 
load(res_file, 'mean_mag','mean_mag_hebbs', 'std_mag');
% Ensure column vector for cam_spx
cam_spx = cam_spx(:);
%% ---- Build Grid Matrices ----
% X coordinates (cam_spx repeated across columns)
X = repmat(cam_spx, 1, size(alpha,2)); 
% Y coordinates (alpha is already the correct size)
Y = alpha;
% Z Data (Reliability-weighted mean)
Z_weighted = mean_mag;
%% ---- Plotting ----
fig = figure;
% Use pcolor directly on the matrices. 
% It handles the irregular spacing in alpha automatically.
h = pcolor(X, Y, Z_weighted);
% Smooth the colors
shading interp; 

% ==========================================
% NEW CODE: Add the SMOOTH dashed contour line
% ==========================================
hold on;
threshold = 0.9;

% 1. Define a high-resolution grid (e.g., 300x300 points)
num_pts = 300; 
x_fine = linspace(min(X(:)), max(X(:)), num_pts);
y_fine = linspace(min(Y(:)), max(Y(:)), num_pts);
[X_fine, Y_fine] = meshgrid(x_fine, y_fine);

% 2. Interpolate the Z data onto the high-res grid
% 'cubic' interpolation ensures a smooth, continuous mathematical curve
Z_fine = griddata(X(:), Y(:), Z_weighted(:), X_fine, Y_fine, 'cubic');

% 3. Plot the contour using the smoothed data
% [~, h_cont] = contour(X_fine, Y_fine, Z_fine, [threshold, threshold], ...
%                       'LineColor', 'k', ... 
%                       'LineStyle', '--', ...
%                       'LineWidth', 2);
hold off;
% ==========================================

% Formatting
set(gca, 'Layer', 'top'); % Puts tick marks on top of the plot
colorbar;
axis tight;
% Labels with LaTeX
xlabel('$M$', 'Interpreter', 'latex', 'FontSize', 20);
ylabel('$\alpha$', 'Interpreter', 'latex', 'FontSize', 20);
 % Set the Y-axis limit strictly to 0.12
%xlim([1, 20]);
% Large tick labels
ax = gca;
ax.FontSize = 30;
ax.TickLabelInterpreter = 'latex';
% Optional: Nicer colormap
colormap('parula'); 
% Save
% Force the vector renderer (crucial for crisp lines and a fixed colorbar)
set(fig, 'Renderer', 'painters');
% Use the print command specifically designed for SVG export
print(fig, 'retrieval_weighted.svg', '-dsvg');