%% test_compat.m â matlab-free-vscode
%  VÃ©rifie que les correctifs de compatibilitÃ© MATLABâOctave dans
%  octave_compat.m fonctionnent correctement.
%  Usage : octave --no-gui --eval "run('test/test_compat.m')"

runtime_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'runtime');
addpath(runtime_dir);
run(fullfile(runtime_dir, 'octave_compat.m'));

passed = 0;
failed = 0;

function result = test_case(name, expr_fn)
    try
        expr_fn();
        fprintf('  PASS  %s\n', name);
        result = true;
    catch e
        fprintf('  FAIL  %s : %s\n', name, e.message);
        result = false;
    end
end

%% ââ Test 1 : norm2 ââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
ok = test_case('norm2 disponible', @() assert(norm2([3 4]) == 5));
if ok, passed++; else failed++; end

%% ââ Test 2 : norm2 sur matrice (lignes) ââââââââââââââââââââââââââââââââââ
ok = test_case('norm2 matrice', @() assert(all(abs(norm2([3 4; 0 1]) - [5;1]) < 1e-10)));
if ok, passed++; else failed++; end

%% ââ Test 3 : norme_vecteur ââââââââââââââââââââââââââââââââââââââââââââââââ
ok = test_case('norme_vecteur disponible', @() assert(norm(norme_vecteur([3 4]) - [0.6 0.8]) < 1e-10));
if ok, passed++; else failed++; end

%% ââ Test 4 : norme_vecteur normalisation ââââââââââââââââââââââââââââââââââ
ok = test_case('norme_vecteur unitaire', @() assert(abs(norm(norme_vecteur([1 2 3])) - 1) < 1e-10));
if ok, passed++; else failed++; end

%% ââ Test 5 : distance_points ââââââââââââââââââââââââââââââââââââââââââââââ
ok = test_case('distance_points disponible', @() assert(abs(distance_points([0 0], [3 4]) - 5) < 1e-10));
if ok, passed++; else failed++; end

%% ââ Test 6 : distance_points symÃ©trique ââââââââââââââââââââââââââââââââââ
ok = test_case('distance_points symÃ©trie', @() ...
    assert(abs(distance_points([1 2], [4 6]) - distance_points([4 6], [1 2])) < 1e-10));
if ok, passed++; else failed++; end

%% ââ Test 7 : distance_points auto (un seul argument) ââââââââââââââââââââ
ok = test_case('distance_points auto D(i,j)=D(j,i)', @() ...
    assert(all(all(abs(distance_points([0 0; 1 0; 0 1]) - ...
                       distance_points([0 0; 1 0; 0 1])') < 1e-10))));
if ok, passed++; else failed++; end

%% ââ Test 8 : recherche_points_proche alias âââââââââââââââââââââââââââââââ
% Seulement si recherche_points_proche_v2 est disponible dans le dossier
if exist('recherche_points_proche_v2', 'file')
    ok = test_case('recherche_points_proche alias', @() ...
        assert(~isempty(which('recherche_points_proche'))));
    if ok, passed++; else failed++; end
else
    fprintf('  SKIP  recherche_points_proche (recherche_points_proche_v2 absent)\n');
end

%% ââ Bilan âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
fprintf('\n%d tests passÃ©s, %d Ã©chouÃ©s.\n', passed, failed);
if failed > 0
    error('Des tests de compatibilitÃ© ont Ã©chouÃ©.');
end
