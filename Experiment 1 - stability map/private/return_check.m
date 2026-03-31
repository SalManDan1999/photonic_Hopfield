%% ALP Basic API, Written by Nakul Bende (fixed by SMD)
% RETURN_CHECK  - Translate ALP return codes into human-readable messages
% Usage:
%   msg = return_check(code);

function out_signal = return_check(return_value)

% Normalize to 32-bit unsigned for robust matching
code = uint32(return_value);

switch code
    case uint32(hex2dec('00000000'))
        out_signal = 'The operation was a success';
    case uint32(hex2dec('00000001'))
        out_signal = 'The operation was a success, output truncated';

    % === ALP error codes (32-bit, 0x08000001 .. 0x0800000F) ===
    case uint32(hex2dec('08000001'))
        out_signal = 'No free ALP device found';
    case uint32(hex2dec('08000002'))
        out_signal = 'ALP already in use';
    case uint32(hex2dec('08000003'))
        out_signal = 'Device initialization failed';
    case uint32(hex2dec('08000004'))
        out_signal = 'Device initialization failed – toggle reset switch';
    case uint32(hex2dec('08000005'))
        out_signal = 'Invalid device handle';
    case uint32(hex2dec('08000006'))
        out_signal = 'Device disconnected – free the handle';
    case uint32(hex2dec('08000007'))
        out_signal = 'Device error – free and re-allocate the device';
    case uint32(hex2dec('08000008'))
        out_signal = 'Multi-thread: another function running';
    case uint32(hex2dec('08000009'))
        out_signal = 'Halted – use device control to resume';
    case uint32(hex2dec('0800000A'))
        out_signal = 'Memory cannot be accessed';
    case uint32(hex2dec('0800000B'))
        out_signal = 'Insufficient internal memory';
    case uint32(hex2dec('0800000C'))
        out_signal = 'Argument had invalid inputs';
    case uint32(hex2dec('0800000D'))
        out_signal = 'Missing USB dongle';
    case uint32(hex2dec('0800000E'))
        out_signal = 'API missing';
    case uint32(hex2dec('0800000F'))
        out_signal = 'API not supported';

    otherwise
        % Always set a message to avoid undefined variable errors
        out_signal = sprintf('Unknown ALP return code: 0x%08X (%d)', code, double(code));
end

disp(out_signal)
