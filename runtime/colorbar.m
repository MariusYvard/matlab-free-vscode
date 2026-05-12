function varargout = colorbar(varargin)
%colorbar  Override matlab-free-vscode : signale l'ajout d'une colorbar.
    global __mfv_colorbar__;
    __mfv_colorbar__ = true;
    if nargout > 0
        [varargout{1:nargout}] = __mfv_call_real__('colorbar', varargin{:});
    else
        try
            __mfv_call_real__('colorbar', varargin{:});
        catch
        end
    end
    __mfv_notify__(struct('type','colorbar','visible',true));
end
