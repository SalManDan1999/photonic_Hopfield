function [M, baseline] = generate_complex_field(cam_x, cam_y, sigma1, sigma2, varargin)
% GENERATE_COMPLEX_FIELD
%   [M, baseline] = generate_complex_field(cam_x, cam_y, sigma1, sigma2)
%   returns a cam_x-by-cam_y complex matrix M where
%       M(i,j) = baseline + noise(i,j)
%   with:
%     baseline ~ N(0, sigma1^2) + i N(0, sigma1^2)   (one scalar shared by all pixels)
%     noise(i,j) ~ N(0, sigma2^2) + i N(0, sigma2^2) (independent per pixel)
%
%   Optional name-value pairs:
%     'Seed'  : integer RNG seed for reproducibility (default: [])
%     'Class' : 'double' (default) or 'single'
%
%   Example:
%     [M, b] = generate_complex_field(256, 256, 0.5, 0.1, 'Seed', 42, 'Class', 'single');

    % --- Parse inputs
    p = inputParser;
    addRequired(p, 'cam_x',  @(x)isnumeric(x)&&isscalar(x)&&x==floor(x)&&x>0);
    addRequired(p, 'cam_y',  @(x)isnumeric(x)&&isscalar(x)&&x==floor(x)&&x>0);
    addRequired(p, 'sigma1', @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    addRequired(p, 'sigma2', @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    addParameter(p, 'Seed',  [], @(x)isnumeric(x)&&isscalar(x));
    addParameter(p, 'Class', 'double', @(s)ischar(s)||isstring(s));
    parse(p, cam_x, cam_y, sigma1, sigma2, varargin{:});

    cls = lower(string(p.Results.Class));
    if cls ~= "single" && cls ~= "double"
        error('Class must be ''single'' or ''double''.');
    end

    % --- Optional reproducibility
    if ~isempty(p.Results.Seed)
        rng(p.Results.Seed, 'twister');
    end

    % --- Draw baseline (one complex scalar) and per-pixel noise
    if cls == "single"
        baseline = single(p.Results.sigma1) * (randn('single') + 1i*randn('single'));
        noiseR   = randn(p.Results.cam_x, p.Results.cam_y, 'single');
        noiseI   = randn(p.Results.cam_x, p.Results.cam_y, 'single');
        M        = baseline + single(p.Results.sigma2) * (noiseR + 1i*noiseI);
    else
        baseline = p.Results.sigma1 * (randn + 1i*randn);
        noiseR   = randn(p.Results.cam_x, p.Results.cam_y);
        noiseI   = randn(p.Results.cam_x, p.Results.cam_y);
        M        = baseline + p.Results.sigma2 * (noiseR + 1i*noiseI);
    end
end
