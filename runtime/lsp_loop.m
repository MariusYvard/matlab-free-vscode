%% lsp_loop.m — matlab-free-vscode
%  Boucle LSP JSON-RPC complète exécutée par OctaveSession.ts au démarrage.
%  Implémente le protocole Language Server Protocol (LSP) via stdin/stdout.
%
%  Messages entrants  : Content-Length: N

{JSON-RPC}
%  Messages sortants  : Content-Length: N

{JSON-RPC}
%  Notifications MFV  : 
__MFV__{JSON}__MFV__
  (bootstrap.m)
%
%  Méthodes LSP supportées :
%    initialize / initialized / shutdown / exit
%    textDocument/didOpen, didChange, didClose, didSave
%    textDocument/completion
%    textDocument/hover
%    textDocument/definition
%    textDocument/publishDiagnostics  (côté serveur → client)
%    octave/runCode                   (méthode custom : exécute du code)

function __mfv_lsp_loop__()

%% ── État de la session ───────────────────────────────────────────────────
files      = struct();   % uri → texte source
initialized = false;
shutdown_req = false;

%% ── Boucle principale ────────────────────────────────────────────────────
while ~shutdown_req

    %% 1. Lecture des headers HTTP-like
    content_length = 0;
    while true
        line = fgetl(stdin);
        if isequal(line, -1)   % EOF → quitte proprement
            return;
        end
        line = strtrim(line);
        if isempty(line)
            break;             % ligne vide = fin des headers
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
            response = __lsp_response__(msg, __lsp_capabilities__());

        case 'initialized'
            % Notification → pas de réponse

        case 'shutdown'
            shutdown_req = true;
            response = __lsp_response__(msg, []); % null result

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
            items  = __lsp_completions__(prefix);
            response = __lsp_response__(msg, struct( ...
                'isIncomplete', false, ...
                'items', items));

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
            % Méthode inconnue → erreur standard LSP
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
    body = jsonencode(obj);
    % Comptage byte-accurate (important pour UTF-8)
    bytes = uint8(body);
    fprintf(stdout, 'Content-Length: %d

', length(bytes));
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
            'hoverProvider',      true, ...
            'definitionProvider', true  ...
        ), ...
        'serverInfo', struct( ...
            'name',    'matlab-free-vscode (Octave)', ...
            'version', '0.1.0' ...
        ) ...
    );
end

%% ── Complétion via completion_matches() ────────────────────────────────────
function items = __lsp_completions__(prefix)
    try
        matches = completion_matches(prefix);
    catch
        matches = {};
    end

    if ischar(matches)
        matches = strsplit(strtrim(matches), '
');
    end
    matches = matches(~cellfun(@isempty, matches));

    items = struct( ...
        'label',      matches, ...
        'kind',       num2cell(repmat(3, length(matches), 1)), ...
        'insertText', matches ...
    );
    if isempty(items)
        items = struct([]);
    end
end

%% ── Hover via help ──────────────────────────────────────────────────────────
function result = __lsp_hover__(word)
    result = [];
    if isempty(word), return; end
    try
        [~, txt] = system(['octave --no-gui --eval "help ' word '" 2>/dev/null']);
        if ~isempty(strtrim(txt))
            result = struct( ...
                'contents', struct( ...
                    'kind',  'markdown', ...
                    'value', ['``
' strtrim(txt) '
``'] ...
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
            uri = ['file:///' strrep(filepath, '\', '/')];
            if ~strncmp(uri, 'file:////', 9)
                uri = strrep(uri, 'file:///', 'file:///');
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

%% ── Diagnostics via octave --check-syntax ──────────────────────────────────
function __lsp_publish_diagnostics__(uri, text)
    diagnostics = {};
    try
        tmpf = [tempdir() 'mfv_check_' num2str(floor(time()*1000)) '.m'];
        fid  = fopen(tmpf, 'w');
        fprintf(fid, '%s', text);
        fclose(fid);

        [~, out] = system(['octave --no-gui --eval "source(''' ...
            strrep(tmpf, '\', '/') ''')" 2>&1']);
        delete(tmpf);

        lines = strsplit(out, '
');
        for i = 1:length(lines)
            line = strtrim(lines{i});
            if strncmpi(line, 'error:', 6) || strncmpi(line, 'warning:', 8)
                sev  = 1;
                msg  = line;
                lnum = 0;

                tok = regexp(line, 'lines+(d+)', 'tokens');
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

%% ── Exécution de code utilisateur ──────────────────────────────────────────
function __lsp_run_code__(code)
    try
        evalin('base', code);
    catch e
        __mfv_notify__(struct('type', 'error', 'message', e.message));
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
    prefix = '';
    if isempty(text), return; end
    lines = strsplit(text, '
');
    if line_idx + 1 > length(lines), return; end
    cur_line = lines{line_idx + 1};
    if char_idx > length(cur_line)
        char_idx = length(cur_line);
    end
    segment = cur_line(1:char_idx);
    tok = regexp(segment, '[w.]+$', 'match');
    if ~isempty(tok)
        prefix = tok{end};
    end
end

function word = __word_at__(text, line_idx, char_idx)
    word = '';
    if isempty(text), return; end
    lines = strsplit(text, '
');
    if line_idx + 1 > length(lines), return; end
    cur_line = lines{line_idx + 1};
    if char_idx > length(cur_line)
        char_idx = length(cur_line);
    end
    matches = regexp(cur_line, 'w+', 'match');
    starts  = regexp(cur_line, 'w+', 'start');
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
function __mfv_notify__(payload)
    try
        fprintf(stdout, '
__MFV__%s__MFV__
', jsonencode(payload));
        fflush(stdout);
    catch
    end
end
