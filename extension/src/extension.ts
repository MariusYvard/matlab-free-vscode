/**
 * extension.ts — matlab-free-vscode
 * Point d'entrée de l'extension VS Code.
 * Coordonne OctaveSession, FigurePanel, ThreeDPanel, VariableExplorerPanel
 * et le LanguageClient LSP.
 */

import * as vscode from 'vscode'
import * as path   from 'path'
import {
    LanguageClient,
    LanguageClientOptions,
    StreamInfo,
} from 'vscode-languageclient/node'
import { OctaveSession }         from './OctaveSession'
import { FigurePanel   }         from './FigurePanel'
import { ThreeDPanel   }         from './ThreeDPanel'
import { VariableExplorerPanel } from './VariableExplorerPanel'

let client:  LanguageClient  | null = null
let session: OctaveSession   | null = null

export async function activate(context: vscode.ExtensionContext) {
    // ── 1. Démarre la session Octave ──────────────────────────────────────
    session = new OctaveSession(context)
    const started = await session.start()
    if (!started) return

    // ── 2. Câble le LanguageClient sur les streams LSP d'Octave ──────────
    const serverOptions = (): Promise<StreamInfo> =>
        Promise.resolve({
            writer: session!.lspIn,
            reader: session!.lspOut,
        })

    const clientOptions: LanguageClientOptions = {
        documentSelector: [
            { scheme: 'file', language: 'matlab' },
            { scheme: 'file', language: 'octave' },
        ],
        synchronize: {
            fileEvents: vscode.workspace.createFileSystemWatcher('**/*.m'),
        },
        outputChannelName: 'matlab-free LSP',
    }

    client = new LanguageClient(
        'matlab-free',
        'MATLAB / Octave (matlab-free)',
        serverOptions,
        clientOptions
    )
    client.start()

    // ── 3. Commandes ──────────────────────────────────────────────────────

    // Exécuter la sélection ou la ligne courante
    context.subscriptions.push(
        vscode.commands.registerCommand('matlab-free.runSelection', () => {
            const editor = vscode.window.activeTextEditor
            if (!editor) return
            const sel  = editor.selection
            const code = sel.isEmpty
                ? editor.document.lineAt(sel.active.line).text.trim()
                : editor.document.getText(sel)
            if (code.trim()) session?.sendCommand(code)
        })
    )

    // Exécuter tout le fichier courant
    context.subscriptions.push(
        vscode.commands.registerCommand('matlab-free.runFile', () => {
            const editor = vscode.window.activeTextEditor
            if (!editor) return
            if (editor.document.languageId !== 'matlab' &&
                editor.document.languageId !== 'octave') return
            // Échappe les apostrophes pour Octave : 'foo''bar.m'
            const filePath = editor.document.uri.fsPath
                .replace(/\\/g, '/')
                .replace(/'/g, "''")
            session?.sendCommand(`run('${filePath}')`)
        })
    )

    // Redémarrer la session Octave
    context.subscriptions.push(
        vscode.commands.registerCommand('matlab-free.restart', async () => {
            await client?.stop()
            session?.dispose()
            session = new OctaveSession(context)
            const ok = await session.start()
            if (!ok) return
            // Recâble le client sur les nouveaux streams
            const newServerOptions = (): Promise<StreamInfo> =>
                Promise.resolve({ writer: session!.lspIn, reader: session!.lspOut })
            client = new LanguageClient('matlab-free', 'MATLAB / Octave (matlab-free)',
                newServerOptions, clientOptions)
            client.start()
            context.subscriptions.push(session)
            vscode.window.showInformationMessage('matlab-free : session Octave redémarrée.')
        })
    )

    // Ouvrir le Variable Explorer
    context.subscriptions.push(
        vscode.commands.registerCommand('matlab-free.showVariableExplorer', () => {
            VariableExplorerPanel.show()
        })
    )

    // Effacer le workspace Octave
    context.subscriptions.push(
        vscode.commands.registerCommand('matlab-free.clearWorkspace', () => {
            session?.sendCommand('clear all;')
            vscode.window.showInformationMessage('matlab-free : workspace effacé.')
        })
    )

    // Afficher l'output channel Octave
    context.subscriptions.push(
        vscode.commands.registerCommand('matlab-free.showOutput', () => {
            session?.outputChannel.show()
        })
    )

    context.subscriptions.push(session)
    context.subscriptions.push({ dispose: () => client?.stop() })

    vscode.window.setStatusBarMessage('$(check) Octave prêt', 3000)
}

export function deactivate(): Thenable<void> | undefined {
    return client?.stop()
}
