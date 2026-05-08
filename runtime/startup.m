%% startup.m — matlab-free-vscode
%  Point d'entrée Octave. Appelé automatiquement par OctaveSession.ts
%  ou manuellement par l'utilisateur : run('startup.m')

this_dir = fileparts(mfilename('fullpath'));
addpath(this_dir);

%% Correctifs compatibilité MATLAB → Octave
run(fullfile(this_dir, 'octave_compat.m'));

%% Intercepts de visualisation
run(fullfile(this_dir, 'bootstrap.m'));

%% Dossiers supplémentaires configurés par l'utilisateur
%  (injecté dynamiquement par OctaveSession.ts via --eval)

fprintf('[matlab-free] Session Octave prête.\n');
fflush(stdout);
