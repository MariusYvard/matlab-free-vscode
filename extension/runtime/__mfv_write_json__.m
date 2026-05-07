function __mfv_write_json__(filepath, data)
%__MFV_WRITE_JSON__  Écrit data en JSON dans filepath.
    fid = fopen(filepath, 'w');
    fprintf(fid, '%s', jsonencode(data));
    fclose(fid);
end
