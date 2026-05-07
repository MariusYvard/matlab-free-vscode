# Changelog

All notable changes to **matlab-free-vscode** are documented here.

## [0.3.1] — 2026-05-07

### 🔧 Fixed
- **Missing dependencies**: fixed a critical bug where `node_modules` were omitted from the VSIX package due to a misconfigured build script (`--no-dependencies`). This was causing the extension to fail to activate with the error `Cannot find module 'vscode-languageclient/node'`.

## [0.3.0] — 2026-05-07

### 🔧 Fixed
- **Windows Octave detection**: now scans `C:\Octave`, `%LOCALAPPDATA%\Programs`, and both `mingw64\bin` and `ucrt64\bin` subdirectories
- **LSP hardcoded paths**: hover, signature help, and diagnostics no longer silently fail when `octave` is not in the system PATH — the extension now injects the resolved binary path via `MFV_OCTAVE_BIN`
- **Corrupted `bootstrap.m`**: removed 1470 null bytes at end of file
- **Test file encoding**: fixed broken UTF-8 characters in `test_compat.m` and `test_figures.m`

### 📝 Changed
- **README.md**: complete rewrite — bilingual EN/FR, professional badges, comprehensive feature docs, full settings table, architecture diagram
- **`package.json`**: bilingual description, expanded keywords for marketplace discoverability
- **CI release notes**: now version-agnostic with bilingual installation instructions

## [0.2.0] — 2026-05-01

### ✨ Added
- Variable Explorer: real-time workspace variable panel
- PNG export in both 2D and 3D figure panels
- Fullscreen mode for 3D figures
- New 2D plot intercepts: `contour`, `contourf`, `quiver`, `quiver3`, `semilogy`, `semilogx`, `loglog`, `stem`, `stairs`, `errorbar`, `pie`
- Signature Help (function parameter hints in real time)
- Struct field completion and user `.m` function completion
- Auto-detection of Octave on Windows
- Dedicated output channel for Octave stdout/stderr

## [0.1.0] — 2026-04-15

### ✨ Initial Release
- Syntax highlighting for `.m` files
- Run selection (`Ctrl+Enter`) and run file (`Ctrl+Shift+Enter`)
- 2D inline SVG figures (plot, bar, scatter, histogram, imagesc)
- 3D interactive Three.js figures (surf, mesh, patch)
- Colormaps (jet, hot, cool, gray, viridis, parula) + colorbar
- VRML `.wrl` loading
- 3D lighting (camlight, lighting)
- LSP autocompletion, hover, go-to-definition
- Syntax diagnostics on save
- MATLAB → Octave compatibility patches
