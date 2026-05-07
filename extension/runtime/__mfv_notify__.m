function __mfv_notify__(payload)
%__MFV_NOTIFY__  Émet un message JSON sur stdout encadré par __MFV__…__MFV__
%  pour que MsgParser.ts puisse l'isoler du flux LSP normal.
    try
        fprintf(stdout, '\n__MFV__%s__MFV__\n', jsonencode(payload));
        fflush(stdout);
    catch
    end
end
