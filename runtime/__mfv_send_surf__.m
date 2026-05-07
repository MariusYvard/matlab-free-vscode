function __mfv_send_surf__(varargin)
%__MFV_SEND_SURF__  Sérialise une surface (surf/mesh) et notifie VS Code.
    global __mfv_colormap__;
    if nargin >= 3 && isnumeric(varargin{1})
        X = varargin{1}; Y = varargin{2}; Z = varargin{3};
    else
        return
    end
    payload = struct('type', '3d', 'kind', 'surf', ...
                     'X', X, 'Y', Y, 'Z', Z, ...
                     'colormap', __mfv_colormap__);
    p = __mfv_tmpjson__('surf');
    __mfv_write_json__(p, payload);
    __mfv_notify__(struct('type', 'surf', 'json', p));
end
