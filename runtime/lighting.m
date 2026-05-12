function varargout = lighting(varargin)
%lighting  Override matlab-free-vscode : propage le mode au panneau 3D.
    if nargin < 1, varargin = {'phong'}; end
    if nargout > 0
        [varargout{1:nargout}] = __mfv_call_real__('lighting', varargin{:});
    else
        try
            __mfv_call_real__('lighting', varargin{:});
        catch
        end
    end
    if ischar(varargin{1})
        __mfv_notify__(struct('type','lighting','mode',varargin{1}));
    end
end
