<p align="center">
  <img src="https://img.shields.io/visual-studio-marketplace/v/MariusYvard.matlab-free-vscode?color=0078d7&label=VS%20Code%20Marketplace" alt="version">
  <img src="https://img.shields.io/github/license/MariusYvard/matlab-free-vscode?color=green" alt="license">
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-blue" alt="platform">
  <img src="https://img.shields.io/badge/engine-GNU%20Octave%20%E2%89%A57.0-orange" alt="octave">
</p>

# matlab-free-vscode

**Full MATLAB environment in VS Code — no MathWorks license, no subscription.**

> *[🇫🇷 Version française ci-dessous](#version-française)*

This extension connects VS Code (and [Google Antigravity](https://antigravity.google)) to [GNU Octave](https://octave.org), an open-source MATLAB-compatible interpreter, and adds a built-in LSP server: syntax highlighting, autocompletion, hover docs, go-to-definition, and **inline figure rendering** — all directly inside the editor. Standard scientific MATLAB code runs without modification.

---

## ✨ What it does

Write a normal `.m` file. Press `Ctrl+Enter`. Octave executes in the background and results appear:

- **`plot(x, sin(x))`** opens an interactive SVG panel with zoom and SVG/PNG export
- **`surf(peaks(30))`** opens a 3D Three.js panel with orbit controls, wireframe toggle, and orthographic projection
- **`patch('Vertices', V, 'Faces', F, 'CData', C)`** renders a colored mesh with colormaps and colorbar
- **Autocompletion** queries Octave live via `completion_matches` — built-in functions, struct fields, workspace variables, and user `.m` files
- **Hover** shows Octave documentation in a tooltip
- **F12** navigates to source `.m` files via `which`
- **Variable Explorer** shows workspace variables in real time after each execution

---

## 📋 Features

| Feature | Status |
|---|---|
| Full `.m` syntax highlighting | ✅ |
| Run selection / line (`Ctrl+Enter`) | ✅ |
| Run entire file (`Ctrl+Shift+Enter`) | ✅ |
| 2D inline figures (plot, bar, scatter, histogram, imagesc, contour, quiver…) | ✅ |
| Interactive 3D figures (surf, mesh, patch, scatter3, plot3) | ✅ |
| Colormaps (jet, hot, gray, cool, viridis, parula) + colorbar | ✅ |
| VRML `.wrl` loading (scanned meshes, robots…) | ✅ |
| 3D lighting (camlight, lighting phong/flat/none) | ✅ |
| Autocompletion (built-in + struct fields + user functions) | ✅ |
| Signature Help (function parameter hints) | ✅ |
| Hover / inline documentation | ✅ |
| Go-to-definition | ✅ |
| Syntax diagnostics on save | ✅ |
| MATLAB → Octave compatibility patches | ✅ |
| Variable Explorer (real-time workspace) | ✅ |
| Auto-detect Octave on Windows | ✅ |
| Debugger | ⚠️ via [vscOctaveDebugger](https://github.com/paulo-fernando-silva/vscOctaveDebugger) |
| Simulink / proprietary MathWorks Toolboxes | ❌ |

---

## 🔧 Prerequisites

**GNU Octave ≥ 7.0** must be installed.

```bash
# Windows
winget install GNU.Octave

# macOS
brew install octave

# Ubuntu / Debian
sudo apt install octave
```

> **Windows users:** The extension auto-detects Octave in standard installation paths (`C:\Program Files\GNU Octave`, `C:\Octave`, etc.). No manual configuration needed in most cases.

Verify: `octave --version` should return something.

---

## 📦 Installation

### Option A — Pre-built VSIX (recommended)

1. Go to the [Releases](https://github.com/MariusYvard/matlab-free-vscode/releases) page
2. Download `matlab-free-vscode-x.x.x.vsix`
3. In VS Code or Antigravity: `Ctrl+Shift+P` → **Extensions: Install from VSIX** → select the file
4. Restart the editor if prompted

### Option B — From source

```bash
git clone https://github.com/MariusYvard/matlab-free-vscode.git
cd matlab-free-vscode/extension
npm install
npm run compile
npm run package          # → generates matlab-free-vscode-x.x.x.vsix
```

Then install the generated `.vsix` as described above.

---

## ⚙️ Configuration

By default, the extension searches for `octave` in the system PATH and common Windows installation directories. If Octave is installed in a non-standard location, add to your `settings.json`:

```json
{
  "matlab-free.octavePath": "/usr/local/bin/octave"
}
```

Common paths:

| System | Typical path |
|---|---|
| Windows (official installer) | `C:\Program Files\GNU Octave\Octave-9.x.x\mingw64\bin\octave-cli.exe` |
| macOS (Homebrew) | `/opt/homebrew/bin/octave` |
| Linux (apt) | `/usr/bin/octave` |

| Setting | Type | Default | Description |
|---|---|---|---|
| `matlab-free.octavePath` | `string` | `"octave"` | Path to the Octave binary |
| `matlab-free.showFiguresInWebview` | `boolean` | `true` | Show figures in integrated Webview panels |
| `matlab-free.defaultColormap` | `string` | `"jet"` | Default colormap for 3D figures |
| `matlab-free.extraPath` | `string[]` | `[]` | Additional folders added to Octave's path at startup |

---

## 🚀 Usage

### Keyboard shortcuts

| Action | Windows / Linux | macOS |
|---|---|---|
| Run line or selection | `Ctrl+Enter` | `Cmd+Enter` |
| Run entire file | `Ctrl+Shift+Enter` | `Cmd+Shift+Enter` |
| Restart Octave session | `Ctrl+Shift+P` → *MATLAB: Restart* | same |
| Show Variable Explorer | `Ctrl+Shift+P` → *MATLAB: Variable Explorer* | same |
| Clear workspace | `Ctrl+Shift+P` → *MATLAB: Clear workspace* | same |

### Typical workflow

1. Open a folder containing your `.m` files
2. Open a `.m` file — Octave starts automatically in the background
3. Place your cursor on a line and press `Ctrl+Enter`
4. Output appears in the integrated terminal; figures open in panels on the right

### 2D Figures

Functions like `plot`, `bar`, `histogram`, `scatter`, `imagesc`, `contour`, `quiver`, `stem`, `stairs`, `errorbar`, `pie`, `semilogy`, `semilogx`, `loglog`, `plot3`, `scatter3` generate an SVG figure in a dedicated panel. Each figure number (`figure(1)`, `figure(2)`…) maps to a distinct panel. Panels update on re-execution without closing.

Controls:
- **Zoom +/-**: buttons or `Ctrl+Scroll`
- **Reset**: returns to initial size
- **⬇ SVG**: download as vector SVG
- **⬇ PNG**: download as high-DPI PNG

### 3D Figures

`surf`, `mesh`, and `patch` open an interactive Three.js panel.

| Gesture | Effect |
|---|---|
| Click + drag | Rotation |
| Scroll | Zoom |
| Shift + drag | Pan |
| *Wireframe* button | Toggle wireframe |
| *Ortho* button | Toggle perspective / orthographic |
| *Reset* button | Re-center camera |
| *PNG* button | Export screenshot |
| *Full* button | Fullscreen mode |

Example:

```matlab
[X, Y] = meshgrid(-3:0.15:3);
Z = sin(X) .* cos(Y);
colormap('viridis');
colorbar;
surf(X, Y, Z);
lighting('phong');
camlight;
```

### Available colormaps

`jet` (default), `hot`, `cool`, `gray`, `viridis`, `parula`

---

## 🔄 MATLAB → Octave Compatibility

The vast majority of scientific MATLAB code works directly. Key differences:

| Construct | Status |
|---|---|
| `textscan`, `regexp`, `strsplit`, `strtrim` | ✅ identical |
| `sparse`, `speye`, `svd`, `eig`, `fft` | ✅ identical |
| `norm2(A)` (lowercase) | ✅ auto-aliased by extension |
| `norme_vecteur(A)` | ✅ auto-generated |
| `distance_points(A, B)` | ✅ auto-generated |
| `error(message('stats:...'))` | ⚠️ auto-patched if present |
| `isstr` | ✅ alias of `ischar` in Octave |
| MathWorks Toolboxes (Statistics, Signal…) | ❌ not available |
| Simulink | ❌ not supported |

Patches are applied at startup via `octave_compat.m` — your source files are never modified.

---

## 🏗️ Architecture

```
matlab-free-vscode/
├── runtime/
│   ├── bootstrap.m          Overrides plot/surf/patch/colormap/… → JSON notifications
│   ├── lsp_loop.m           LSP JSON-RPC server (completion, hover, definition, diagnostics)
│   ├── octave_compat.m      MATLAB → Octave compatibility patches (idempotent)
│   └── startup.m            Entry point: loads bootstrap + lsp_loop
├── extension/
│   └── src/
│       ├── extension.ts      VS Code activation, commands, configuration
│       ├── OctaveSession.ts   Spawns Octave, pipes stdin/stdout, routes messages
│       ├── MsgParser.ts       Separates LSP JSON-RPC / __MFV__ notification streams
│       ├── FigurePanel.ts     2D figure Webview (inline SVG, zoom, export)
│       ├── ThreeDPanel.ts     3D Webview (Three.js, patch, surf, VRML, OrbitControls)
│       └── VariableExplorerPanel.ts   Real-time workspace variable table
├── test/
│   ├── test_compat.m         Compatibility function tests
│   └── test_figures.m        Figure interception tests
└── .github/workflows/
    └── build-vsix.yml        CI: compile TypeScript + package VSIX + GitHub Release on tag
```

### MFV Communication Protocol

Octave writes to stdout a mixed stream. `MsgParser.ts` splits it into two channels:

```
Octave stdout
  ├── "Content-Length: N\r\n\r\n{...}"   → standard LSP JSON-RPC → IntelliSense
  └── "\n__MFV__{...}__MFV__\n"          → visual notifications → FigurePanel / ThreeDPanel
```

The `__MFV__` delimiter ensures that no JSON-RPC content can be confused with a visual notification, even if user code prints JSON.

---

## 🤝 Contributing

PRs are welcome — priority areas:

1. **`bootstrap.m`**: cover more MATLAB functions (`streamline`, `pcolor`, `ribbon`…)
2. **`lsp_loop.m`**: improve diagnostic precision and symbol resolution
3. **Tests**: expand automated test suites
4. **Grammar**: improve syntax highlighting for `classdef` MATLAB classes
5. **Debugger**: deeper integration with vscOctaveDebugger

---

## 📄 License

MIT — see [LICENSE](LICENSE)

---

## 🙏 Credits

- [GNU Octave](https://octave.org) — open-source MATLAB-compatible interpreter
- [Three.js](https://threejs.org) — WebGL 3D rendering
- [mathworks/MATLAB-language-server](https://github.com/mathworks/MATLAB-language-server) — LSP architecture reference
- [Calysto/octave_kernel](https://github.com/Calysto/octave_kernel) — SVG capture strategy
- [paulo-fernando-silva/vscOctaveDebugger](https://github.com/paulo-fernando-silva/vscOctaveDebugger) — Octave stdin/stdout protocol

---

---

# Version française

**Environnement MATLAB complet dans VS Code — sans licence MathWorks, sans abonnement.**

L'extension connecte VS Code à [GNU Octave](https://octave.org), un interpréteur MATLAB open-source, et lui greffe un serveur LSP maison : coloration syntaxique, complétion, hover, go-to-definition, et rendu des figures directement dans l'éditeur. Le code MATLAB scientifique standard tourne sans modification.

Compatible **VS Code ≥ 1.85** et **[Google Antigravity](https://antigravity.google)**.

## Ce que ça fait concrètement

Vous écrivez un fichier `.m` normal. Vous appuyez sur `Ctrl+Enter`. Octave exécute le code en arrière-plan et le résultat apparaît :

- Un `plot(x, sin(x))` ouvre un panneau SVG interactif à côté de l'éditeur, avec zoom molette et export SVG/PNG.
- Un `surf(peaks(30))` ouvre un panneau 3D Three.js : rotation libre, bascule perspective/orthographique, wireframe à la volée.
- Un `patch('Vertices', V, 'Faces', F, 'CData', C)` affiche un maillage coloré avec la colormap choisie et une colorbar optionnelle.
- L'autocomplétion (`.` ou `(`) interroge Octave en live via `completion_matches`.
- Survoler une fonction affiche sa doc Octave dans une infobulle.
- F12 sur un nom de fonction navigue vers le fichier source `.m` via `which`.
- Le **Variable Explorer** affiche les variables du workspace en temps réel.

## Prérequis

**GNU Octave ≥ 7.0** doit être installé et accessible dans le PATH.

```bash
# Windows
winget install GNU.Octave

# macOS
brew install octave

# Ubuntu / Debian
sudo apt install octave
```

> **Utilisateurs Windows :** L'extension détecte automatiquement Octave dans les chemins d'installation courants (`C:\Program Files\GNU Octave`, `C:\Octave`, etc.). Aucune configuration manuelle n'est nécessaire dans la plupart des cas.

## Installation

### Option A — VSIX pré-compilé (recommandé)

1. Allez sur la page [Releases](https://github.com/MariusYvard/matlab-free-vscode/releases)
2. Téléchargez le fichier `matlab-free-vscode-x.x.x.vsix`
3. Dans VS Code ou Antigravity : `Ctrl+Shift+P` → **Extensions: Install from VSIX** → sélectionnez le fichier
4. Redémarrez l'éditeur si demandé

### Option B — Depuis les sources

```bash
git clone https://github.com/MariusYvard/matlab-free-vscode.git
cd matlab-free-vscode/extension
npm install
npm run compile
npm run package
```

## Raccourcis clavier

| Action | Windows / Linux | macOS |
|---|---|---|
| Exécuter ligne ou sélection | `Ctrl+Enter` | `Cmd+Enter` |
| Exécuter tout le fichier | `Ctrl+Shift+Enter` | `Cmd+Shift+Enter` |
| Redémarrer la session Octave | `Ctrl+Shift+P` → *MATLAB: Redémarrer* | idem |

## Licence

MIT — voir [LICENSE](LICENSE)
