function varargout = drawnow(varargin)
%drawnow  Override matlab-free-vscode : notifie le panneau actif.
    if nargout > 0
        [varargout{1:nargout}] = __mfv_call_real__('drawnow', varargin{:});
    else
        try
            __mfv_call_real__('drawnow', varargin{:});
        catch
        end
    end
    __mfv_notify__(struct('type','drawnow'));
end
