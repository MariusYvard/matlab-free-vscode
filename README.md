# matlab-free-vscode

> Code MATLAB/Octave gratuitement dans VS Code et Google Antigravity — zéro licence, zéro installation MATLAB.

## Fonctionnalités

| Fonctionnalité | Détail |
|---|---|
| Syntaxe MATLAB | Coloration, auto-indent, folding |
| IntelliSense | Complétion, hover, go-to-definition via Octave |
| Diagnostics | Erreurs de syntaxe à la sauvegarde |
| Figures 2D | plot, bar, scatter → SVG inline |
| Figures 3D | patch, surf, VRML → Three.js interactif |
| Exécution | Ctrl+Enter (sélection), Ctrl+Shift+Enter (fichier) |

## Prérequis

- [GNU Octave ≥ 7.0](https://octave.org/download) — gratuit, open-source
- VS Code ≥ 1.85 ou Google Antigravity

## Installation

1. Téléchargez le `.vsix` depuis [Releases](https://github.com/MariusYvard/matlab-free-vscode/releases)
2. `Ctrl+Shift+P` → **Extensions: Install from VSIX**
3. Si Octave n'est pas dans votre PATH : `matlab-free.octavePath` dans les settings

## Build depuis les sources

```bash
git clone https://github.com/MariusYvard/matlab-free-vscode
cd matlab-free-vscode/extension
npm install
npm run compile
mkdir runtime && cp -r ../runtime/* runtime/
npm run package   # génère matlab-free-vscode-0.1.0.vsix
```

## Architecture

```
Octave (--no-gui)
  └─ stdout ──► MsgParser.ts ──► LSP → vscode-languageclient (IntelliSense)
                              └► MFV → FigurePanel (SVG) / ThreeDPanel (Three.js)
  └─ stdin  ◄── lspIn (PassThrough) ◄── LanguageClient
```

## Licence

MIT — © 2026 matlab-free-vscode contributors
