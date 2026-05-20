function [backgroundFrame, proceed] = cam_preview_gui(vid, opts)
% CAM_PREVIEW_GUI  Live preview with background capture & ROI tools.
% [backgroundFrame, proceed] = cam_preview_gui(vid, opts)
%
% INPUTS
%   vid  : configured videoinput ('gentl', Mono8). This function will start/stop it.
%   opts : struct with optional fields:
%          .ExposureTime  (default: keep current)
%          .Gain          (default: keep current)
%          .UiFpsCap      (default: 15)  % UI refresh cap (Hz)
%
% OUTPUTS
%   backgroundFrame : uint8 frame captured via "Set Background" (empty if none).
%   proceed         : true iff "Set Background" was pressed (you can proceed to acquisition).

    arguments
        vid
        opts struct = struct()
    end

    % ---- defaults (struct-based) ----
    if ~isfield(opts,'ExposureTime'), opts.ExposureTime = []; end
    if ~isfield(opts,'Gain'),         opts.Gain         = []; end
    if ~isfield(opts,'UiFpsCap'),     opts.UiFpsCap     = 15; end

    % --- Configure (optional tweaks) ---
    try
        src = getselectedsource(vid);
        if ~isempty(opts.ExposureTime), set(src,'ExposureTime',opts.ExposureTime); end
        if ~isempty(opts.Gain),         set(src,'Gain',opts.Gain);                 end
    catch ME
        warning('Could not access source properties: %s', ME.message);
    end
    
    if isprop(src,'AcquisitionFrameRateEnable')
        src.AcquisitionFrameRateEnable = 'false';
    end
    % --- Ensure streaming (immediate trigger, continuous) ---
    triggerconfig(vid,'immediate');
    vid.FramesPerTrigger = Inf;
    vid.LoggingMode      = 'memory';
    if ~strcmp(vid.Running,'on'), start(vid); end

    % --- Figure & UI ---
    sensorSize = vid.VideoResolution;
    fullWidth  = sensorSize(1);
    fullHeight = sensorSize(2);
    screenSize = get(0,'ScreenSize');

    hFig = figure('Position',screenSize,'MenuBar','none','ToolBar','none', ...
        'NumberTitle','off','Name','Camera Feed (Streaming Preview)', ...
        'CloseRequestFcn',@onClose, 'WindowState','maximized', 'Color','w');

    ax  = axes('Parent',hFig,'Units','normalized','Position',[0 0 1 1]); axis(ax,'off');
    hIm = imshow(zeros(fullHeight,fullWidth,'uint8'),'Parent',ax, ...
        'Border','tight','InitialMagnification','fit','DisplayRange',[0 255]);
    colormap(ax,'gray'); axis(ax,'normal');

    annotationHandle = annotation('textbox',[0.75 0.85 0.22 0.12], ...
        'String','', 'Color','yellow','FontSize',14,'FontWeight','bold', ...
        'EdgeColor','none','HorizontalAlignment','right');

    uicontrol('Style','pushbutton','String','Stop', ...
        'Position',[50 screenSize(4)-100 100 40], ...
        'Callback',@(~,~)onStop(),'BackgroundColor',[1 0 0]);

    uicontrol('Style','pushbutton','String','Screenshot', ...
        'Position',[160 screenSize(4)-100 100 40], ...
        'Callback',@(~,~)onScreenshot(),'BackgroundColor',[0 0.5 0]);

    uicontrol('Style','pushbutton','String','Set Background', ...
        'Position',[270 screenSize(4)-100 150 40], ...
        'Callback',@(~,~)onSetBackground(),'BackgroundColor',[1 1 0]);

    uicontrol('Style','pushbutton','String','Set ROI', ...
        'Position',[430 screenSize(4)-100 100 40], ...
        'Callback',@(~,~)onSetROI(),'BackgroundColor',[0.2 0.4 1]);

    uicontrol('Style','pushbutton','String','Reset ROI', ...
        'Position',[540 screenSize(4)-100 100 40], ...
        'Callback',@(~,~)onResetROI(),'BackgroundColor',[0.8 0.3 0.3]);

    % --- State ---
    backgroundFrame   = [];
    lastFrame         = [];
    screenshotCounter = 1;
    stopFlag          = false;
    proceed           = false;   % set true when background is captured

    % --- Preview loop ---
    t_fps = tic; frames_counted = 0;
    last_ui = tic; ui_cap = 1 / max(1, opts.UiFpsCap);

    while isgraphics(hFig) && ~stopFlag && ~proceed
        n = vid.FramesAvailable;
        if n > 0
            batch = getdata(vid, n, 'uint8');     % H x W x 1 x n
            lastRaw = batch(:,:,:,end);
            frames_counted = frames_counted + n;

            tnow = toc(t_fps);
            if tnow >= 0.5
                fps_meas = frames_counted / tnow;
                t_fps = tic; frames_counted = 0;
            end

            if ~isempty(backgroundFrame) && isequal(size(lastRaw),size(backgroundFrame))
                ddd = int16(lastRaw) - int16(backgroundFrame); ddd(ddd<0)=0;
                frameToShow = uint8(ddd);
            else
                frameToShow = lastRaw;
            end
            lastFrame = frameToShow;

            if toc(last_ui) >= ui_cap
                if isgraphics(hIm), set(hIm,'CData',frameToShow); end
                maxIntensity = max(lastRaw(:));
                roi = vid.ROIPosition; Wroi = roi(3); Hroi = roi(4);
                if exist('fps_meas','var'), fps_str = sprintf('%.2f', fps_meas); else, fps_str='...'; end
                if isgraphics(annotationHandle)
                    annotationHandle.String = { ...
                        ['Max Intensity: ', num2str(maxIntensity)], ...
                        ['FPS (measured): ', fps_str], ...
                        ['Exposure (µs): ', safeGet(src,'ExposureTime')], ...
                        ['Camera Size: ', num2str(fullWidth), ' × ', num2str(fullHeight)], ...
                        ['ROI Size: ', num2str(Wroi), ' × ', num2str(Hroi), ...
                         ' = ', num2str(Wroi*Hroi), ' px'] ...
                    };
                end
                drawnow limitrate
                last_ui = tic;
            end
        else
            pause(0.002);
        end
    end

    % --- Clean up stream BEFORE returning ---
    if isvalid(vid) && strcmp(vid.Running,'on'), stop(vid); end
    if isgraphics(hFig), delete(hFig); end

    % ===== Nested helpers =====
    function onStop()
        proceed = true;
        stopFlag = true;
    end

    function onClose(~,~)
        stopFlag = true;
        proceed = true;
        try, delete(hFig); catch, end
    end

    function onScreenshot()
        if isempty(lastFrame)
            warndlg('No frame available to save.','Screenshot'); return;
        end
        fn = sprintf('screenshot_%03d.mat', screenshotCounter);
        frameData = lastFrame; %#ok<NASGU>
        save(fn,'frameData');
        fprintf('Screenshot #%d saved as %s\n', screenshotCounter, fn);
        screenshotCounter = screenshotCounter + 1;
    end

    function onSetBackground()
        if isempty(lastFrame)
            errordlg('No frame available yet. Wait for preview, then click again.', 'Background Error');
            return;
        end
        backgroundFrame = lastFrame;
        save('background.mat','backgroundFrame','-v7.3');
        fprintf('Background saved to background.mat\n');
        proceed = true;
        onClose();
    end

    function onSetROI()
        prompt = {'ROI Width:','ROI Height:','X Shift from center:','Y Shift from center:'};
        answ = inputdlg(prompt,'Set ROI',1,{'300','300','0','0'});
        if isempty(answ), return; end
        rw = str2double(answ{1}); rh = str2double(answ{2});
        xs = str2double(answ{3}); ys = str2double(answ{4});
        try
            cam_set_roi(vid, rw, rh, xs, ys); % your helper
            backgroundFrame = [];             % invalidate bg after ROI change
            fprintf('ROI applied: %dx%d @ (%d,%d)\n', rw, rh, xs, ys);
        catch ME
            errordlg(['Failed to set ROI: ' ME.message],'ROI Error');
        end
    end

    function onResetROI()
        try
            sensorSize2 = vid.VideoResolution;
            fullW  = sensorSize2(1);
            fullH  = sensorSize2(2);
            vid.ROIPosition = [0 0 fullW fullH];
            backgroundFrame = [];
            fprintf('ROI reset to full size: %dx%d\n', fullW, fullH);
            if isgraphics(hIm)
                set(hIm,'CData',zeros(fullH,fullW,'uint8'));
                drawnow limitrate
            end
        catch ME
            errordlg(['Failed to reset ROI: ' ME.message],'ROI Error');
        end
    end

    function val = safeGet(s, prop)
        try
            v = get(s,prop);
            if isnumeric(v), val = num2str(v); else, val = char(v); end
        catch
            val = 'n/a';
        end
    end
end
