function varargout = title(varargin)
%title  Override matlab-free-vscode : propage le titre au panneau actif.
    if nargout > 0
        [varargout{1:nargout}] = __mfv_call_real__('title', varargin{:});
    else
        try
            __mfv_call_real__('title', varargin{:});
        catch
        end
    end
    if nargin > 0 && ischar(varargin{1})
        __mfv_notify__(struct('type','title','text',varargin{1}));
    end
end
