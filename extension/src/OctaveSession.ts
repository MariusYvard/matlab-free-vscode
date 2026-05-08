import * as vscode from 'vscode'
import * as cp from 'child_process'
import * as path from 'path'
import * as fs from 'fs'
import * as net from 'net'
import { PassThrough } from 'stream'
import { MsgParser, MfvMessage } from './MsgParser'
import { FigurePanel } from './FigurePanel'
import { ThreeDPanel } from './ThreeDPanel'
import { VariableExplorerPanel } from './VariableExplorerPanel'

export class OctaveSession implements vscode.Disposable {
    private lspProc: cp.ChildProcess | null = null
    private execProc: cp.ChildProcess | null = null
    private parser: MsgParser
    private outCh: vscode.OutputChannel
    private tcpServer: net.Server | null = null
    private tcpPort: number = 0

    public lspOut = new PassThrough()
    public lspIn = new PassThrough()

    private isDisposed = false

    constructor(private readonly ctx: vscode.ExtensionContext) {
        this.parser = new MsgParser()
        this.outCh = vscode.window.createOutputChannel('Octave', { log: false } as any)
        
        // Listen to parser events
        this.parser.on('mfv', (msg: MfvMessage) => this.dispatch(msg))
        this.parser.on('text', (txt: string) => this.logOutput(txt))
        // 'lsp' event is no longer emitted by parser since LSP has its own process
    }

    async start(): Promise<boolean> {
        const cfg = vscode.workspace.getConfiguration('matlab-free')
        let octavePath = cfg.get<string>('octavePath', 'octave')

        if (octavePath === 'octave' && process.platform === 'win32') {
            const detected = OctaveSession.detectOctaveWindows()
            if (detected) {
                octavePath = detected
                this.log(`[matlab-free] Octave détecté automatiquement : ${detected}\n`)
            }
        }

        // Start TCP Server for MFV Messages
        await this.startTcpServer()

        const okLsp = this.startLspProcess(octavePath, cfg)
        const okExec = this.startExecProcess(octavePath, cfg)

        if (!okLsp || !okExec) {
            return false
        }

        return true
    }

    private async startTcpServer(): Promise<void> {
        return new Promise((resolve) => {
            this.tcpServer = net.createServer((socket) => {
                socket.on('data', (data) => {
                    // Feed TCP data directly to parser
                    this.parser.feed(data)
                })
            })
            this.tcpServer.listen(0, '127.0.0.1', () => {
                this.tcpPort = (this.tcpServer?.address() as net.AddressInfo).port
                resolve()
            })
        })
    }

    private startLspProcess(octavePath: string, cfg: vscode.WorkspaceConfiguration): boolean {
        const runtimeDir = path.join(this.ctx.extensionPath, 'runtime')
        const lspLoopM = path.join(runtimeDir, 'lsp_loop.m').replace(/\\/g, '/')
        
        if (!fs.existsSync(lspLoopM)) {
            vscode.window.showErrorMessage(`matlab-free: runtime introuvable. Réinstallez l'extension.`)
            return false
        }

        const extraPaths = cfg.get<string[]>('extraPath', [])
        const addpaths = [runtimeDir, ...extraPaths].map(p => `addpath('${p.replace(/\\/g, '/')}');`).join(' ')
        const initScript = `${addpaths} source('${lspLoopM}'); __mfv_lsp_loop__();`

        this.lspProc = cp.spawn(octavePath, [
            '--no-gui', '--no-line-editing', '--quiet', '--no-history', '--eval', initScript
        ], {
            stdio: ['pipe', 'pipe', 'pipe'],
            env: { 
                ...process.env, 
                OCTAVE_HISTFILE: '/dev/null',
                MFV_TCP_PORT: this.tcpPort.toString()
            }
        })

        if (!this.lspProc.pid) {
            vscode.window.showErrorMessage(`matlab-free: impossible de démarrer LSP à "${octavePath}".`)
            return false
        }

        // Direct pipe for LSP
        this.lspProc.stdout!.on('data', (d) => this.lspOut.write(d))
        this.lspIn.on('data', (d) => this.lspProc?.stdin?.writable && this.lspProc.stdin.write(d))
        this.lspProc.stderr!.on('data', (d) => this.logError(`[LSP] ${d.toString()}`))

        this.lspProc.on('exit', code => {
            if (!this.isDisposed) this.logError(`\n[LSP] Processus arrêté (code ${code})\n`)
        })

        return true
    }

    private startExecProcess(octavePath: string, cfg: vscode.WorkspaceConfiguration): boolean {
        const runtimeDir = path.join(this.ctx.extensionPath, 'runtime')
        const startupM = path.join(runtimeDir, 'startup.m').replace(/\\/g, '/')
        
        const extraPaths = cfg.get<string[]>('extraPath', [])
        const addpaths = [runtimeDir, ...extraPaths].map(p => `addpath('${p.replace(/\\/g, '/')}');`).join(' ')
        const initScript = `${addpaths} run('${startupM}');`

        this.execProc = cp.spawn(octavePath, [
            '--no-gui', '--no-line-editing', '--quiet', '--no-history'
        ], {
            stdio: ['pipe', 'pipe', 'pipe'],
            env: { 
                ...process.env, 
                OCTAVE_HISTFILE: '/dev/null',
                MFV_TCP_PORT: this.tcpPort.toString() // Pass TCP port
            }
        })

        if (!this.execProc.pid) {
            vscode.window.showErrorMessage(`matlab-free: impossible de démarrer le moteur d'exécution.`)
            return false
        }

        // Send startup script to interactive stdin
        this.execProc.stdin.write(initScript + '\n')

        // Stdout fallback routing (if TCP fails) and normal disp() output
        this.execProc.stdout!.on('data', (chunk: Buffer) => this.parser.feed(chunk))
        this.execProc.stderr!.on('data', (d: Buffer) => this.logError(d.toString()))

        this.execProc.on('exit', code => {
            if (this.isDisposed) return
            this.logError(`\n[matlab-free] Moteur d'exécution arrêté (code ${code}). Auto-redémarrage...\n`)
            // Auto-Healing: restart execution engine silently
            setTimeout(() => {
                if (!this.isDisposed) {
                    this.startExecProcess(octavePath, cfg)
                    vscode.window.showInformationMessage('matlab-free : Moteur d\'exécution redémarré (Auto-Healing).')
                }
            }, 1000)
        })

        return true
    }

    sendCommand(code: string): void {
        if (!this.execProc?.stdin?.writable) {
            vscode.window.showWarningMessage('matlab-free : le moteur d\'exécution n\'est pas prêt.')
            return
        }
        
        // We use a pseudo-JSONRPC payload to execute code if Octave is running a listen loop,
        // OR we can just feed code directly to stdin if we are not running lsp_loop on execProc.
        // Wait, if execProc doesn't run lsp_loop, it doesn't parse JSON-RPC!
        // To fix this, we just write the raw code to execProc stdin + newline!
        // But let's wrap it in an eval or just write it.
        this.execProc.stdin.write(code + '\n')
    }

    private dispatch(msg: MfvMessage): void {
        switch (msg.type) {
            case 'figure': FigurePanel.show(msg.handle ?? 1, msg.path); break;
            case 'patch': case 'surf': case '3d': ThreeDPanel.show(`fig_${Date.now()}`, msg as any); break;
            case 'colormap': case 'colorbar': case 'camlight': case 'lighting': ThreeDPanel.broadcast(msg); break;
            case 'title': ThreeDPanel.setTitle(msg.text ?? ''); break;
            case 'workspace': VariableExplorerPanel.push(msg.vars ?? []); break;
            case 'error':
                this.logError(`[Octave] ${msg.message}\n`)
                vscode.window.showErrorMessage(`Octave: ${msg.message}`)
                break
        }
    }

    private logOutput(text: string): void {
        if (text.trim()) {
            this.outCh.append(text)
            this.outCh.show(true)
        }
    }

    private logError(text: string): void {
        this.outCh.append(text)
    }

    private log(text: string): void {
        this.outCh.append(text)
    }

    get outputChannel(): vscode.OutputChannel { return this.outCh }

    dispose(): void {
        this.isDisposed = true
        this.lspProc?.kill()
        this.execProc?.kill()
        this.tcpServer?.close()
        this.lspOut.destroy()
        this.lspIn.destroy()
        this.outCh.dispose()
    }

    private static detectOctaveWindows(): string | null {
        const programFiles = [
            process.env['ProgramFiles'] ?? 'C:\\Program Files',
            process.env['ProgramFiles(x86)'] ?? 'C:\\Program Files (x86)',
        ]
        for (const root of programFiles) {
            const octaveRoot = path.join(root, 'GNU Octave')
            if (!fs.existsSync(octaveRoot)) continue
            const versions = fs.readdirSync(octaveRoot).filter(d => d.startsWith('Octave-')).sort().reverse()
            for (const ver of versions) {
                const candidate = path.join(octaveRoot, ver, 'mingw64', 'bin', 'octave-cli.exe')
                if (fs.existsSync(candidate)) return candidate
            }
        }
        return null
    }
}
