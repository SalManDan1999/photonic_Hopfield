% === Careful! This sets up a ROI but only at software level. You'll need the mako driver
% to crop at camera level.

function cam_set_roi(vid, roi_width, roi_height, offset_x, offset_y)
    % CAM_SET_ROI - Set software ROI using ROIPosition on videoinput object
    %
    % INPUT:
    %   vid        - Initialized videoinput object
    %   roi_width  - Width of ROI
    %   roi_height - Height of ROI
    %   offset_x   - Horizontal shift from (0, 0)
    %   offset_y   - Vertical shift from (0, 0)

    if ~isvalid(vid)
        error('Invalid video input object.');
    end

    % Get full frame size from VideoResolution
    sensorSize = vid.VideoResolution;
    maxWidth = sensorSize(1);
    maxHeight = sensorSize(2);

    % Ensure ROI stays within sensor bounds
    if offset_x + roi_width > maxWidth || offset_y + roi_height > maxHeight
        error('ROI exceeds sensor bounds.');
    end

    % Set the ROI via software
    stop(vid);  % Stop before changing ROI
    vid.ROIPosition = [offset_x, offset_y, roi_width, roi_height];
end
