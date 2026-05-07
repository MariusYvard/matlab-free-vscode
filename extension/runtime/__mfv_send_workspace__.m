function __mfv_send_workspace__()
%__MFV_SEND_WORKSPACE__  Envoie l'état du workspace base vers VS Code.
%  Appelé par lsp_loop.m après chaque exécution de code utilisateur.
    try
        info = evalin('base', 'whos()');
        if isempty(info)
            vars_list = {};
        else
            n = length(info);
            vars_list = cell(1, n);
            for k = 1:n
                sz = info(k).size;
                if length(sz) >= 2
                    size_str = sprintf('%dx%d', sz(1), sz(2));
                else
                    size_str = num2str(sz(1));
                end
                vars_list{k} = struct( ...
                    'name',  info(k).name, ...
                    'class', info(k).class, ...
                    'size',  size_str, ...
                    'bytes', info(k).bytes ...
                );
            end
        end
        __mfv_notify__(struct('type', 'workspace', 'vars', {vars_list}));
    catch
        % Silencieux : le Variable Explorer est optionnel
    end
end
