function varargout = colormap(varargin)
%colormap  Override matlab-free-vscode : propage le choix au panneau 3D.
    global __mfv_colormap__;
    if isempty(__mfv_colormap__), __mfv_colormap__ = 'jet'; end
    if nargin == 0
        name = 'jet';
    elseif ischar(varargin{1})
        name = lower(varargin{1});
    else
        name = 'custom';
    end
    __mfv_colormap__ = name;
    if nargout > 0
        [varargout{1:nargout}] = __mfv_call_real__('colormap', varargin{:});
    else
        try
            __mfv_call_real__('colormap', varargin{:});
        catch
        end
    end
    __mfv_notify__(struct('type','colormap','name',name));
end
