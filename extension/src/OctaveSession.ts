/**
 * OctaveSession.ts — matlab-free-vscode
 */
import * as vscode  from 'vscode'
import * as cp      from 'child_process'
import * as path    from 'path'
import * as fs      from 'fs'
import { PassThrough } from 'stream'
import { MsgParser, MfvMessage } from './MsgParser'
import { FigurePanel }           from './FigurePanel'
import { ThreeDPanel }           from './ThreeDPanel'

export class OctaveSession implements vscode.Disposable {
    private proc:   cp.ChildProcess | null = null
    private parser: MsgParser
    private outCh:  vscode.OutputChannel | null = null

    public lspOut = new PassThrough()
    public lspIn  = new PassThrough()

    constructor(private readonly ctx: vscode.ExtensionContext) {
        this.parser = new MsgParser()
    }

    async start(): Promise<boolean> {
        const cfg        = vscode.workspace.getConfiguration('matlab-free')
        const octavePath = cfg.get<string>('octavePath', 'octave')
        const extraPaths = cfg.get<string[]>('extraPath', [])
        const runtimeDir = path.join(this.ctx.extensionPath, 'runtime')
        const startupM   = path.join(runtimeDir, 'startup.m').replace(/\\/g, '/')
        const lspLoopM   = path.join(runtimeDir, 'lsp_loop.m').replace(/\\/g, '/')

        if (!fs.existsSync(startupM)) {
            vscode.window.showErrorMessage('matlab-free: runtime introuvable. Reinstallez l extension.')
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
            '--no-gui', '--no-line-editing', '--quiet', '--no-history',
            '--eval', initScript,
        ], { stdio: ['pipe','pipe','pipe'], env: { ...process.env, OCTAVE_HISTFILE: '/dev/null' } })

        if (!this.proc.pid) {
            vscode.window.showErrorMessage(`matlab-free: impossible de démarrer Octave à "${octavePath}".`)
            return false
        }

        this.proc.stdout!.on('data', (chunk: Buffer) => this.parser.feed(chunk))
        this.parser.on('lsp', (data: Buffer) => this.lspOut.write(data))
        this.parser.on('mfv', (msg: MfvMessage) => this.dispatch(msg))
        this.lspIn.on('data', (chunk: Buffer) => {
            this.proc?.stdin?.writable && this.proc.stdin.write(chunk)
        })
        this.proc.stderr!.on('data', (d: Buffer) => this.log(d.toString()))
        this.proc.on('exit', code => {
            if (code !== 0)
                vscode.window.showWarningMessage(`matlab-free: Octave s est arrete (code ${code}). Utilisez "MATLAB: Redemarrer".`)
        })
        return true
    }

    sendCommand(code: string): void {
        if (!this.proc?.stdin?.writable) return
        const req    = JSON.stringify({ jsonrpc: '2.0', method: 'octave/runCode', params: { code } })
        const header = `Content-Length: ${Buffer.byteLength(req)}\r\n\r\n`
        this.proc.stdin.write(header + req)
    }

    private dispatch(msg: MfvMessage): void {
        switch (msg.type) {
            case 'figure':   FigurePanel.show(msg.handle ?? 1, msg.path); break
            case 'patch': case 'surf': case '3d':
                ThreeDPanel.show(`fig_${Date.now()}`, msg as any); break
            case 'colormap': case 'colorbar': case 'camlight': case 'lighting':
                ThreeDPanel.broadcast(msg); break
            case 'title':    ThreeDPanel.setTitle(msg.text ?? ''); break
            case 'error':
                this.log(`[Octave error] ${msg.message}`)
                vscode.window.showErrorMessage(`Octave: ${msg.message}`)
                break
        }
    }

    private log(text: string): void {
        if (!this.outCh) this.outCh = vscode.window.createOutputChannel('Octave (matlab-free)')
        this.outCh.append(text)
    }

    dispose(): void {
        this.proc?.kill()
        this.lspOut.destroy()
        this.lspIn.destroy()
        this.outCh?.dispose()
    }
}
