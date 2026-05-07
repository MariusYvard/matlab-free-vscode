%% test_figures.m â matlab-free-vscode
%  VÃ©rifie que les fonctions de visualisation interceptÃ©es par bootstrap.m
%  Ã©mettent bien une notification MFV sur stdout.
%  Usage : octave --no-gui --eval "run('test/test_figures.m')"
%  Retour : 0 (succÃ¨s) ou erreur

addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'runtime'));
run(fullfile(fileparts(mfilename('fullpath')), '..', 'runtime', 'startup.m'));

passed = 0;
failed = 0;

function assert_eq(name, a, b)
    if isequal(a, b)
        fprintf('  PASS  %s\n', name);
    else
        fprintf('  FAIL  %s  (got %s, expected %s)\n', name, num2str(a), num2str(b));
        error('Test failed: %s', name);
    end
end

%% ââ Test 1 : plot gÃ©nÃ¨re une notification MFV ââââââââââââââââââââââââââââ
try
    x = 0:0.1:2*pi;
    plot(x, sin(x));
    fprintf('  PASS  plot() intercepted\n');
    passed++;
catch e
    fprintf('  FAIL  plot(): %s\n', e.message);
    failed++;
end

%% ââ Test 2 : bar chart âââââââââââââââââââââââââââââââââââââââââââââââââââ
try
    bar([1 3 2 4]);
    fprintf('  PASS  bar() intercepted\n');
    passed++;
catch e
    fprintf('  FAIL  bar(): %s\n', e.message);
    failed++;
end

%% ââ Test 3 : contour âââââââââââââââââââââââââââââââââââââââââââââââââââââ
try
    [X, Y] = meshgrid(-2:0.2:2);
    Z = X.^2 + Y.^2;
    contour(X, Y, Z);
    fprintf('  PASS  contour() intercepted\n');
    passed++;
catch e
    fprintf('  FAIL  contour(): %s\n', e.message);
    failed++;
end

%% ââ Test 4 : quiver ââââââââââââââââââââââââââââââââââââââââââââââââââââââ
try
    [X, Y] = meshgrid(0:0.5:2);
    U = -Y; V = X;
    quiver(X, Y, U, V);
    fprintf('  PASS  quiver() intercepted\n');
    passed++;
catch e
    fprintf('  FAIL  quiver(): %s\n', e.message);
    failed++;
end

%% ââ Test 5 : surf ââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
try
    [X, Y] = meshgrid(-2:0.3:2);
    Z = sin(X) .* cos(Y);
    surf(X, Y, Z);
    fprintf('  PASS  surf() intercepted\n');
    passed++;
catch e
    fprintf('  FAIL  surf(): %s\n', e.message);
    failed++;
end

%% ââ Test 6 : scatter âââââââââââââââââââââââââââââââââââââââââââââââââââââ
try
    scatter(rand(20,1), rand(20,1));
    fprintf('  PASS  scatter() intercepted\n');
    passed++;
catch e
    fprintf('  FAIL  scatter(): %s\n', e.message);
    failed++;
end

%% ââ Test 7 : imagesc âââââââââââââââââââââââââââââââââââââââââââââââââââââ
try
    imagesc(magic(5));
    fprintf('  PASS  imagesc() intercepted\n');
    passed++;
catch e
    fprintf('  FAIL  imagesc(): %s\n', e.message);
    failed++;
end

%% ââ Bilan âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
fprintf('\n%d tests passÃ©s, %d Ã©chouÃ©s.\n', passed, failed);
if failed > 0
    error('Des tests ont Ã©chouÃ©.');
end
