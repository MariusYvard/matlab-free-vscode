%% bootstrap.m  matlab-free-vscode
%
%  v0.5.0 : Initialisation des variables globales.
%
%  Les fonctions d'interception (plot, surf, mesh, patch, ...) ne sont plus
%  définies ici. Elles vivent dans des fichiers .m séparés du dossier runtime/,
%  car Octave ne propage pas les définitions de fonctions d'un script vers
%  l'extérieur (contrairement à MATLAB R2016b+ pour les "live scripts").
%
%  Voir : plot.m, surf.m, mesh.m, patch.m, colormap.m, ..., et le helper
%  __mfv_call_real__.m qui appelle la fonction Octave native en court-circuitant
%  notre override (rmpath temporaire).

global __mfv_colormap__;
global __mfv_colorbar__;
global __mfv_fig_counter__;

if isempty(__mfv_colormap__),    __mfv_colormap__ = 'jet';   end
if isempty(__mfv_colorbar__),    __mfv_colorbar__ = false;   end
if isempty(__mfv_fig_counter__), __mfv_fig_counter__ = 0;    end
