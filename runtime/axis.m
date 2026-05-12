function varargout = axis(varargin)
%axis  Override matlab-free-vscode : notifie le mode si chaîne.
    if nargout > 0
        [varargout{1:nargout}] = __mfv_call_real__('axis', varargin{:});
    else
        try
            __mfv_call_real__('axis', varargin{:});
        catch
        end
    end
    if nargin > 0 && ischar(varargin{1})
        __mfv_notify__(struct('type','axis','mode',varargin{1}));
    end
end
