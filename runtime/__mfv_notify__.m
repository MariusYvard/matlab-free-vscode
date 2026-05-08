function __mfv_notify__(payload)
%__MFV_NOTIFY__  Émet un message JSON via TCP ou sur stdout en fallback
    try
        json_str = jsonencode(payload);
        port_str = getenv('MFV_TCP_PORT');
        if ~isempty(port_str)
            % Try TCP via Java Socket
            if exist('javaObject', 'builtin') || exist('javaObject', 'file')
                try
                    port = str2double(port_str);
                    sock = javaObject('java.net.Socket', '127.0.0.1', port);
                    outStream = sock.getOutputStream();
                    
                    % We format the payload exactly as the MsgParser expects or just raw bytes
                    % MsgParser feeds chunks and looks for __MFV__ ... __MFV__
                    raw_msg = sprintf('\n__MFV__%s__MFV__\n', json_str);
                    
                    outStream.write(uint8(raw_msg));
                    outStream.flush();
                    sock.close();
                    return;
                catch
                    % Ignore TCP errors, fallback to stdout
                end
            end
        end
        
        % Fallback stdout
        fprintf(stdout, '\n__MFV__%s__MFV__\n', json_str);
        fflush(stdout);
    catch
    end
end
