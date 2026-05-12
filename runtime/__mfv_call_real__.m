function varargout = __mfv_call_real__(fname, varargin)
%__MFV_CALL_REAL__  Appelle la fonction Octave native en court-circuitant
%  notre override portant le même nom.
%
%  Mécanisme : retire temporairement le dossier runtime/ du path,
%  exécute feval(fname, varargin{:}), puis restaure le path. Sûr en
%  cas d'exception (onCleanup).
%
%  Utilisé par tous les fichiers d'interception (plot.m, surf.m, ...).
    here = fileparts(mfilename('fullpath'));

    % Détecte si notre dossier est actuellement dans le path
    p = path();
    sep = pathsep();
    on_path = ~isempty(strfind([sep p sep], [sep here sep]));

    if on_path
        rmpath(here);
    end
    restorer = onCleanup(@() __mfv_restore_path__(here, on_path));

    if nargout == 0
        feval(fname, varargin{:});
    else
        [varargout{1:nargout}] = feval(fname, varargin{:});
    end
end

function __mfv_restore_path__(here, was_on_path)
    if was_on_path
        addpath(here);
    end
end
