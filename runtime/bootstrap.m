%% bootstrap.m — matlab-free-vscode
%  Charge automatiquement au démarrage de la session Octave par OctaveSession.ts.
%  Intercepte toutes les fonctions de visualisation MATLAB et les redirige
%  vers les panneaux Webview de l'extension VS Code.
%
%  Protocole de communication :
%    Octave stdout → lignes JSON encadrées par \n{"type":"...","..."}\n
%    Le MsgParser.ts sépare ces lignes du flux LSP JSON-RPC normal.
%
%  Licence : MIT — https://github.com/MariusYvard/matlab-free-vscode

%% ── État global de la session ────────────────────────────────────────────
global __mfv_colormap__;   % colormap courante ('jet', 'hot', 'gray', ...)
global __mfv_colorbar__;   % colorbar demandée pour le prochain patch
global __mfv_fig_counter__;% compteur de figures ouvertes

__mfv_colormap__   = 'jet';
__mfv_colorbar__   = false;
__mfv_fig_counter__ = 0;

%% ── Helpers internes ─────────────────────────────────────────────────────

function __mfv_notify__(payload)
    % Émet un message JSON sur stdout, encadré par des sauts de ligne
    % pour que MsgParser.ts puisse l'isoler du flux LSP.
    try
        fprintf(stdout, '\n__MFV__%s__MFV__\n', jsonencode(payload));
        fflush(stdout);
    catch
    end
end

function tmppath = __mfv_tmpjson__(prefix)
    tmppath = fullfile(tempdir(), [prefix '_' num2str(floor(time()*1000)) '.json']);
end

function __mfv_write_json__(filepath, data)
    fid = fopen(filepath, 'w');
    fprintf(fid, '%s', jsonencode(data));
    fclose(fid);
end

%% ── colormap ─────────────────────────────────────────────────────────────
function colormap(varargin)
    global __mfv_colormap__;
    if nargin == 0
        name = 'jet';
    elseif ischar(varargin{1})
        name = lower(varargin{1});
    else
        name = 'custom';
    end
    __mfv_colormap__ = name;
    __mfv_notify__(struct('type','colormap','name',name));
end

%% ── colorbar ─────────────────────────────────────────────────────────────
function colorbar(varargin)
    global __mfv_colorbar__;
    __mfv_colorbar__ = true;
    __mfv_notify__(struct('type','colorbar','visible',true));
end

%% ── patch ────────────────────────────────────────────────────────────────
function h = patch(varargin)
    global __mfv_colormap__;
    global __mfv_colorbar__;

    h = builtin('patch', varargin{:});

    if ischar(varargin{1})
        props = struct();
        for k = 1:2:length(varargin)-1
            key = lower(varargin{k});
            key(key == ' ') = '_';
            props.(key) = varargin{k+1};
        end
        V         = [];
        F         = [];
        cdata     = [];
        facecolor = 'flat';
        edgecolor = 'k';
        if isfield(props,'vertices'),  V         = props.vertices;  end
        if isfield(props,'faces'),     F         = props.faces;     end
        if isfield(props,'cdata'),     cdata     = props.cdata;     end
        if isfield(props,'facecolor'), facecolor = props.facecolor; end
        if isfield(props,'edgecolor'), edgecolor = props.edgecolor; end
    else
        V         = get(h,'Vertices');
        F         = get(h,'Faces');
        cdata     = get(h,'FaceVertexCData');
        facecolor = get(h,'FaceColor');
        edgecolor = get(h,'EdgeColor');
    end

    payload = struct( ...
        'type',       '3d', ...
        'kind',       'patch', ...
        'vertices',   V, ...
        'faces',      F, ...
        'cdata',      cdata, ...
        'facecolor',  facecolor, ...
        'edgecolor',  edgecolor, ...
        'colormap',   __mfv_colormap__, ...
        'colorbar',   __mfv_colorbar__ ...
    );

    p = __mfv_tmpjson__('patch');
    __mfv_write_json__(p, payload);
    __mfv_notify__(struct('type','patch','json', p));
    __mfv_colorbar__ = false;
end

%% ── Figures 2D ───────────────────────────────────────────────────────────
function varargout = plot(varargin)
    [varargout{1:nargout}] = builtin('plot', varargin{:});
    __mfv_capture_svg__(gcf());
end
function varargout = bar(varargin)
    [varargout{1:nargout}] = builtin('bar', varargin{:});
    __mfv_capture_svg__(gcf());
end
function varargout = histogram(varargin)
    [varargout{1:nargout}] = builtin('histogram', varargin{:});
    __mfv_capture_svg__(gcf());
end
function varargout = scatter(varargin)
    [varargout{1:nargout}] = builtin('scatter', varargin{:});
    __mfv_capture_svg__(gcf());
end
function varargout = imagesc(varargin)
    [varargout{1:nargout}] = builtin('imagesc', varargin{:});
    __mfv_capture_svg__(gcf());
end
function varargout = contour(varargin)
    [varargout{1:nargout}] = builtin('contour', varargin{:});
    __mfv_capture_svg__(gcf());
end
function varargout = contourf(varargin)
    [varargout{1:nargout}] = builtin('contourf', varargin{:});
    __mfv_capture_svg__(gcf());
end
function varargout = quiver(varargin)
    [varargout{1:nargout}] = builtin('quiver', varargin{:});
    __mfv_capture_svg__(gcf());
end
function varargout = quiver3(varargin)
    [varargout{1:nargout}] = builtin('quiver3', varargin{:});
    __mfv_capture_svg__(gcf());
end
function varargout = semilogy(varargin)
    [varargout{1:nargout}] = builtin('semilogy', varargin{:});
    __mfv_capture_svg__(gcf());
end
function varargout = semilogx(varargin)
    [varargout{1:nargout}] = builtin('semilogx', varargin{:});
    __mfv_capture_svg__(gcf());
end
function varargout = loglog(varargin)
    [varargout{1:nargout}] = builtin('loglog', varargin{:});
    __mfv_capture_svg__(gcf());
end
function varargout = stem(varargin)
    [varargout{1:nargout}] = builtin('stem', varargin{:});
    __mfv_capture_svg__(gcf());
end
function varargout = stairs(varargin)
    [varargout{1:nargout}] = builtin('stairs', varargin{:});
    __mfv_capture_svg__(gcf());
end
function varargout = errorbar(varargin)
    [varargout{1:nargout}] = builtin('errorbar', varargin{:});
    __mfv_capture_svg__(gcf());
end
function varargout = pie(varargin)
    [varargout{1:nargout}] = builtin('pie', varargin{:});
    __mfv_capture_svg__(gcf());
end

%% ── Figures 3D ───────────────────────────────────────────────────────────
function varargout = surf(varargin)
    [varargout{1:nargout}] = builtin('surf', varargin{:});
    __mfv_send_surf__(varargin{:});
end
function varargout = mesh(varargin)
    [varargout{1:nargout}] = builtin('mesh', varargin{:});
    __mfv_send_surf__(varargin{:});
end
function varargout = plot3(varargin)
    [varargout{1:nargout}] = builtin('plot3', varargin{:});
    __mfv_capture_svg__(gcf());
end
function varargout = scatter3(varargin)
    [varargout{1:nargout}] = builtin('scatter3', varargin{:});
    __mfv_capture_svg__(gcf());
end

%% ── Éclairage ────────────────────────────────────────────────────────────
function camlight(varargin)
    builtin('camlight', varargin{:});
    __mfv_notify__(struct('type','camlight'));
end
function lighting(mode)
    if nargin < 1, mode = 'phong'; end
    builtin('lighting', mode);
    __mfv_notify__(struct('type','lighting','mode',mode));
end

%% ── Axes & refresh ───────────────────────────────────────────────────────
function axis(varargin)
    builtin('axis', varargin{:});
    if nargin > 0 && ischar(varargin{1})
        __mfv_notify__(struct('type','axis','mode',varargin{1}));
    end
end
function drawnow(varargin)
    builtin('drawnow', varargin{:});
    __mfv_notify__(struct('type','drawnow'));
end
function title(varargin)
    builtin('title', varargin{:});
    if nargin > 0 && ischar(varargin{1})
        __mfv_notify__(struct('type','title','text',varargin{1}));
    end
end
function xlabel(varargin)
    builtin('xlabel', varargin{:});
end
function ylabel(varargin)
    builtin('ylabel', varargin{:});
end
function zlabel(varargin)
    builtin('zlabel', varargin{:});
end
function legend(varargin)
    builtin('legend', varargin{:});
end
function grid(varargin)
    builtin('grid', varargin{:});
end
function hold(varargin)
    builtin('hold', varargin{:});
end
function subplot(varargin)
    builtin('subplot', varargin{:});
end
function figure(varargin)
    builtin('figure', varargin{:});
end
function clf(varargin)
    builtin('clf', varargin{:});
end
function close(varargin)
    builtin('close', varargin{:});
end
function xlim(varargin)
    builtin('xlim', varargin{:});
end
function ylim(varargin)
    builtin('ylim', varargin{:});
end
function zlim(varargin)
    builtin('zlim', varargin{:});
end

%% ── Variable Explorer ─────────────────────────────────────────────────────
function __mfv_send_workspace__()
    % Envoie l'état du workspace base vers VS Code (panneau Variable Explorer).
    % Appelé automatiquement par __lsp_run_code__ après chaque exécution.
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

%% ── Helpers privés ───────────────────────────────────────────────────────
function __mfv_capture_svg__(h)
    p = fullfile(tempdir(), ['mfv_fig_' num2str(h) '.svg']);
    try
        print(h, p, '-dsvg', '-r0');
        __mfv_notify__(struct('type','figure','path',p,'handle',h));
    catch
    end
end

function __mfv_send_surf__(varargin)
    global __mfv_colormap__;
    if nargin >= 3 && isnumeric(varargin{1})
        X = varargin{1}; Y = varargin{2}; Z = varargin{3};
    else
        return
    end
    payload = struct('type','3d','kind','surf','X',X,'Y',Y,'Z',Z, ...
                     'colormap',__mfv_colormap__);
    p = __mfv_tmpjson__('surf');
    __mfv_write_json__(p, payload);
    __mfv_notify__(struct('type','surf','json',p));
end
