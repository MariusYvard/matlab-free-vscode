function varargout = mesh(varargin)
%mesh  Override matlab-free-vscode : envoie la surface en JSON au panneau 3D.
    if nargout > 0
        [varargout{1:nargout}] = __mfv_call_real__('mesh', varargin{:});
    else
        try
            __mfv_call_real__('mesh', varargin{:});
        catch
        end
    end
    try
        __mfv_send_surf__(varargin{:});
    catch
    end
end
