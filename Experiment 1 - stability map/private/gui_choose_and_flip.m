function [chosen_idx, chosen_clean, modified_pattern] = gui_choose_and_flip(base_patterns, flip_percent)
% GUI_CHOOSE_AND_FLIP
%   [IDX, CLEAN, MODIFIED] = gui_choose_and_flip(BASE_PATTERNS, FLIP_PERCENT)
%   BASE_PATTERNS : Ny x Nx x P array with binary values in {+1,-1} or {1,0}
%   FLIP_PERCENT  : fraction (0..1). Exactly round(FLIP_PERCENT * Ny*Nx) pixels will be flipped.
%
%   Returns:
%     chosen_idx       : index (1..P) of the chosen pattern
%     chosen_clean     : the original chosen pattern (in ±1)
%     modified_pattern : the flipped pattern (in ±1) to start Hopfield dynamics

    arguments
        base_patterns {mustBeNumeric, mustBeNonempty}
        flip_percent (1,1) double {mustBeGreaterThanOrEqual(flip_percent,0), mustBeLessThanOrEqual(flip_percent,1)}
    end

    % --- Normalize patterns to ±1 internally
    bp = base_patterns;
    bp = double(bp);
    if ~all(ismember(unique(bp),[-1 0 1]))
        error('base_patterns must contain only values in {-1,0,1}.');
    end
    if any(bp(:)==0) % interpret 0/1 as -1/+1
        bp = 2*(bp>0)-1;
    end

    [Ny, Nx, P] = size(bp);

    %% ================== GUI #1: choose a pattern ==================
    f1 = figure('Name','Choose a pattern','NumberTitle','off', ...
                'Color','w','Units','normalized','Position',[0.1 0.1 0.8 0.8]);
    tl = tiledlayout(f1, ceil(sqrt(P)), ceil(sqrt(P)), 'Padding','compact','TileSpacing','compact');

    selected = NaN;
    ax_list = gobjects(P,1);

    for k = 1:P
        ax = nexttile(tl);
        ax_list(k) = ax;
        imagesc(ax, bp(:,:,k)); axis(ax,'image','off'); colormap(ax, gray(256));
        title(ax, sprintf('#%d',k), 'FontWeight','normal');
        set(ax, 'UserData', k);
        % Highlight on click
        set(ax, 'ButtonDownFcn', @(~,~)selectThis(ax));
        % also make the image itself clickable
        hImg = findobj(ax,'Type','image');
        set(hImg, 'HitTest','on', 'ButtonDownFcn', @(~,~)selectThis(ax));
    end

    uicontrol('Style','pushbutton','String','Confirm selection', ...
              'Units','normalized','Position',[0.42 0.01 0.16 0.05], ...
              'FontWeight','bold', 'Callback', @confirmSelection);

    % Instruction text
    uicontrol('Style','text','String','Click a pattern to select, then press "Confirm selection".', ...
              'Units','normalized','BackgroundColor','w','Position',[0.25 0.94 0.5 0.04], ...
              'HorizontalAlignment','center','FontSize',11);

    uiwait(f1);  % Wait until user confirms

    if isnan(selected)
        error('Selection window closed without confirming a choice.');
    end

    chosen_idx = selected;
    chosen_clean = bp(:,:,chosen_idx);

    %% ================== GUI #2: flip limited number of pixels ==================
    max_flips = round(flip_percent * numel(chosen_clean));
    flips_done = 0;
    current = chosen_clean;
    original = chosen_clean;

    f2 = figure('Name','Flip pixels','NumberTitle','off', ...
                'Color','w','Units','normalized','Position',[0.2 0.15 0.6 0.7]);

    ax2 = axes('Parent', f2, 'Units','normalized','Position',[0.05 0.1 0.7 0.85]);
    im2 = imagesc(ax2, current); axis(ax2,'image','off'); colormap(ax2, gray(256));

    msg = uicontrol('Style','text','Units','normalized','BackgroundColor','w', ...
                    'Position',[0.78 0.62 0.2 0.28],'HorizontalAlignment','left','FontSize',11);

    resetBtn = uicontrol('Style','pushbutton','String','Reset flips', ...
                         'Units','normalized','Position',[0.78 0.53 0.2 0.06], ...
                         'Callback', @doReset);

    closeHint = uicontrol('Style','text','String','When done, close this window to accept.', ...
                          'Units','normalized','BackgroundColor','w','Position',[0.75 0.05 0.24 0.04], ...
                          'HorizontalAlignment','center','FontWeight','bold');

    setText();

    % Make clicking toggle pixel until flips_done==max_flips
    set(im2, 'HitTest','on', 'ButtonDownFcn', @flipPixel);
    set(ax2, 'ButtonDownFcn', @flipPixel);

    % Block until the user closes (accepts) the window
    uiwait(f2);

    modified_pattern = current;

    % --------------- nested functions ---------------

    function selectThis(ax)
        % Clear previous highlights
        for j = 1:numel(ax_list)
            set(ax_list(j), 'LineWidth', 0.5, 'XColor', 'k', 'YColor','k', 'Box','off');
            title(ax_list(j), sprintf('#%d', j), 'FontWeight','normal');
        end
        % Highlight this one
        rectangle(ax, 'Position',[0.5 0.5 Nx Ny], 'EdgeColor',[0 0.5 1], 'LineWidth',2, 'HitTest','off'); %#ok<NASGU>
        title(ax, sprintf('#%d  (selected)', ax.UserData), 'FontWeight','bold');
        selected = ax.UserData;
    end

    function confirmSelection(~,~)
        if isnan(selected)
            warndlg('Please click a pattern to select it first.','No selection');
            return;
        end
        uiresume(f1);
        if isvalid(f1); close(f1); end
    end

    function flipPixel(~,~)
        if flips_done >= max_flips
            return; % already reached the quota
        end
        % Map click to pixel indices
        cp = get(ax2, 'CurrentPoint');
        x = round(cp(1,1));
        y = round(cp(1,2));
        if x < 1 || x > Nx || y < 1 || y > Ny
            return;
        end
        % Toggle ±1
        current(y,x) = -current(y,x);
        flips_done = flips_done + 1;

        set(im2, 'CData', current);
        setText();

        if flips_done >= max_flips
            % Disable further flipping
            set(im2, 'ButtonDownFcn', []);
            set(ax2,  'ButtonDownFcn', []);
            msg.String = sprintf([ ...
                'All requested pixels flipped.\n' ...
                'Close the window to accept.\n\n' ...
                'Or press "Reset flips" to try again.\n' ...
                '(Flips: %d / %d)'], flips_done, max_flips);
            msg.ForegroundColor = [0 0.5 0];
        end
    end

    function doReset(~,~)
        current = original;
        flips_done = 0;
        set(im2, 'CData', current);
        % Re-enable flipping
        set(im2, 'ButtonDownFcn', @flipPixel);
        set(ax2,  'ButtonDownFcn', @flipPixel);
        setText();
    end

    function setText()
        remain = max_flips - flips_done;
        if max_flips == 0
            msg.String = sprintf(['flip\\_percent = 0%%.\n' ...
                                  'No flips required.\n' ...
                                  'Close this window to accept.']);
            msg.ForegroundColor = [0 0 0];
        else
            msg.String = sprintf([ ...
                'Click to flip pixels (white↔black).\n' ...
                'Required flips: %d\n' ...
                'Remaining: %d\n\n' ...
                '- Close this window to accept.\n' ...
                '- Or press "Reset flips" to start over.'], ...
                max_flips, remain);
            msg.ForegroundColor = [0 0 0];
        end
    end
end
