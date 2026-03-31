function backgroundFrame = cam_background(vid, numFrames)
    % CAM_BACKGROUND - Averages multiple frames from an existing camera object
    %
    % USAGE:
    %   bg = cam_background(vid);           % Uses default of 200 frames
    %   bg = cam_background(vid, 100);      % Uses 100 frames
    %
    % INPUT:
    %   vid        - An initialized videoinput object
    %   numFrames  - Number of frames to average (default: 200)
    %
    % OUTPUT:
    %   backgroundFrame - The average frame as uint8

    if nargin < 2
        numFrames = 200;
    end

    % Safety check
    if ~isvalid(vid)
        error('Invalid video input object.');
    end

    % Preallocate the accumulator as double
    frameSum = [];

    disp(['Capturing ', num2str(numFrames), ' frames for background averaging...']);
    flushdata(vid);  % Clear any residual data
    start(vid);

    for i = 1:numFrames
        frame = getsnapshot(vid);

        if isempty(frameSum)
            frameSum = double(frame);  % Initialize on first frame
        else
            frameSum = frameSum + double(frame);
        end

        if mod(i, 20) == 0 || i == numFrames
            fprintf('Captured %d / %d frames\n', i, numFrames);
        end
    end

    % Compute average and cast back to uint8
    backgroundFrame = uint8(frameSum / numFrames);
    fprintf('Background frame computed.\n');

    % Optional: save to disk
    save('background.mat', 'backgroundFrame');
    fprintf('Saved background frame to background.mat\n');
end
