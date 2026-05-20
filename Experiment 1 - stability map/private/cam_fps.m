function fps = cam_fps(vid, numFrames)
    % CAM_MEASURE_FPS - Measures the maximum FPS of a camera
    %
    % USAGE:
    %   fps = cam_measure_fps(vid);          % Default 1000 frames
    %   fps = cam_measure_fps(vid, 500);     % Custom number of frames
    %
    % INPUT:
    %   vid        - An initialized videoinput object
    %   numFrames  - Number of frames to use for measurement (default: 1000)
    %
    % OUTPUT:
    %   fps - Measured frames per second

    if nargin < 2
        numFrames = 1000;  % New default
    end

    if ~isvalid(vid)
        error('Invalid video input object.');
    end

    % Clear buffer
    flushdata(vid);
    start(vid);

    fprintf('Measuring FPS using %d frames...\n', numFrames);

    % Time the loop
    tic;
    for i = 1:numFrames
        getsnapshot(vid);  % Grab frame (discarded)
    end
    elapsedTime = toc;

    % Compute FPS
    fps = numFrames / elapsedTime;

    fprintf('Measured FPS: %.2f frames per second\n', fps);
end
