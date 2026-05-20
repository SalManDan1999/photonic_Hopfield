%% =================================== Learning patterns =====================================
% This function sends patterns to the DMD, one after the other, and records corresponding local fields.
% Based on the sequence of local fields in each pixel, a mapping between dmd superpixels and camera 
% pixels is performed.


function [map_idx,weights] = learning(patterns,small_frame,full_frame,use_weights,vid,cfg)
    h = waitbar(0, sprintf('Processing frames %d/%d...', 0, size(patterns,3)));
    cleanupObj = onCleanup(@() (ishandle(h) && close(h)));                       % auto-close on error/return
    patterns_local_fields = zeros(cfg.H_cam,cfg.W_cam,size(patterns,3),'int8');  % preallocate 28x28x100
    fprintf('\nSending patterns. Please wait.')
    for kkk = 1:size(patterns,3)
        pattern = patterns(:,:,kkk);
        frame = local_fields_calculator(pattern,small_frame,full_frame,vid,cfg);  % your acquisition function, must return 28x28
        patterns_local_fields(:,:,kkk) = frame;          % insert into the 3D array
        if ishandle(h)
            waitbar(kkk/size(patterns,3), h, sprintf('Sending frame %d/%d...', kkk, size(patterns,3)));
            drawnow limitrate;  % keeps UI responsive without too much overhead
        end
    end
    [map_idx,weights]=util_learn_mapping_weighted(patterns_local_fields,patterns,cfg.cam_size_spx,use_weights,true);
end