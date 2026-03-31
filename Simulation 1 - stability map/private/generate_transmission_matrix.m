function T = generate_transmission_matrix(N_x, N_y, cam_x, cam_y, sigma, varargin)
% GENERATE_TRANSMISSION_MATRIX
%   T = generate_transmission_matrix(N_x, N_y, cam_x, cam_y, sigma)
%   returns a (cam_x*cam_y) x (N_x*N_y) complex matrix T whose entries are
%   ~ N(0, sigma^2) + i N(0, sigma^2).
%
%   Optional name-value pairs:
%     'Seed'  : integer, RNG seed for reproducibility (default: [])
%     'Class' : 'double' (default) or 'single'
%
%   Usage to propagate an input field U (size N_x x N_y) to output V:
%       T = generate_transmission_matrix(Nx,Ny,cx,cy,sigma);
%       V = reshape(T * U(:), [cam_x, cam_y]);

    % --- Parse inputs
    p = inputParser;
    addRequired(p, 'N_x',   @(x)isnumeric(x)&&isscalar(x)&&x==floor(x)&&x>0);
    addRequired(p, 'N_y',   @(x)isnumeric(x)&&isscalar(x)&&x==floor(x)&&x>0);
    addRequired(p, 'cam_x', @(x)isnumeric(x)&&isscalar(x)&&x==floor(x)&&x>0);
    addRequired(p, 'cam_y', @(x)isnumeric(x)&&isscalar(x)&&x==floor(x)&&x>0);
    addRequired(p, 'sigma', @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    addParameter(p, 'Seed',  [], @(x)isnumeric(x)&&isscalar(x));
    addParameter(p, 'Class', 'double', @(s)ischar(s)||isstring(s));
    parse(p, N_x, N_y, cam_x, cam_y, sigma, varargin{:});

    N_in  = N_x  * N_y;        % number of input pixels
    N_out = cam_x * cam_y;     % number of output pixels

    cls = lower(string(p.Results.Class));
    if cls ~= "single" && cls ~= "double"
        error('Class must be ''single'' or ''double''.');
    end

    % --- Optional reproducibility
    if ~isempty(p.Results.Seed)
        rng(p.Results.Seed, 'twister');
    end

    % --- Allocate and fill with complex Gaussian entries
    if cls == "single"
        R = randn(N_out, N_in, 'single');
        I = randn(N_out, N_in, 'single');
        T = single(p.Results.sigma) * (R + 1i * I);
    else
        R = randn(N_out, N_in);
        I = randn(N_out, N_in);
        T = p.Results.sigma * (R + 1i * I);
    end
end
