/**
 * FigurePanel.ts — matlab-free-vscode
 * Panneau Webview pour l'affichage des figures 2D générées par Octave.
 * Les figures sont exportées en SVG via gnuplot et affichées inline.
 * Supporte : plot, bar, histogram, scatter, imagesc, contour, quiver, plot3, etc.
 */

import * as vscode from 'vscode'
import * as fs     from 'fs'

export class FigurePanel {
    /** Map handle Octave → panneau ouvert */
    static readonly panels = new Map<number, FigurePanel>()

    static show(handle: number, svgPath: string): void {
        handle = Number(handle)
        if (!Number.isFinite(handle)) handle = 1
        const col      = vscode.ViewColumn.Beside
        const existing = FigurePanel.panels.get(handle)

        if (existing) {
            existing.update(svgPath)
            existing.panel.reveal(col, true)
            return
        }

        const panel = vscode.window.createWebviewPanel(
            'mfvFigure',
            `Figure ${handle}`,
            col,
            {
                enableScripts:          true,
                retainContextWhenHidden: true,
                localResourceRoots:     [],
            }
        )

        const fp = new FigurePanel(panel, handle)
        fp.update(svgPath)
        FigurePanel.panels.set(handle, fp)
        panel.onDidDispose(() => FigurePanel.panels.delete(handle))
    }

    private constructor(
        private readonly panel: vscode.WebviewPanel,
        private readonly handle: number,
    ) {}

    update(svgPath: string): void {
        if (!fs.existsSync(svgPath)) return

        const svg = fs.readFileSync(svgPath, 'utf8')
            // Retire les déclarations XML et DOCTYPE pour l'inline
            .replace(/<\?xml[^>]*\?>/g, '')
            .replace(/<!DOCTYPE[^>]*>/g, '')
            .trim()

        this.panel.title   = `Figure ${this.handle}`
        this.panel.webview.html = this.buildHtml(svg, svgPath)
    }

    private buildHtml(svgContent: string, svgPath: string): string {
        const mtime = fs.statSync(svgPath).mtimeMs.toFixed(0)
        return /* html */`<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta http-equiv="Content-Security-Policy"
      content="default-src 'none';
               script-src 'unsafe-inline';
               style-src 'unsafe-inline';
               img-src data: blob:;">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box }
  body {
    background: #1e1e1e;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
    font-family: monospace;
  }
  #toolbar {
    position: fixed; top: 0; left: 0; right: 0;
    background: #2d2d2d; border-bottom: 1px solid #444;
    display: flex; align-items: center; gap: 8px;
    padding: 4px 10px; z-index: 10;
  }
  #toolbar button {
    background: #3c3c3c; border: 1px solid #555; color: #ccc;
    padding: 3px 10px; border-radius: 3px; cursor: pointer; font-size: 12px;
  }
  #toolbar button:hover { background: #4a4a4a }
  #toolbar span { color: #888; font-size: 11px; margin-left: auto }
  #fig-wrap {
    margin-top: 36px;
    padding: 12px;
    max-width: 100vw;
    overflow: auto;
  }
  #fig-wrap svg {
    max-width: 100%;
    height: auto;
    background: white;
    border-radius: 2px;
  }
  /* Zoom par transform */
  #fig-inner { transform-origin: top left; transition: transform 0.15s }
</style>
</head>
<body>
<div id="toolbar">
  <button onclick="zoom(1.2)">＋ Zoom</button>
  <button onclick="zoom(1/1.2)">－ Zoom</button>
  <button onclick="reset()">⟳ Reset</button>
  <button onclick="saveSvg()">⬇ SVG</button>
  <button onclick="savePng()">⬇ PNG</button>
  <span>Figure ${this.handle} — ${new Date(Number(mtime)).toLocaleTimeString()}</span>
</div>
<div id="fig-wrap">
  <div id="fig-inner">${svgContent}</div>
</div>

<script>
let scale = 1
const inner = document.getElementById('fig-inner')

function zoom(factor) {
  scale = Math.max(0.2, Math.min(8, scale * factor))
  inner.style.transform = \`scale(\${scale})\`
}
function reset() {
  scale = 1
  inner.style.transform = 'scale(1)'
}
function saveSvg() {
  const blob = new Blob([inner.innerHTML], {type:'image/svg+xml'})
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = 'figure_${this.handle}.svg'
  a.click()
}
function savePng() {
  const svgEl = inner.querySelector('svg')
  if (!svgEl) return
  const w = svgEl.viewBox?.baseVal?.width  || svgEl.clientWidth  || 800
  const h = svgEl.viewBox?.baseVal?.height || svgEl.clientHeight || 600
  const blob = new Blob([inner.innerHTML], {type:'image/svg+xml'})
  const url  = URL.createObjectURL(blob)
  const img  = new Image()
  img.onload = () => {
    const canvas  = document.createElement('canvas')
    canvas.width  = w * 2
    canvas.height = h * 2
    const ctx = canvas.getContext('2d')
    ctx.scale(2, 2)
    ctx.fillStyle = '#ffffff'
    ctx.fillRect(0, 0, w, h)
    ctx.drawImage(img, 0, 0, w, h)
    URL.revokeObjectURL(url)
    const a = document.createElement('a')
    a.download = 'figure_${this.handle}.png'
    a.href = canvas.toDataURL('image/png')
    a.click()
  }
  img.src = url
}

// Zoom molette
document.addEventListener('wheel', e => {
  if (e.ctrlKey) { e.preventDefault(); zoom(e.deltaY < 0 ? 1.1 : 1/1.1) }
}, { passive: false })

// Messages live depuis l'extension (mise à jour figure)
window.addEventListener('message', e => {
  if (e.data?.type === 'update' && e.data.svg) {
    inner.innerHTML = e.data.svg
  }
})
</script>
</body>
</html>`
    }

    /** Met à jour une figure existante sans recréer le panneau. */
    static refresh(handle: number, svgPath: string): void {
        const fp = FigurePanel.panels.get(handle)
        if (!fp) { FigurePanel.show(handle, svgPath); return }

        if (!fs.existsSync(svgPath)) return
        const svg = fs.readFileSync(svgPath, 'utf8')
            .replace(/<\?xml[^>]*\?>/g, '')
            .replace(/<!DOCTYPE[^>]*>/g, '')
            .trim()

        fp.panel.webview.postMessage({ type: 'update', svg })
    }
}
