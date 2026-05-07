function __mfv_capture_svg__(h)
%__MFV_CAPTURE_SVG__  Exporte la figure h en SVG et notifie VS Code.
    p = fullfile(tempdir(), ['mfv_fig_' num2str(h) '.svg']);
    try
        print(h, p, '-dsvg', '-r0');
        __mfv_notify__(struct('type', 'figure', 'path', p, 'handle', h));
    catch
    end
end
