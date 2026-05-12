function h = patch(varargin)
%patch  Override matlab-free-vscode : sérialise le maillage 3D vers VS Code.
    global __mfv_colormap__;
    global __mfv_colorbar__;
    if isempty(__mfv_colormap__), __mfv_colormap__ = 'jet'; end
    if isempty(__mfv_colorbar__), __mfv_colorbar__ = false; end

    h = __mfv_call_real__('patch', varargin{:});

    V = []; F = []; cdata = []; facecolor = 'flat'; edgecolor = 'k';
    if nargin >= 1 && ischar(varargin{1})
        for k = 1:2:length(varargin)-1
            key = lower(varargin{k});
            key(key == ' ') = '_';
            switch key
                case 'vertices',  V = varargin{k+1};
                case 'faces',     F = varargin{k+1};
                case 'cdata',     cdata = varargin{k+1};
                case 'facevertexcdata', cdata = varargin{k+1};
                case 'facecolor', facecolor = varargin{k+1};
                case 'edgecolor', edgecolor = varargin{k+1};
            end
        end
    else
        try
            V = get(h,'Vertices');
            F = get(h,'Faces');
            cdata = get(h,'FaceVertexCData');
            facecolor = get(h,'FaceColor');
            edgecolor = get(h,'EdgeColor');
        catch
        end
    end

    payload = struct( ...
        'type',      '3d', ...
        'kind',      'patch', ...
        'vertices',  V, ...
        'faces',     F, ...
        'cdata',     cdata, ...
        'facecolor', facecolor, ...
        'edgecolor', edgecolor, ...
        'colormap',  __mfv_colormap__, ...
        'colorbar',  __mfv_colorbar__);

    try
        p = __mfv_tmpjson__('patch');
        __mfv_write_json__(p, payload);
        __mfv_notify__(struct('type','patch','json', p));
    catch
    end
    __mfv_colorbar__ = false;
end
