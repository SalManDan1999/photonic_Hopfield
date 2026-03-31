%% plot_mag_colormap.m
clear; clc;

%% ---- Load data ----
cfg_file = 'experiment_config.mat';
res_file = 'results.mat';
load(cfg_file,'PPP','cam_spx','timestamp'); 
load(res_file, 'mean_mag', 'std_mag');
alpha=PPP/400;
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

% Formatting
set(gca, 'Layer', 'top'); % Puts tick marks on top of the plot
colorbar;
axis tight;

% Labels with LaTeX
xlabel('$M$', 'Interpreter', 'latex', 'FontSize', 20);
ylabel('$\alpha$', 'Interpreter', 'latex', 'FontSize', 20);
ylim([0.04, 0.16]); % Set the Y-axis limit strictly to 0.12
xlim([1, 150]);
% Large tick labels
ax = gca;
ax.FontSize = 18;
ax.TickLabelInterpreter = 'latex';

% Optional: Nicer colormap
colormap('parula'); 

% Save
saveas(fig, sprintf('plot_mag_%s.fig', timestamp));