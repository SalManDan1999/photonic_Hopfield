function [hdevice,dll_name] = dmd_start()
    % === CONFIGURATION ===
    % Get the folder of this script
    this_folder = fileparts(mfilename('fullpath'));

    % Go to the folder containing the DLL and header
    dll_folder = fullfile(this_folder, 'alp_library'); % Adjust folder name as needed
    addpath(genpath(dll_folder));

    dll_name = 'alpV42basic';
    dll_header = 'alpbasic';

    % Optional: update system PATH
    if ispc
        current_path = getenv('PATH');
        if ~contains(current_path, dll_folder)
            setenv('PATH', [dll_folder pathsep current_path]);
        end
    end

    % === LOAD LIBRARY ===
    if ~libisloaded(dll_name)
        dll = [dll_name, '.dll'];
        head = [dll_header, '.h'];
        if ~libisloaded(dll)
           loadlibrary(dll, head); %Load the alp41basic library (X64 bit)
        end
        
        return_lib = libisloaded(dll_name);
        if return_lib == 1
            return_lib = 'Library is loaded';
            disp(return_lib);
        else return_lib = 'Error: Library was not loaded';
            disp(return_lib);
        end
        
        libfunctionsview(dll_name)
        disp(['✅ Library load result: ' return_lib]);
    else
        disp(['Library "' dll_name '" already loaded.']);
    end

    % === ALLOCATE DMD ===
    disp('Now allocating the DMD:')
    deviceid = uint32(0);
    hdevice = uint32(1);
    hdeviceptr = libpointer('longPtr', hdevice); %make an outpointer to write
    [return_allocate, hdevice] = calllib(dll_name, 'AlpbDevAlloc', deviceid, hdeviceptr);
    return_check(return_allocate);
    
    % === RESET DMD ===
    return_reset = calllib(dll_name, 'AlpbDevReset', hdevice, 4, 0); %setting 4 and 0 there allows for global reset
    return_check(return_reset);

    % === CLEAR THE DMD ===
    first_block = 0;
    last_block = 15;
    first_block = int32(first_block);
    last_block = int32(last_block); 
    disp('Now clearing the DMD:');
    [return_clear] = calllib(dll_name, 'AlpbDevClear', hdevice, first_block, last_block);
    return_check(return_clear);

    disp('Initialization state:');
    return_check(return_allocate);
    disp('📍 Handle obtained:');
    disp(hdevice);
end
