function tmppath = __mfv_tmpjson__(prefix)
%__MFV_TMPJSON__  Retourne un chemin de fichier JSON temporaire unique.
    tmppath = fullfile(tempdir(), [prefix '_' num2str(floor(time()*1000)) '.json']);
end
