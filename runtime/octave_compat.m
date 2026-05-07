%% octave_compat.m — matlab-free-vscode
%  Correctifs de compatibilité MATLAB → Octave, appliqués automatiquement.
%  Génère les fichiers manquants dans le dossier courant si nécessaire.
%  Sûr à appeler plusieurs fois (idempotent).
%
%  NOTE: pas de helper function — Octave n'hisse pas les définitions de
%  fonctions dans les scripts (contrairement à MATLAB).

this_dir = fileparts(mfilename('fullpath'));

%% ── norm2 (alias minuscule) ──────────────────────────────────────────────
p = fullfile(this_dir, 'norm2.m');
if ~exist(p, 'file')
    fid = fopen(p, 'w');
    fprintf(fid, 'function B=norm2(A)\nB=sqrt(sum(A.^2,2));\nend\n');
    fclose(fid);
end

%% ── norme_vecteur ────────────────────────────────────────────────────────
p = fullfile(this_dir, 'norme_vecteur.m');
if ~exist(p, 'file')
    fid = fopen(p, 'w');
    fprintf(fid, 'function B=norme_vecteur(A)\nn=sqrt(sum(A.^2,2));n(n==0)=1;\nB=A./(n*ones(1,size(A,2)));\nend\n');
    fclose(fid);
end

%% ── distance_points ──────────────────────────────────────────────────────
p = fullfile(this_dir, 'distance_points.m');
if ~exist(p, 'file')
    fid = fopen(p, 'w');
    fprintf(fid, 'function D=distance_points(A,B)\n');
    fprintf(fid, 'if nargin==1,B=A;end\n');
    fprintf(fid, 'nA=size(A,1);nB=size(B,1);\n');
    fprintf(fid, 'D=sqrt(max(0,sum(A.^2,2)*ones(1,nB)+ones(nA,1)*sum(B.^2,2)''-2*(A*B'')));\n');
    fprintf(fid, 'end\n');
    fclose(fid);
end

%% ── recherche_points_proche ──────────────────────────────────────────────
p = fullfile(this_dir, 'recherche_points_proche.m');
if ~exist(p, 'file')
    fid = fopen(p, 'w');
    fprintf(fid, 'function [I,d]=recherche_points_proche(A,B)\n[I,d]=recherche_points_proche_v2(A,B);\nend\n');
    fclose(fid);
end

%% ── Patch my_procrustes : message() MATLAB-only ──────────────────────────
proc = fullfile(this_dir, 'my_procrustes.m');
if exist(proc, 'file')
    fid = fopen(proc, 'r'); c = fread(fid, '*char')'; fclose(fid);
    if ~isempty(strfind(c, "message("))
        c = strrep(c, "error(message('stats:procrustes:InputSizeMismatch'))", ...
                      "error('procrustes: tailles X/Y incompatibles')");
        c = strrep(c, "error(message('stats:procrustes:TooManyColumns'))", ...
                      "error('procrustes: Y a plus de colonnes que X')");
        fid = fopen(proc, 'w'); fwrite(fid, c); fclose(fid);
    end
end
