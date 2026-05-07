/**
 * OctaveSession.ts — matlab-free-vscode
 * Démarre Octave, charge le runtime, sépare le flux LSP / MFV,
 * et expose les streams attendus par vscode-languageclient.
 */

import * as vscode  from 'vscode'
import * as cp      from 'child_process'
import * as path    from 'path'
import * as fs      from 'fs'
import { PassThrough } from 'stream'
import { MsgParser, MfvMessage } from './MsgParser'
import { FigurePanel }           from './FigurePanel'
import { ThreeDPanel }           from './ThreeDPanel'
import { VariableExplorerPanel } from './VariableExplorerPanel'

export class OctaveSession implements vscode.Disposable {
    private proc:    cp.ChildProcess | null = null
    private parser:  MsgParser
    private outCh:   vscode.OutputChannel

    /** Stream LSP lu par vscode-languageclient (stdout filtré d'Octave) */
    public lspOut = new PassThrough()
    /** Stream LSP écrit par vscode-languageclient → stdin Octave */
    public lspIn  = new PassThrough()

    constructor(private readonly ctx: vscode.ExtensionContext) {
        this.parser = new MsgParser()
        this.outCh  = vscode.window.createOutputChannel('Octave', { log: false } as any)
    }

    async start(): Promise<boolean> {
        const cfg        = vscode.workspace.getConfiguration('matlab-free')
        let   octavePath = cfg.get<string>('octavePath', 'octave')
        const extraPaths = cfg.get<string[]>('extraPath', [])
        const runtimeDir = path.join(this.ctx.extensionPath, 'runtime')

        // ── Auto-détection d'Octave sur Windows ───────────────────────────
        if (octavePath === 'octave' && process.platform === 'win32') {
            const detected = OctaveSession.detectOctaveWindows()
            if (detected) {
                octavePath = detected
                this.log(`[matlab-free] Octave détecté automatiquement : ${detected}\n`)
            }
        }

        const startupM = path.join(runtimeDir, 'startup.m').replace(/\\/g, '/')
        const lspLoopM = path.join(runtimeDir, 'lsp_loop.m').replace(/\\/g, '/')

        if (!fs.existsSync(startupM)) {
            vscode.window.showErrorMessage(
                `matlab-free: runtime introuvable dans "${runtimeDir}". ` +
                'Réinstallez l\'extension.')
            return false
        }

        const addpaths = [runtimeDir, ...extraPaths]
            .map(p => `addpath('${p.replace(/\\/g, '/')}');`)
            .join(' ')

        const initScript = [
            addpaths,
            `run('${startupM}');`,
            `source('${lspLoopM}');`,
            `__mfv_lsp_loop__();`,
        ].join(' ')

        this.proc = cp.spawn(octavePath, [
            '--no-gui',
            '--no-line-editing',
            '--quiet',
            '--no-history',
            '--eval', initScript,
        ], {
            stdio: ['pipe', 'pipe', 'pipe'],
            env:   { ...process.env, OCTAVE_HISTFILE: '/dev/null' },
        })

        if (!this.proc.pid) {
            vscode.window.showErrorMessage(
                `matlab-free: impossible de démarrer Octave à "${octavePath}". ` +
                'Vérifiez le paramètre matlab-free.octavePath dans les settings.')
            return false
        }

        // ── Routage stdout ────────────────────────────────────────────────
        this.proc.stdout!.on('data', (chunk: Buffer) => this.parser.feed(chunk))

        this.parser.on('lsp',  (data: Buffer)    => this.lspOut.write(data))
        this.parser.on('mfv',  (msg: MfvMessage) => this.dispatch(msg))
        this.parser.on('text', (txt: string)     => this.logOutput(txt))

        // ── stdin LSP → Octave ────────────────────────────────────────────
        this.lspIn.on('data', (chunk: Buffer) => {
            this.proc?.stdin?.writable && this.proc.stdin.write(chunk)
        })

        // ── Stderr → output channel ───────────────────────────────────────
        this.proc.stderr!.on('data', (d: Buffer) => this.logError(d.toString()))

        this.proc.on('exit', code => {
            if (code !== 0) {
                this.logError(`\n[matlab-free] Octave arrêté (code ${code})\n`)
                vscode.window.showWarningMessage(
                    `matlab-free: Octave s'est arrêté (code ${code}). ` +
                    'Utilisez "MATLAB: Redémarrer" pour relancer.')
            }
        })

        return true
    }

    /** Exécute une commande arbitraire dans la session Octave. */
    sendCommand(code: string): void {
        if (!this.proc?.stdin?.writable) return
        const req = JSON.stringify({
            jsonrpc: '2.0',
            method:  'octave/runCode',
            params:  { code },
        })
        const header = `Content-Length: ${Buffer.byteLength(req)}\r\n\r\n`
        this.proc.stdin.write(header + req)
    }

    private dispatch(msg: MfvMessage): void {
        switch (msg.type) {
            case 'figure':
                FigurePanel.show(msg.handle ?? 1, msg.path)
                break
            case 'patch':
            case 'surf':
            case '3d':
                ThreeDPanel.show(`fig_${Date.now()}`, msg as any)
                break
            case 'colormap':
            case 'colorbar':
            case 'camlight':
            case 'lighting':
                ThreeDPanel.broadcast(msg)
                break
            case 'title':
                ThreeDPanel.setTitle(msg.text ?? '')
                break
            case 'workspace':
                // Mise à jour du Variable Explorer (push = non-bloquant)
                VariableExplorerPanel.push(msg.vars ?? [])
                break
            case 'error':
                this.logError(`[Octave] ${msg.message}\n`)
                vscode.window.showErrorMessage(`Octave: ${msg.message}`)
                break
        }
    }

    /** Affiche la sortie standard Octave (disp, fprintf…) dans l'output channel. */
    private logOutput(text: string): void {
        if (text.trim()) {
            this.outCh.append(text)
            this.outCh.show(true) // preserveFocus
        }
    }

    /** Affiche les erreurs Octave en rouge dans l'output channel. */
    private logError(text: string): void {
        this.outCh.append(text)
    }

    /** Log interne d'extension (debug). */
    private log(text: string): void {
        this.outCh.append(text)
    }

    /** Retourne l'output channel pour que extension.ts puisse l'afficher. */
    get outputChannel(): vscode.OutputChannel { return this.outCh }

    dispose(): void {
        this.proc?.kill()
        this.lspOut.destroy()
        this.lspIn.destroy()
        this.outCh.dispose()
    }

    // ── Auto-détection Octave sous Windows ───────────────────────────────
    private static detectOctaveWindows(): string | null {
        const programFiles = [
            process.env['ProgramFiles']      ?? 'C:\\Program Files',
            process.env['ProgramFiles(x86)'] ?? 'C:\\Program Files (x86)',
        ]
        for (const root of programFiles) {
            const octaveRoot = path.join(root, 'GNU Octave')
            if (!fs.existsSync(octaveRoot)) continue
            const versions = fs.readdirSync(octaveRoot)
                .filter(d => d.startsWith('Octave-'))
                .sort()
                .reverse()
            for (const ver of versions) {
                const candidate = path.join(octaveRoot, ver, 'mingw64', 'bin', 'octave-cli.exe')
                if (fs.existsSync(candidate)) return candidate
            }
        }
        return null
    }
}
