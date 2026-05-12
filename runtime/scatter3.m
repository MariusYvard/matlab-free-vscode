function varargout = scatter3(varargin)
%scatter3  Override matlab-free-vscode : capture la figure en SVG après dessin.
    [varargout{1:nargout}] = __mfv_call_real__('scatter3', varargin{:});
    try
        __mfv_capture_svg__(gcf());
    catch
    end
end
