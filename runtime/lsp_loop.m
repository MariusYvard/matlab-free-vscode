%% lsp_loop.m — matlab-free-vscode
%  Boucle LSP JSON-RPC complète exécutée par OctaveSession.ts au démarrage.
%  Implémente le protocole Language Server Protocol (LSP) via stdin/stdout.
%
%  Messages entrants  : Content-Length: N\r\n\r\n{JSON-RPC}
%  Messages sortants  : Content-Length: N\r\n\r\n{JSON-RPC}
%  Notifications MFV  : \n__MFV__{JSON}__MFV__\n  (bootstrap.m)
%
%  Méthodes LSP supportées :
%    initialize / initialized / shutdown / exit
%    textDocument/didOpen, didChange, didClose, didSave
%    textDocument/completion      (built-in + struct fields + fonctions utilisateur)
%    textDocument/signatureHelp   (signature de la fonction courante)
%    textDocument/hover
%    textDocument/definition
%    textDocument/publishDiagnostics  (côté serveur → client)
%    octave/runCode                   (méthode custom : exécute du code + workspace)

function __mfv_lsp_loop__()

%% ── État de la session ───────────────────────────────────────────────────
files        = struct();   % uri → texte source
initialized  = false;
shutdown_req = false;
workspace_dir = '';        % répertoire de travail pour scan des .m utilisateur

%% ── Boucle principale ────────────────────────────────────────────────────
while ~shutdown_req

    %% 1. Lecture des headers HTTP-like
    content_length = 0;
    while true
        line = fgetl(stdin);
        if isequal(line, -1)
            return;
        end
        line = strtrim(line);
        if isempty(line)
            break;
        end
        if strncmpi(line, 'Content-Length:', 15)
            content_length = str2double(strtrim(line(16:end)));
        end
    end

    if content_length <= 0
        continue;
    end

    %% 2. Lecture du corps JSON
    raw = char(fread(stdin, content_length, 'uint8')');
    try
        msg = jsondecode(raw);
    catch
        continue;
    end

    if ~isfield(msg, 'method')
        continue;
    end
    method = msg.method;

    %% 3. Dispatch par méthode
    response = [];

    switch method

        % ── Cycle de vie ──────────────────────────────────────────────
        case 'initialize'
            initialized = true;
            % Récupère le répertoire racine du workspace.
            % Sur Windows on a "file:///C:/...", sur Unix "file:///home/...".
            % Décodage minimal des %XX et normalisation du séparateur.
            if isfield(msg.params, 'rootUri') && ~isempty(msg.params.rootUri)
                u = msg.params.rootUri;
                if strncmp(u, 'file://', 7), u = u(8:end); end
                if length(u) >= 1 && u(1) == '/', u = u(2:end); end
                if length(u) >= 3 && u(2) == ':'
                    % Windows : "C:/foo" passe tel quel
                else
                    % Unix : on remet le slash initial
                    u = ['/' u];
                end
                workspace_dir = u;
                if ispc()
                    workspace_dir = strrep(workspace_dir, '/', filesep());
                end
            end
            response = __lsp_response__(msg, __lsp_capabilities__());

        case 'initialized'
            % Notification → pas de réponse

        case 'shutdown'
            shutdown_req = true;
            response = __lsp_response__(msg, []);

        case 'exit'
            return;

        % ── Gestion des documents ─────────────────────────────────────
        case 'textDocument/didOpen'
            uri  = msg.params.textDocument.uri;
            text = msg.params.textDocument.text;
            files.(uri2key(uri)) = text;
            __lsp_publish_diagnostics__(uri, text);

        case 'textDocument/didChange'
            uri = msg.params.textDocument.uri;
            if isfield(msg.params, 'contentChanges') && ...
               ~isempty(msg.params.contentChanges)
                changes = msg.params.contentChanges;
                if isstruct(changes)
                    text = changes(end).text;
                elseif iscell(changes)
                    text = changes{end}.text;
                end
                files.(uri2key(uri)) = text;
            end
            % Les diagnostics sont déclenchés uniquement à la sauvegarde
            % pour ne pas spawner un processus Octave à chaque frappe.

        case 'textDocument/didClose'
            key = uri2key(msg.params.textDocument.uri);
            if isfield(files, key)
                files = rmfield(files, key);
            end

        case 'textDocument/didSave'
            uri  = msg.params.textDocument.uri;
            key  = uri2key(uri);
            text = '';
            if isfield(files, key)
                text = files.(key);
            end
            if ~isempty(text)
                __lsp_publish_diagnostics__(uri, text);
            end

        % ── Complétion ────────────────────────────────────────────────
        case 'textDocument/completion'
            pos  = msg.params.position;
            uri  = msg.params.textDocument.uri;
            key  = uri2key(uri);
            text = '';
            if isfield(files, key), text = files.(key); end

            prefix = __extract_prefix__(text, pos.line, pos.character);
            items  = __lsp_completions__(prefix, workspace_dir);
            response = __lsp_response__(msg, struct( ...
                'isIncomplete', false, ...
                'items', items));

        % ── Signature Help ────────────────────────────────────────────
        case 'textDocument/signatureHelp'
            pos  = msg.params.position;
            uri  = msg.params.textDocument.uri;
            key  = uri2key(uri);
            text = '';
            if isfield(files, key), text = files.(key); end

            funcname = __extract_call_context__(text, pos.line, pos.character);
            result   = __lsp_signature_help__(funcname);
            response = __lsp_response__(msg, result);

        % ── Hover ─────────────────────────────────────────────────────
        case 'textDocument/hover'
            pos    = msg.params.position;
            uri    = msg.params.textDocument.uri;
            key    = uri2key(uri);
            text   = '';
            if isfield(files, key), text = files.(key); end

            word   = __word_at__(text, pos.line, pos.character);
            result = __lsp_hover__(word);
            response = __lsp_response__(msg, result);

        % ── Go-to-definition ──────────────────────────────────────────
        case 'textDocument/definition'
            pos  = msg.params.position;
            uri  = msg.params.textDocument.uri;
            key  = uri2key(uri);
            text = '';
            if isfield(files, key), text = files.(key); end

            word   = __word_at__(text, pos.line, pos.character);
            result = __lsp_definition__(word);
            response = __lsp_response__(msg, result);

        % ── Méthode custom : exécuter du code ─────────────────────────
        case 'octave/runCode'
            code = msg.params.code;
            __lsp_run_code__(code);
            % Pas de réponse : les sorties arrivent via __mfv_notify__

        otherwise
            if isfield(msg, 'id')
                response = __lsp_error__(msg, -32601, 'Method not found');
            end
    end

    %% 4. Envoi de la réponse
    if ~isempty(response)
        __lsp_send__(response);
    end

end % while

end % __mfv_lsp_loop__

%% ═══════════════════════════════════════════════════════════════════════════
%%  Fonctions auxiliaires LSP
%% ═══════════════════════════════════════════════════════════════════════════

function __lsp_send__(obj)
    body  = jsonencode(obj);
    bytes = uint8(body);
    fprintf(stdout, 'Content-Length: %d\r\n\r\n', length(bytes));
    fwrite(stdout, bytes);
    fflush(stdout);
end

function r = __lsp_response__(msg, result)
    r = struct('jsonrpc', '2.0', 'id', msg.id);
    if isempty(result)
        r.result = [];
    else
        r.result = result;
    end
end

function r = __lsp_error__(msg, code, message)
    r = struct('jsonrpc', '2.0', 'id', msg.id, ...
               'error', struct('code', code, 'message', message));
end

function caps = __lsp_capabilities__()
    caps = struct( ...
        'capabilities', struct( ...
            'textDocumentSync', struct( ...
                'openClose', true, ...
                'change',    2, ...
                'save',      struct('includeText', true) ...
            ), ...
            'completionProvider', struct( ...
                'resolveProvider',   false, ...
                'triggerCharacters', {{'.', '('}} ...
            ), ...
            'signatureHelpProvider', struct( ...
                'triggerCharacters',   {{'(', ','}}, ...
                'retriggerCharacters', {{','}} ...
            ), ...
            'hoverProvider',      true, ...
            'definitionProvider', true  ...
        ), ...
        'serverInfo', struct( ...
            'name',    'matlab-free-vscode (Octave)', ...
            'version', '0.2.0' ...
        ) ...
    );
end

%% ── Complétion enrichie ────────────────────────────────────────────────────
function items = __lsp_completions__(prefix, workspace_dir)
    items_list = {};

    % ── Détection complétion de champ de struct (ex: "s.fi")
    dot_idx = find(prefix == '.', 1, 'last');
    if ~isempty(dot_idx) && dot_idx > 1
        varname   = prefix(1:dot_idx-1);
        field_pfx = prefix(dot_idx+1:end);
        try
            fields = evalin('base', ['fieldnames(' varname ')']);
            for k = 1:length(fields)
                f = fields{k};
                if strncmp(f, field_pfx, length(field_pfx))
                    items_list{end+1} = struct( ...
                        'label',      [varname '.' f], ...
                        'insertText', f, ...
                        'kind',       5, ...   % 5 = Field
                        'detail',     'struct field' ...
                    );
                end
            end
        catch
        end
        % Si on a trouvé des champs, on les retourne directement
        if ~isempty(items_list)
            items = __items_to_struct__(items_list);
            return
        end
    end

    % ── Complétion built-in via completion_matches
    builtin_matches = {};
    try
        raw = completion_matches(prefix);
        if ischar(raw)
            builtin_matches = strsplit(strtrim(raw), '\n');
        elseif iscell(raw)
            builtin_matches = raw;
        end
        builtin_matches = builtin_matches(~cellfun(@isempty, builtin_matches));
    catch
    end
    for k = 1:length(builtin_matches)
        m = builtin_matches{k};
        items_list{end+1} = struct( ...
            'label',      m, ...
            'insertText', m, ...
            'kind',       3, ...   % 3 = Function
            'detail',     'built-in' ...
        );
    end

    % ── Complétion des fonctions utilisateur (fichiers .m du workspace)
    if ~isempty(workspace_dir) && exist(workspace_dir, 'dir')
        try
            m_files = dir(fullfile(workspace_dir, '**', '*.m'));
            for k = 1:length(m_files)
                [~, fname] = fileparts(m_files(k).name);
                if strncmp(fname, prefix, length(prefix)) && ...
                   ~any(strcmp(fname, builtin_matches))
                    items_list{end+1} = struct( ...
                        'label',      fname, ...
                        'insertText', fname, ...
                        'kind',       3, ...
                        'detail',     'user function' ...
                    );
                end
            end
        catch
        end
    end

    % ── Complétion des variables du workspace
    try
        ws_vars = evalin('base', 'who()');
        for k = 1:length(ws_vars)
            v = ws_vars{k};
            if strncmp(v, prefix, length(prefix)) && ...
               ~any(cellfun(@(x) strcmp(x.label, v), items_list))
                items_list{end+1} = struct( ...
                    'label',      v, ...
                    'insertText', v, ...
                    'kind',       6, ...   % 6 = Variable
                    'detail',     'workspace' ...
                );
            end
        end
    catch
    end

    items = __items_to_struct__(items_list);
end

function s = __items_to_struct__(items_list)
    if isempty(items_list)
        s = struct([]);
    else
        s = [items_list{:}];
    end
end

%% ── Signature Help ──────────────────────────────────────────────────────────
function result = __lsp_signature_help__(funcname)
    result = struct('signatures', {{}}, 'activeSignature', 0, 'activeParameter', 0);
    if isempty(funcname), return; end
    try
        [~, txt] = system(['octave --no-gui --eval "help ' funcname '" 2>&1']);
        txt = strtrim(txt);
        if isempty(txt), return; end

        % Extrait la première ligne de signature (commence souvent par le nom de la fonction)
        lines = strsplit(txt, '\n');
        sig_line = '';
        for i = 1:min(10, length(lines))
            l = strtrim(lines{i});
            % Cherche la ligne qui ressemble à une signature : "funcname(...)"
            if ~isempty(regexp(l, ['^' funcname '\s*\('], 'once')) || ...
               ~isempty(regexp(l, ['^\[.*\]\s*=\s*' funcname '\s*\('], 'once'))
                sig_line = l;
                break;
            end
        end
        if isempty(sig_line)
            sig_line = lines{1};
        end

        % Extrait les paramètres depuis les parenthèses
        params = {};
        tok = regexp(sig_line, '\(([^)]*)\)', 'tokens', 'once');
        if ~isempty(tok) && ~isempty(tok{1})
            param_strs = strsplit(tok{1}, ',');
            for k = 1:length(param_strs)
                p = strtrim(param_strs{k});
                if ~isempty(p)
                    params{end+1} = struct('label', p);
                end
            end
        end

        doc = strjoin(lines(1:min(5,end)), '\n');
        sig = struct( ...
            'label',         sig_line, ...
            'documentation', struct('kind','markdown','value',['```\n' doc '\n```']), ...
            'parameters',    {params} ...
        );
        result = struct('signatures', {{sig}}, 'activeSignature', 0, 'activeParameter', 0);
    catch
    end
end

%% ── Hover via help ──────────────────────────────────────────────────────────
function result = __lsp_hover__(word)
    result = [];
    if isempty(word), return; end
    try
        [~, txt] = system(['octave --no-gui --eval "help ' word '" 2>&1']);
        txt = strtrim(txt);
        if ~isempty(txt)
            % Limite à 20 lignes pour ne pas surcharger l'infobulle
            lines = strsplit(txt, '\n');
            snippet = strjoin(lines(1:min(20,end)), '\n');
            result = struct( ...
                'contents', struct( ...
                    'kind',  'markdown', ...
                    'value', ['```\n' snippet '\n```'] ...
                ) ...
            );
        end
    catch
    end
end

%% ── Go-to-definition via which ─────────────────────────────────────────────
function result = __lsp_definition__(word)
    result = [];
    if isempty(word), return; end
    try
        filepath = strtrim(which(word));
        if ~isempty(filepath) && exist(filepath, 'file')
            % Normalise l'URI selon la plateforme
            if ispc()
                uri = ['file:///' strrep(filepath, '\', '/')];
            else
                uri = ['file://' filepath];
            end
            result = struct( ...
                'uri',   uri, ...
                'range', struct( ...
                    'start', struct('line', 0, 'character', 0), ...
                    'end',   struct('line', 0, 'character', 0) ...
                ) ...
            );
        end
    catch
    end
end

%% ── Diagnostics (cross-platform) ────────────────────────────────────────────
function __lsp_publish_diagnostics__(uri, text)
    diagnostics = {};
    try
        % Écrit le texte dans un fichier temporaire
        tmpf = fullfile(tempdir(), ['mfv_check_' num2str(floor(time()*1000)) '.m']);
        fid  = fopen(tmpf, 'w');
        fprintf(fid, '%s', text);
        fclose(fid);

        % Lance la vérification : redirige stderr vers stdout pour capture
        % (2>&1 fonctionne sur Unix, Windows CMD et PowerShell)
        octave_cmd = ['octave --no-gui --norc --eval "source(' ...
                      '''' strrep(tmpf, '\', '/') ''')" 2>&1'];
        [~, out] = system(octave_cmd);
        delete(tmpf);

        % Parse les erreurs/warnings
        lines = strsplit(out, '\n');
        for i = 1:length(lines)
            line = strtrim(lines{i});
            if strncmpi(line, 'error:', 6) || strncmpi(line, 'warning:', 8)
                sev  = 1;
                msg  = line;
                lnum = 0;

                tok = regexp(line, 'line\s+(\d+)', 'tokens');
                if ~isempty(tok)
                    lnum = str2double(tok{1}{1}) - 1;
                end
                if strncmpi(line, 'warning:', 8)
                    sev = 2;
                end

                diagnostics{end+1} = struct( ...
                    'range', struct( ...
                        'start', struct('line', max(0,lnum), 'character', 0), ...
                        'end',   struct('line', max(0,lnum), 'character', 999) ...
                    ), ...
                    'severity', sev, ...
                    'source',   'octave', ...
                    'message',  msg ...
                );
            end
        end
    catch
    end

    notif = struct( ...
        'jsonrpc', '2.0', ...
        'method',  'textDocument/publishDiagnostics', ...
        'params',  struct( ...
            'uri',         uri, ...
            'diagnostics', {diagnostics} ...
        ) ...
    );
    __lsp_send__(notif);
end

%% ── Exécution de code + envoi workspace ────────────────────────────────────
function __lsp_run_code__(code)
    try
        evalin('base', code);
    catch e
        __mfv_notify__(struct('type', 'error', 'message', e.message));
    end
    % Toujours mettre à jour le Variable Explorer après exécution
    try
        __mfv_send_workspace__();
    catch
    end
end

%% ── Utilitaires texte ───────────────────────────────────────────────────────
function key = uri2key(uri)
    key = regexprep(uri, '[^a-zA-Z0-9]', '_');
    if ~isempty(key) && (key(1) >= '0' && key(1) <= '9')
        key = ['f_' key];
    end
end

function prefix = __extract_prefix__(text, line_idx, char_idx)
    % Extrait le préfixe courant (mot partiel, avec possibilité de "struct.")
    prefix = '';
    if isempty(text), return; end
    lines = strsplit(text, '\n');
    if line_idx + 1 > length(lines), return; end
    cur_line = lines{line_idx + 1};
    if char_idx > length(cur_line)
        char_idx = length(cur_line);
    end
    segment = cur_line(1:char_idx);
    % Préfixe = dernier token alphanumérique + point (pour les structs)
    tok = regexp(segment, '[\w\.]+$', 'match');
    if ~isempty(tok)
        prefix = tok{end};
    end
end

function funcname = __extract_call_context__(text, line_idx, char_idx)
    % Extrait le nom de la fonction devant le '(' courant pour signatureHelp.
    funcname = '';
    if isempty(text), return; end
    lines = strsplit(text, '\n');
    if line_idx + 1 > length(lines), return; end
    cur_line = lines{line_idx + 1};
    if char_idx > length(cur_line)
        char_idx = length(cur_line);
    end
    segment = cur_line(1:char_idx);
    % Cherche le dernier "nom(" avant la position
    tok = regexp(segment, '(\w+)\s*\([^)]*$', 'tokens');
    if ~isempty(tok)
        funcname = tok{end}{1};
    end
end

function word = __word_at__(text, line_idx, char_idx)
    word = '';
    if isempty(text), return; end
    lines = strsplit(text, '\n');
    if line_idx + 1 > length(lines), return; end
    cur_line = lines{line_idx + 1};
    if char_idx > length(cur_line)
        char_idx = length(cur_line);
    end
    matches = regexp(cur_line, '\w+', 'match');
    starts  = regexp(cur_line, '\w+', 'start');
    for i = 1:length(matches)
        s = starts(i);
        e = s + length(matches{i}) - 1;
        if s <= char_idx + 1 && char_idx + 1 <= e
            word = matches{i};
            return;
        end
    end
end

%% ── Helper notification MFV ──────────────────────────────────────────────────
%  Anciennement défini ici comme subfunction écrivant sur stdout. Cette version
%  corrompait le framing LSP (le stdout du process LSP est lu par le
%  LanguageClient). On utilise désormais __mfv_notify__.m du dossier runtime/,
%  ajouté au path par OctaveSession.ts, qui envoie via TCP au serveur de
%  l'extension.
