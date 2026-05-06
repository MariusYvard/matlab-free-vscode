%% octave_compat.m — matlab-free-vscode
%  Correctifs de compatibilite MATLAB -> Octave, appliques automatiquement.

this_dir = fileparts(mfilename('fullpath'));

%% norm2 (alias minuscule)
__write_if_missing__(fullfile(this_dir,'norm2.m'), "function B=norm2(A)\nB=sqrt(sum(A.^2,2));\nend\n");

%% norme_vecteur
__write_if_missing__(fullfile(this_dir,'norme_vecteur.m'), "function B=norme_vecteur(A)\nn=sqrt(sum(A.^2,2));n(n==0)=1;\nB=A./(n*ones(1,size(A,2)));\nend\n");

%% distance_points
__write_if_missing__(fullfile(this_dir,'distance_points.m'), strjoin({
    "function D=distance_points(A,B)"
    "if nargin==1,B=A;end"
    "nA=size(A,1);nB=size(B,1);"
    "D=sqrt(max(0,sum(A.^2,2)*ones(1,nB)+ones(nA,1)*sum(B.^2,2)'-2*(A*B')));"
    "end"
    }, '\n'));

%% recherche_points_proche
__write_if_missing__(fullfile(this_dir,'recherche_points_proche.m'), "function [I,d]=recherche_points_proche(A,B)\n[I,d]=recherche_points_proche_v2(A,B);\nend\n");

%% Patch my_procrustes
proc = fullfile(this_dir,'my_procrustes.m');
if exist(proc,'file')
    fid=fopen(proc,'r'); c=fread(fid,'*char')'; fclose(fid);
    if ~isempty(strfind(c,"message("))
        c=strrep(c,"error(message('stats:procrustes:InputSizeMismatch'))","error('procrustes: tailles X/Y incompatibles')");
        c=strrep(c,"error(message('stats:procrustes:TooManyColumns'))","error('procrustes: Y a plus de colonnes que X')");
        fid=fopen(proc,'w'); fwrite(fid,c); fclose(fid);
    end
end

function __write_if_missing__(p, content)
    if ~exist(p,'file')
        fid=fopen(p,'w'); fprintf(fid,'%s',content); fclose(fid);
    end
end
