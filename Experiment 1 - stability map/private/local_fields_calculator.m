function local_fields = local_fields_calculator(stateMat, small_frame, full_frame, vid, cfg, map_idx,weights,fast)
% LOCAL_FIELDS_CALCULATOR 
% Projects state on the DMD, acquires two frames (state and its flipped version),
% optionally filters them with a map_idx, and returns their difference
% (or its sign if fast=true). Optional background subtraction included.
%
% INPUTS
%   stateMat : N_y × N_x matrix (values in {-1,1} – neuron state)
%   small_frame : (this is the ideal picture you're sending to DMD, non superpixeled)
%   full_frame  : (this is the actual picture you're sending to DMD)
%   vid      : configured videoinput (Basler), ready for getsnapshot
%   cfg      : struct with required fields:
%%             .pointer                           (pointer to load image)
%              .W_DMD, .H_DMD                     (DMD canvas size)
%              .W_ROI, .H_ROI, .X_SHIFT, .Y_SHIFT (ROI placement on DMD)
%              .dmd_super_w, .dmd_super_h         (DMD superpixel size in px)
%              .dll_name, .hdevice (if using api_load) OR .dmd_send_fn
%              .active_ROI                        (DMD active region)
%              .chessboard                        (which chessboard to use) 
%              .mask_neurons, .mask_reference, mask_ROI (where to update)
%              .background                        (noise to subtract)
%              .cam_pause                         (wait time for camera)
%              .cam_spx                           (how big camera spx is)
%              .first_row (default 0), .last_row (default H_DMD-1)
%   map_idx  : (optional) [Nneur x n_spx] uint32 matrix of linear indices
%   fast     : (optional, default=false) if true, return only sign map in {-1,0,+1}
%
% OUTPUT
%   local_fields :
%     - if map_idx empty   → matrix of camera frame size
%     - if map_idx given   → matrix of size(stateMat)
%     - if fast==true      → int8 sign map in {-1,0,+1}

% --- Argument validation block ---
arguments
    stateMat (:,:) {mustBeNumeric}
    small_frame % Type validation can be added (e.g., {mustBeNumeric})
    full_frame  % Type validation can be added
    vid         % Type validation can be added (e.g., {mustBeA('videoinput')})
    cfg (1,1) struct
    map_idx = [] % Optional: defaults to empty array
    weights = [] % Optional also
    fast (1,1) logical = false % Optional: defaults to false
end

    % --- Acquire frames ---
    % Get the frame for the current state
    frame1 = util_speckle_from_state(stateMat, small_frame, full_frame, vid, cfg);
    
    % Get the frame for the *flipped* state
    frame2 = util_speckle_from_state(-stateMat, small_frame, full_frame, vid, cfg);

    % --- Calculate difference ---
    if isempty(map_idx)
        % Full-frame difference
        Dout = int16(frame1) - int16(frame2);
    else
        [Ny, Nx] = size(stateMat);
        Nneur    = Ny * Nx;
        nPix     = numel(frame1);
        % Fast sparse matrix multiplication is employed to sum local fields

        % 1. Prepare indices for the sparse matrix
        % The following creates an array with Nneur rows, enumerating
        % neurons, and M columns
        row_idx = repmat((1:Nneur)', 1, size(map_idx, 2));
        
        % 2. Create a logical mask for valid indices
        valid_mask = (map_idx >= 1) & (map_idx <= nPix);
        
        % 3. Construct the Sparse Projection Matrix S
        % S is [Nneur x nPix]. It acts as a mapping from pixels to neurons.
        S = sparse(double(row_idx(valid_mask)), ... %row indices
                   double(map_idx(valid_mask)), ... %column indices
                   double(weights(valid_mask)), ... %entries
                   Nneur, nPix);

        % 4. Perform the weighted sum via matrix multiplication
        % Reshape frames to vectors [nPix x 1]
        diff_vec = double(frame1(:)) - double(frame2(:));
        
        % This single operation replaces the gather, multiply, and sum steps
        Dout_lin = S * diff_vec; 
        
        Dout = reshape(Dout_lin, Ny, Nx);
    end
    
    % --- Output (optionally sign) ---
    if fast
        local_fields = int8(sign(Dout));      % {-1,0,+1}
    else
        local_fields = Dout;                  % int16
    end
end
