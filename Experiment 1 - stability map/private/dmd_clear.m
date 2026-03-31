function dmd_clear(dll_name,hdevice)
    if ~libisloaded(dll_name)
            error('Library "%s" is not loaded. Call your init first.', dll_name);
    end

    % Simple sanity check on handle (adapt if your API uses a different type/range)
    if isempty(hdevice) || ~isscalar(hdevice)
        error('hdevice is empty or invalid. Call your init first.');
    end

    % === RESET DMD ===
    return_reset = calllib(dll_name, 'AlpbDevReset', hdevice, 4, 0); %setting 4 and 0 there allows for global reset
    disp('Now resetting the DMD:');
    return_check(return_reset);

    % === CLEAR THE DMD ===
    first_block = 0;
    last_block = 15;
    first_block = int32(first_block);
    last_block = int32(last_block); 
    disp('And clearing the DMD:');
    [return_clear] = calllib(dll_name, 'AlpbDevClear', hdevice, first_block, last_block);
    return_check(return_clear);
    
end