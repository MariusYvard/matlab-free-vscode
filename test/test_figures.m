%% test_figures.m  matlab-free-vscode
%  Vérifie que les fonctions de visualisation interceptées par les fichiers
%  runtime/<fn>.m émettent bien une notification MFV (balise __MFV__) sur
%  stdout (fallback).
%
%  Usage : octave --no-gui --eval "run('test/test_figures.m')"

this_dir    = fileparts(mfilename('fullpath'));
runtime_dir = fullfile(this_dir, '..', 'runtime');
addpath(runtime_dir);

% On force le fallback stdout en s'assurant que MFV_TCP_PORT est absent
setenv('MFV_TCP_PORT', '');

run(fullfile(runtime_dir, 'startup.m'));

passed = 0;
failed = 0;

%% Test 0 : nos overrides sont bien dans le path
plot_path = which('plot');
if ~isempty(strfind(plot_path, [filesep 'runtime' filesep])) && ...
   ~isempty(strfind(plot_path, 'plot.m'))
    fprintf('  PASS  plot override est dans le path : %s\n', plot_path);
    passed = passed + 1;
else
    fprintf('  FAIL  plot override absent du path. which()=%s\n', plot_path);
    failed = failed + 1;
end

% Désactive l'affichage graphique pour les tests headless
graphics_toolkit('gnuplot');
setenv('GNUTERM', 'dumb');

cases = { ...
    'plot',     'x=0:0.1:2*pi; plot(x, sin(x));'; ...
    'bar',      'bar([1 3 2 4]);'; ...
    'contour',  '[X,Y]=meshgrid(-2:0.4:2); contour(X,Y,X.^2+Y.^2);'; ...
    'quiver',   '[X,Y]=meshgrid(0:0.5:2); quiver(X,Y,-Y,X);'; ...
    'surf',     '[X,Y]=meshgrid(-2:0.4:2); surf(X,Y,sin(X).*cos(Y));'; ...
    'scatter',  'scatter(rand(20,1), rand(20,1));'; ...
    'imagesc',  'imagesc(magic(5));'; ...
    'colormap', 'colormap(''hot'');'; ...
    'title',    'plot(1:3); title(''hello'');' ...
};

for k = 1:size(cases,1)
    name = cases{k,1};
    expr = cases{k,2};
    try
        out = evalc(expr);
        if ~isempty(strfind(out, '__MFV__'))
            fprintf('  PASS  %s\n', name);
            passed = passed + 1;
        else
            fprintf('  FAIL  %s : aucune balise __MFV__ dans la sortie\n', name);
            failed = failed + 1;
        end
    catch e
        fprintf('  FAIL  %s : %s\n', name, e.message);
        failed = failed + 1;
    end
    close all;
end

fprintf('\n%d tests passés, %d échoués.\n', passed, failed);
if failed > 0
    error('Des tests ont échoué.');
end
