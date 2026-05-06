# matlab-free-vscode

**Environnement MATLAB complet dans VS Code — sans licence MathWorks, sans abonnement.**

L'extension connecte VS Code à [GNU Octave](https://octave.org), un interpréteur MATLAB open-source, et lui greffe un serveur LSP maison : coloration syntaxique, complétion, hover, go-to-definition, et rendu des figures directement dans l'éditeur. Le code MATLAB scientifique standard tourne sans modification.

Compatible **VS Code ≥ 1.85** et **[Google Antigravity](https://antigravity.google)**.

---

## Ce que ça fait concrètement

Vous écrivez un fichier `.m` normal. Vous appuyez sur `Ctrl+Enter`. Octave exécute le code en arrière-plan et le résultat apparaît :

- Un `plot(x, sin(x))` ouvre un panneau SVG interactif à côté de l'éditeur, avec zoom molette et export SVG.
- Un `surf(peaks(30))` ouvre un panneau 3D Three.js : rotation libre, bascule perspective/orthographique, wireframe à la volée.
- Un `patch('Vertices', V, 'Faces', F, 'CData', C)` affiche un maillage coloré avec la colormap choisie et une colorbar optionnelle.
- L'autocomplétion (`.` ou `(`) interroge Octave en live via `completion_matches`.
- Survoler une fonction affiche sa doc Octave dans une infobulle.
- F12 sur un nom de fonction navigue vers le fichier source `.m` via `which`.

---

## Fonctionnalités

| Fonctionnalité | État |
|---|---|
| Coloration syntaxique `.m` complète | ✅ |
| Exécuter sélection / ligne (`Ctrl+Enter`) | ✅ |
| Exécuter tout le fichier (`Ctrl+Shift+Enter`) | ✅ |
| Figures 2D inline (plot, bar, scatter, histogram, imagesc) | ✅ |
| Figures 3D interactives (surf, mesh, patch, scatter3, plot3) | ✅ |
| Colormaps (jet, hot, gray, cool, viridis, parula) + colorbar | ✅ |
| Chargement VRML `.wrl` (maillages scannés, robots…) | ✅ |
| Éclairage 3D (camlight, lighting phong/flat/none) | ✅ |
| Complétion automatique | ✅ |
| Hover / doc inline | ✅ |
| Go-to-definition | ✅ |
| Diagnostics syntaxiques à la sauvegarde | ✅ |
| Correctifs compatibilité MATLAB→Octave automatiques | ✅ |
| Débogueur | ⚠️ via [vscOctaveDebugger](https://github.com/paulo-fernando-silva/vscOctaveDebugger) |
| Simulink / Toolboxes MathWorks propriétaires | ❌ |

---

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

Vérifiez l'installation : `octave --version` doit retourner quelque chose.

---

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
npm run package          # → génère matlab-free-vscode-x.x.x.vsix
```

Installez ensuite le `.vsix` généré comme décrit ci-dessus.

---

## Configuration

Par défaut, l'extension cherche `octave` dans le PATH système. Si Octave est installé à un endroit non standard, ajoutez dans votre `settings.json` :

```json
{
  "matlab-free.octavePath": "/usr/local/bin/octave"
}
```

Exemples courants :

| Système | Chemin typique |
|---|---|
| Windows (installeur officiel) | `C:\Program Files\GNU Octave\Octave-9.x.x\mingw64\bin\octave-cli.exe` |
| macOS (Homebrew) | `/opt/homebrew/bin/octave` |
| Linux (apt) | `/usr/bin/octave` |

---

## Utilisation

### Raccourcis clavier

| Action | Windows / Linux | macOS |
|---|---|---|
| Exécuter ligne ou sélection | `Ctrl+Enter` | `Cmd+Enter` |
| Exécuter tout le fichier | `Ctrl+Shift+Enter` | `Cmd+Shift+Enter` |
| Redémarrer la session Octave | `Ctrl+Shift+P` → *MATLAB: Redémarrer* | idem |

### Workflow typique

1. Ouvrez un dossier contenant vos fichiers `.m`
2. Ouvrez un fichier `.m` — Octave démarre automatiquement en arrière-plan
3. Placez le curseur sur une ligne et appuyez sur `Ctrl+Enter`
4. Le résultat s'affiche dans le terminal intégré ; les figures s'ouvrent dans des panneaux à droite

### Figures 2D

Les fonctions `plot`, `bar`, `histogram`, `scatter`, `imagesc`, `plot3`, `scatter3` génèrent une figure SVG dans un panneau dédié. Chaque numéro de figure (`figure(1)`, `figure(2)`…) correspond à un panneau distinct. Les panneaux se mettent à jour à chaque ré-exécution sans se fermer.

Contrôles disponibles dans le panneau figure :
- **Zoom +/-** : boutons ou `Ctrl+Molette`
- **Reset** : revient à la taille initiale
- **⬇ SVG** : télécharge la figure en SVG vectoriel

### Figures 3D

Les fonctions `surf`, `mesh` et `patch` ouvrent un panneau Three.js interactif.

| Geste | Effet |
|---|---|
| Clic + drag | Rotation |
| Scroll | Zoom |
| Shift + drag | Translation |
| Bouton *Wireframe* | Bascule l'affichage filaire |
| Bouton *Ortho* | Bascule perspective / orthographique |
| Bouton *Reset* | Recentre la caméra |

Exemple complet :

```matlab
[X, Y] = meshgrid(-3:0.15:3);
Z = sin(X) .* cos(Y);
colormap('viridis');
colorbar;
surf(X, Y, Z);
lighting('phong');
camlight;
```

### Colormaps disponibles

`jet` (défaut), `hot`, `cool`, `gray`, `viridis`, `parula`

---

## Compatibilité MATLAB → Octave

La grande majorité du code MATLAB scientifique fonctionne directement. Quelques différences à connaître :

| Construct | Statut |
|---|---|
| `textscan`, `regexp`, `strsplit`, `strtrim` | ✅ identique |
| `sparse`, `speye`, `svd`, `eig`, `fft` | ✅ identique |
| `norm2(A)` (minuscule) | ✅ alias créé automatiquement par l'extension |
| `norme_vecteur(A)` | ✅ fonction ajoutée automatiquement |
| `distance_points(A, B)` | ✅ fonction ajoutée automatiquement |
| `error(message('stats:...'))` | ⚠️ patché automatiquement dans `my_procrustes.m` si présent |
| `isstr` | ✅ alias de `ischar` dans Octave |
| Toolboxes MathWorks (Statistics, Signal…) | ❌ non disponibles |
| Simulink | ❌ non supporté |

L'extension applique ces correctifs au démarrage via `octave_compat.m`, sans toucher à vos fichiers sources.

---

## Architecture interne

```
matlab-free-vscode/
├── runtime/
│   ├── bootstrap.m        Surcharge plot/surf/patch/colormap/… → notifications JSON
│   ├── lsp_loop.m         Serveur LSP JSON-RPC (complétion, hover, définition, diagnostics)
│   ├── octave_compat.m    Correctifs compatibilité MATLAB→Octave (idempotent)
│   └── startup.m          Point d'entrée : charge bootstrap + lsp_loop
├── extension/
│   └── src/
│       ├── extension.ts      Activation VS Code, commandes, configuration
│       ├── OctaveSession.ts  Spawn Octave, pipe stdin/stdout, routage messages
│       ├── MsgParser.ts      Séparation flux LSP JSON-RPC / notifications __MFV__
│       ├── FigurePanel.ts    Webview figures 2D (SVG inline, zoom, export)
│       └── ThreeDPanel.ts    Webview 3D Three.js (patch, surf, VRML, OrbitControls)
└── .github/workflows/
    └── build-vsix.yml     CI : compile TypeScript + package VSIX + GitHub Release sur tag
```

### Protocole de communication MFV

Octave écrit sur stdout un flux mixte. `MsgParser.ts` le sépare en deux canaux :

```
Octave stdout
  ├── "Content-Length: N\r\n\r\n{...}"   → flux LSP JSON-RPC standard → IntelliSense
  └── "\n__MFV__{...}__MFV__\n"          → notifications visuelles → FigurePanel / ThreeDPanel
```

Le délimiteur `__MFV__` garantit qu'aucun contenu JSON-RPC ne peut être confondu avec une notification visuelle, même si le code utilisateur affiche du JSON.

---

## Contribuer

Les PRs sont bienvenues sur ces axes en priorité :

1. **`bootstrap.m`** : couvrir davantage de fonctions MATLAB (`contour`, `quiver`, `streamline`…)
2. **`lsp_loop.m`** : améliorer la précision des diagnostics et la résolution des symboles
3. **Tests** : suite de tests automatisés sur les fonctions interceptées
4. **Grammaire** : améliorer la coloration pour les classes MATLAB (`classdef`)

---

## Licence

MIT — voir [LICENSE](LICENSE)

## Crédits

- [mathworks/MATLAB-language-server](https://github.com/mathworks/MATLAB-language-server) — architecture LSP de référence
- [mathworks/MATLAB-extension-for-vscode](https://github.com/mathworks/MATLAB-extension-for-vscode) — base de l'extension officielle
- [Calysto/octave_kernel](https://github.com/Calysto/octave_kernel) — stratégie de capture SVG
- [K3D-tools/K3D-jupyter](https://github.com/K3D-tools/K3D-jupyter) — pipeline 3D WebGL
- [s-kajita/uOpenHRP](https://github.com/s-kajita/uOpenHRP) — pipeline VRML/patch
- [paulo-fernando-silva/vscOctaveDebugger](https://github.com/paulo-fernando-silva/vscOctaveDebugger) — protocole stdin/stdout Octave
- [Three.js](https://threejs.org) — rendu 3D WebGL
