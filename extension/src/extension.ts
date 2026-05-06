/**
 * extension.ts — matlab-free-vscode
 */
import * as vscode from 'vscode'
import { LanguageClient, LanguageClientOptions, StreamInfo } from 'vscode-languageclient/node'
import { OctaveSession } from './OctaveSession'

let client:  LanguageClient | null = null
let session: OctaveSession  | null = null

export async function activate(context: vscode.ExtensionContext) {
    session = new OctaveSession(context)
    const started = await session.start()
    if (!started) return

    const serverOptions = (): Promise<StreamInfo> =>
        Promise.resolve({ writer: session!.lspIn, reader: session!.lspOut })

    const clientOptions: LanguageClientOptions = {
        documentSelector: [
            { scheme: 'file', language: 'matlab' },
            { scheme: 'file', language: 'octave' },
        ],
        synchronize: { fileEvents: vscode.workspace.createFileSystemWatcher('**/*.m') },
        outputChannelName: 'matlab-free LSP',
    }

    client = new LanguageClient('matlab-free', 'MATLAB / Octave (matlab-free)', serverOptions, clientOptions)
    client.start()

    context.subscriptions.push(
        vscode.commands.registerCommand('matlab-free.runSelection', () => {
            const editor = vscode.window.activeTextEditor
            if (!editor) return
            const sel  = editor.selection
            const code = sel.isEmpty ? editor.document.lineAt(sel.active.line).text.trim() : editor.document.getText(sel)
            session?.sendCommand(code)
        }),
        vscode.commands.registerCommand('matlab-free.runFile', () => {
            const editor = vscode.window.activeTextEditor
            if (!editor || editor.document.languageId !== 'matlab') return
            session?.sendCommand(`run('${editor.document.uri.fsPath.replace(/\\/g, '/')}')`)
        }),
        vscode.commands.registerCommand('matlab-free.restart', async () => {
            session?.dispose()
            session = new OctaveSession(context)
            await session.start()
            vscode.window.showInformationMessage('matlab-free: session Octave redemarre.')
        }),
        session,
        { dispose: () => client?.stop() }
    )

    vscode.window.setStatusBarMessage('$(check) Octave pret', 3000)
}

export function deactivate(): Thenable<void> | undefined {
    return client?.stop()
}
