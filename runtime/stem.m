function varargout = stem(varargin)
%stem  Override matlab-free-vscode : capture la figure en SVG après dessin.
    [varargout{1:nargout}] = __mfv_call_real__('stem', varargin{:});
    try
        __mfv_capture_svg__(gcf());
    catch
    end
end
