function varargout = imagesc(varargin)
%imagesc  Override matlab-free-vscode : capture la figure en SVG après dessin.
    [varargout{1:nargout}] = __mfv_call_real__('imagesc', varargin{:});
    try
        __mfv_capture_svg__(gcf());
    catch
    end
end
