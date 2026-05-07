%% startup.m — matlab-free-vscode
%  Point d'entrée Octave. Appelé automatiquement par OctaveSession.ts

this_dir = fileparts(mfilename('fullpath'));
addpath(this_dir);

%% Correctifs compatibilité MATLAB -> Octave
run(fullfile(this_dir, 'octave_compat.m'));

%% Intercepts de visualisation
run(fullfile(this_dir, 'bootstrap.m'));

fprintf('[matlab-free] Session Octave prete.\n');
fflush(stdout);
