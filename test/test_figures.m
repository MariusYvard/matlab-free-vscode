%% test_figures.m — matlab-free-vscode
%  Verifie que les fonctions de visualisation interceptees par bootstrap.m
%  emettent bien une notification MFV sur stdout.
%  Usage : octave --no-gui --eval "run('test/test_figures.m')"
%  Retour : 0 (succes) ou erreur

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

%% -- Test 1 : plot generates an MFV notification --------------------------
try
    x = 0:0.1:2*pi;
    plot(x, sin(x));
    fprintf('  PASS  plot() intercepted\n');
    passed++;
catch e
    fprintf('  FAIL  plot(): %s\n', e.message);
    failed++;
end

%% -- Test 2 : bar chart ---------------------------------------------------
try
    bar([1 3 2 4]);
    fprintf('  PASS  bar() intercepted\n');
    passed++;
catch e
    fprintf('  FAIL  bar(): %s\n', e.message);
    failed++;
end

%% -- Test 3 : contour ------------------------------------------------------
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

%% -- Test 4 : quiver -------------------------------------------------------
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

%% -- Test 5 : surf ---------------------------------------------------------
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

%% -- Test 6 : scatter ------------------------------------------------------
try
    scatter(rand(20,1), rand(20,1));
    fprintf('  PASS  scatter() intercepted\n');
    passed++;
catch e
    fprintf('  FAIL  scatter(): %s\n', e.message);
    failed++;
end

%% -- Test 7 : imagesc ------------------------------------------------------
try
    imagesc(magic(5));
    fprintf('  PASS  imagesc() intercepted\n');
    passed++;
catch e
    fprintf('  FAIL  imagesc(): %s\n', e.message);
    failed++;
end

%% -- Summary ---------------------------------------------------------------
fprintf('\n%d tests passed, %d failed.\n', passed, failed);
if failed > 0
    error('Some tests failed.');
end
