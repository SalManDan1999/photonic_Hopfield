clearvars -except hdevice


dll_name = 'alpV42basic';
dll_header = 'alpbasic';

dll = [dll_name, '.dll'];
head = [dll_header, '.h'];
if ~libisloaded(dll)
    loadlibrary(dll, head) %Load the alp41basic library (X64 bit)
end


%Allocate the DMD
deviceid = uint32(0);
InitFlag = uint32(0);
hdevice = uint32(1);
hdeviceptr = libpointer('longPtr', hdevice); %make an outpointer to write
[return_allocate,hdevice]= calllib(dll_name, 'AlpbDevAlloc', deviceid,InitFlag, hdeviceptr);