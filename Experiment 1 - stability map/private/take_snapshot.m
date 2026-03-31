function [frame,metadata] = take_snapshot(vid, pause_time, background)
% TAKE_SNAPSHOT - Grab a single frame from a started camera.
%
%   [FRAME, METADATA] = TAKE_SNAPSHOT(VID) grabs a frame from the
%   videoinput object VID. It waits for a new frame to be available
%   before snapshotting.
%
%   [FRAME, METADATA] = TAKE_SNAPSHOT(VID, PAUSE_TIME) waits for PAUSE_TIME
%   seconds after a new frame is detected, but *before* calling getsnapshot.
%   This can be useful to let the DMD or another device settle.
%
%   [FRAME, METADATA] = TAKE_SNAPSHOT(VID, PAUSE_TIME, BACKGROUND) also
%   subtracts the BACKGROUND image (or scalar value) from the captured frame.

    % --- Handle Optional Arguments ---

    % If 2 arguments or fewer are provided, set background to empty.
    if nargin < 3
        background = [];
    end

    % If 1 argument or fewer are provided, set pause_time to 0.
    if nargin < 2
        pause_time = 0; % Default to no pause
    end
    
    % --- Main Function Logic ---

    % Wait for a new frame to be acquired by the camera
    flushdata(vid);
    TMP1 = vid.FramesAcquired;
    TMP2 = vid.FramesAcquired;
    while TMP2 == TMP1 % this halts the code until next frame is captured
        TMP2 = vid.FramesAcquired;
    end
    
    % Optional pause, if a non-zero value was provided
    if pause_time > 0
        pause(pause_time);
    end
    
    % Get the actual snapshot
    [img, metadata] = getsnapshot(vid);
    
    % --- Handle Background Subtraction ---

    % If background is empty, just return the raw image
    if isempty(background)
        frame = img;
        return;
    end
    
    % If background was provided, validate and subtract it
    if ~isscalar(background) && ~isequal(size(background), size(img))
        error('Background must be scalar or the same size as the frame.');
    end
    
    if isinteger(img)
        % Ensure background is the same integer class for imsubtract
        if ~strcmp(class(background), class(img))
            background = cast(background, class(img));
        end
        frame = imsubtract(img, background);  % saturates at 0 (won't go negative)
    else
        % For double/single, just subtract and floor at 0
        frame = max(img - background, 0);
    end
end