/**
 * MsgParser.ts — matlab-free-vscode
 *
 * Sépare le flux stdout d'Octave en deux canaux :
 *   1. Messages LSP JSON-RPC standard → forwarded au LanguageClient
 *   2. Notifications visuelles MFV  → dispatched aux panneaux Webview
 *
 * Protocole : les notifications sont encadrées par __MFV__...__MFV__
 * (défini dans bootstrap.m), ce qui les rend impossible à confondre
 * avec le flux LSP qui utilise "Content-Length: N\r\n\r\n{...}".
 */

import { EventEmitter } from 'events'

export type MfvMessageType =
    | 'figure' | 'patch' | 'surf'
    | 'colormap' | 'colorbar'
    | 'camlight' | 'lighting'
    | 'axis' | 'drawnow' | 'title'
    | 'vrml' | '3d'
    | 'workspace' | 'error'

export interface MfvMessage {
    type: MfvMessageType
    [key: string]: any
}

const MFV_START = '__MFV__'
const MFV_END   = '__MFV__'
const MFV_RE    = /__MFV__([^_][\s\S]*?)__MFV__/g

export class MsgParser extends EventEmitter {
    private buffer = ''

    /**
     * Injecte un chunk brut de stdout Octave.
     * Émet 'lsp' pour les octets LSP normaux,
     * émet 'mfv' pour chaque notification visuelle extraite.
     */
    feed(chunk: Buffer | string): void {
        this.buffer += typeof chunk === 'string' ? chunk : chunk.toString('utf8')
        this.flush()
    }

    private flush(): void {
        let lspParts: string[] = []
        let lastIndex = 0

        // Réinitialise lastIndex pour chaque appel
        MFV_RE.lastIndex = 0

        let match: RegExpExecArray | null
        while ((match = MFV_RE.exec(this.buffer)) !== null) {
            // Tout ce qui précède la balise MFV est du LSP normal
            const before = this.buffer.slice(lastIndex, match.index)
            if (before.length > 0) lspParts.push(before)

            // Tente de parser la notification JSON
            try {
                const msg: MfvMessage = JSON.parse(match[1])
                this.emit('mfv', msg)
            } catch {
                // JSON malformé → ignore silencieusement
            }

            lastIndex = match.index + match[0].length
        }

        // Ce qui reste après la dernière balise est soit du LSP,
        // soit le début d'une prochaine balise MFV incomplète.
        const tail = this.buffer.slice(lastIndex)

        // Si le tail contient le début d'une balise MFV incomplète,
        // on le garde en buffer. Sinon on l'émet comme LSP.
        if (tail.includes(MFV_START)) {
            const startIdx = tail.lastIndexOf(MFV_START)
            lspParts.push(tail.slice(0, startIdx))
            this.buffer = tail.slice(startIdx)
        } else {
            lspParts.push(tail)
            this.buffer = ''
        }

        const lspData = lspParts.join('')
        if (lspData.length > 0) {
            this.emit('lsp', Buffer.from(lspData, 'utf8'))
        }
    }
}
