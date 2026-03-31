function img = util_speckle_from_state(state,small_frame,full_frame,vid,cfg)
%% ---- UTIL POST SYNAPTIC POTENTIALS
% This function associates to the input neuron state the corresponding image
% that should be sent to the DMD, considering also the reference disk.
% INPUTS
% -- state       : N_y times N_x matrix containing the state of ±1 neurons
% -- small frame : the non superpixeled, small image that we need to prepare to send to DMD
% -- full frame  : the full image that we will send to dmd via the pointer.
% -- cfg         : collection of relevant variables.
% OUTPUTS
% -- img         : what the camera sees
    
    small_frame(cfg.mask_neurons)=state(:);                % Writing the state on the small frame
    %% Translating into superpixeled image
    imgROI = util_bin_to_superpixel(small_frame, cfg.dmd_super_w, cfg.dmd_super_h, cfg.chessboard);
    %% ==================================
    full_frame(cfg.mask_ROI)=imgROI(:);                   % Writing on the full frame
    full_frame = full_frame';                             % Perform transposition to send to the DMD                                  
    set(cfg.pointer, 'Value', full_frame);                % Updating the memory address with transpose to update DMD
    dmd_display(cfg.dll_name, cfg.hdevice, cfg.pointer, cfg.first_row, cfg.last_row); 
    img = take_snapshot(vid, cfg.cam_pause, cfg.background);
end


