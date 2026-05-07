/**
 * VariableExplorerPanel.ts — matlab-free-vscode
 * Panneau Webview affichant les variables du workspace Octave en temps réel.
 * Mis à jour après chaque exécution de code via le message MFV 'workspace'.
 */

import * as vscode from 'vscode'

export interface WorkspaceVar {
    name:  string
    class: string
    size:  string
    bytes: number
}

export class VariableExplorerPanel {
    private static instance: VariableExplorerPanel | null = null
    private readonly panel: vscode.WebviewPanel
    private vars: WorkspaceVar[] = []

    private constructor(panel: vscode.WebviewPanel) {
        this.panel = panel
        this.panel.onDidDispose(() => {
            VariableExplorerPanel.instance = null
        })
        this.render()
    }

    static show(): VariableExplorerPanel {
        if (VariableExplorerPanel.instance) {
            VariableExplorerPanel.instance.panel.reveal(vscode.ViewColumn.Two, true)
            return VariableExplorerPanel.instance
        }
        const panel = vscode.window.createWebviewPanel(
            'mfvVariableExplorer',
            'Variables Octave',
            { viewColumn: vscode.ViewColumn.Two, preserveFocus: true },
            {
                enableScripts:           true,
                retainContextWhenHidden: true,
                localResourceRoots:      [],
            }
        )
        VariableExplorerPanel.instance = new VariableExplorerPanel(panel)
        return VariableExplorerPanel.instance
    }

    /** Met à jour la liste des variables et rafraîchit l'affichage. */
    static update(vars: WorkspaceVar[]): void {
        if (!VariableExplorerPanel.instance) return
        VariableExplorerPanel.instance.vars = vars
        VariableExplorerPanel.instance.render()
    }

    /** Pousse une mise à jour sans reconstruire le HTML complet (postMessage). */
    static push(vars: WorkspaceVar[]): void {
        if (!VariableExplorerPanel.instance) {
            // Crée le panneau si pas encore ouvert
            VariableExplorerPanel.show()
        }
        VariableExplorerPanel.instance!.vars = vars
        VariableExplorerPanel.instance!.panel.webview.postMessage({ type: 'update', vars })
    }

    private render(): void {
        this.panel.webview.html = this.buildHtml()
    }

    private buildHtml(): string {
        const rowsJson = JSON.stringify(this.vars)
        return /* html */`<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta http-equiv="Content-Security-Policy"
      content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline';">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: var(--vscode-font-family, 'Segoe UI', monospace);
    font-size: 12px;
    background: var(--vscode-editor-background, #1e1e1e);
    color: var(--vscode-editor-foreground, #d4d4d4);
  }
  #toolbar {
    position: sticky; top: 0;
    background: var(--vscode-sideBar-background, #252526);
    border-bottom: 1px solid var(--vscode-widget-border, #444);
    padding: 6px 10px;
    display: flex; align-items: center; gap: 8px;
  }
  #search {
    flex: 1;
    background: var(--vscode-input-background, #3c3c3c);
    border: 1px solid var(--vscode-input-border, #555);
    color: var(--vscode-input-foreground, #ccc);
    padding: 3px 7px; border-radius: 3px; font-size: 12px;
  }
  #count {
    color: var(--vscode-descriptionForeground, #888);
    font-size: 11px; white-space: nowrap;
  }
  table {
    width: 100%; border-collapse: collapse;
  }
  thead th {
    position: sticky; top: 37px;
    background: var(--vscode-sideBar-background, #252526);
    border-bottom: 1px solid var(--vscode-widget-border, #444);
    padding: 5px 8px; text-align: left;
    font-weight: 600; font-size: 11px; text-transform: uppercase;
    color: var(--vscode-descriptionForeground, #888);
    cursor: pointer; user-select: none;
  }
  thead th:hover { color: var(--vscode-editor-foreground, #ccc); }
  thead th.sort-asc::after  { content: ' ▲'; }
  thead th.sort-desc::after { content: ' ▼'; }
  tbody tr:hover {
    background: var(--vscode-list-hoverBackground, #2a2d2e);
  }
  tbody tr.alt {
    background: var(--vscode-list-inactiveSelectionBackground, #1e1e1e);
  }
  td {
    padding: 4px 8px;
    border-bottom: 1px solid var(--vscode-widget-border, #2d2d2d);
    font-family: var(--vscode-editor-font-family, 'Consolas', monospace);
    white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 200px;
  }
  td.name  { color: var(--vscode-symbolIcon-variableForeground, #9cdcfe); font-weight: 600; }
  td.class { color: var(--vscode-symbolIcon-classForeground,    #4ec9b0); }
  td.size  { color: var(--vscode-descriptionForeground, #888); }
  td.bytes { color: var(--vscode-descriptionForeground, #888); text-align: right; }
  #empty {
    padding: 30px; text-align: center;
    color: var(--vscode-descriptionForeground, #555);
  }
</style>
</head>
<body>
<div id="toolbar">
  <input id="search" type="text" placeholder="Filtrer…" oninput="filter()">
  <span id="count">0 variables</span>
</div>
<table id="tbl">
  <thead>
    <tr>
      <th onclick="sort('name')"  class="sort-asc">Nom</th>
      <th onclick="sort('class')">Type</th>
      <th onclick="sort('size')">Taille</th>
      <th onclick="sort('bytes')">Octets</th>
    </tr>
  </thead>
  <tbody id="body"></tbody>
</table>
<div id="empty" style="display:none">Aucune variable dans le workspace.</div>

<script>
let allVars = ${rowsJson}
let sortKey = 'name'
let sortDir = 1   // 1 = asc, -1 = desc

function fmtBytes(n) {
  if (n < 1024)       return n + ' B'
  if (n < 1048576)    return (n/1024).toFixed(1) + ' KB'
  return (n/1048576).toFixed(1) + ' MB'
}

function render(vars) {
  const q    = document.getElementById('search').value.toLowerCase()
  const rows = vars
    .filter(v => v.name.toLowerCase().includes(q) ||
                 v.class.toLowerCase().includes(q))
    .sort((a,b) => {
      const va = String(a[sortKey]), vb = String(b[sortKey])
      return sortDir * va.localeCompare(vb, undefined, {numeric:true})
    })

  const body = document.getElementById('body')
  if (rows.length === 0) {
    body.innerHTML = ''
    document.getElementById('empty').style.display = 'block'
  } else {
    document.getElementById('empty').style.display = 'none'
    body.innerHTML = rows.map((v,i) => \`
      <tr class="\${i%2===0?'alt':''}">
        <td class="name">\${v.name}</td>
        <td class="class">\${v.class}</td>
        <td class="size">\${v.size}</td>
        <td class="bytes">\${fmtBytes(v.bytes)}</td>
      </tr>
    \`).join('')
  }
  document.getElementById('count').textContent = rows.length + ' variable' + (rows.length!==1?'s':'')
}

function filter() { render(allVars) }

function sort(key) {
  if (sortKey === key) { sortDir *= -1 }
  else { sortKey = key; sortDir = 1 }
  document.querySelectorAll('thead th').forEach(th => {
    th.classList.remove('sort-asc','sort-desc')
  })
  const cols = ['name','class','size','bytes']
  const idx  = cols.indexOf(key)
  const th   = document.querySelectorAll('thead th')[idx]
  th.classList.add(sortDir === 1 ? 'sort-asc' : 'sort-desc')
  render(allVars)
}

// Mise à jour live via postMessage depuis OctaveSession
window.addEventListener('message', e => {
  if (e.data?.type === 'update' && e.data.vars) {
    allVars = e.data.vars
    render(allVars)
  }
})

render(allVars)
</script>
</body>
</html>`
    }
}
