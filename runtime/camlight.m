function varargout = camlight(varargin)
%camlight  Override matlab-free-vscode : notifie le panneau 3D.
    if nargout > 0
        [varargout{1:nargout}] = __mfv_call_real__('camlight', varargin{:});
    else
        try
            __mfv_call_real__('camlight', varargin{:});
        catch
        end
    end
    __mfv_notify__(struct('type','camlight'));
end
