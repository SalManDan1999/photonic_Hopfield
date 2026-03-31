function c = util_correlation_with_reference(background, cfg, vid, ref_frame_dmd, test1)
% UTIL_CORRELATION_WITH_REFERENCE
% Send a frame to the DMD, take a snapshot, and print its correlation
% with a reference frame (test1).
%
% INPUTS:
%   background     : background frame for take_snapshot
%   cfg            : struct with fields:
%                    - dll_name, hdevice, pointer, first_row, last_row, cam_pause
%   vid            : video input object
%   ref_frame_dmd  : image (uint8, transposed for DMD) to display on DMD
%   test1          : reference frame to compare against (for corr2)
%
% No outputs; correlation is printed to console.

    % --- Send frame to DMD
    set(cfg.pointer, 'Value', ref_frame_dmd);
    dmd_display(cfg.dll_name, cfg.hdevice, cfg.pointer, cfg.first_row, cfg.last_row);

    % --- Take snapshot
    frame = take_snapshot(vid, cfg.cam_pause, background);

    % --- Compute and print correlation
    c = corr2(double(test1), double(frame));
end
