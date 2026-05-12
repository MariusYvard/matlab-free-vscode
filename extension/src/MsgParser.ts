/**
 * MsgParser.ts — matlab-free-vscode
 *
 * Sépare le flux entrant du moteur d'exécution Octave (TCP + stdout) en :
 *   1. Notifications visuelles MFV  → événement 'mfv', dispatch panneaux
 *   2. Texte brut (disp, fprintf...) → événement 'text', output channel
 *
 * Protocole : les notifications sont encadrées par __MFV__...__MFV__
 * (émises par __mfv_notify__.m).
 *
 * Note : ce parser n'est plus utilisé pour le LSP. Le process LSP a son
 * propre pipe stdin/stdout direct vers le LanguageClient.
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
     * Injecte un chunk brut. Émet 'mfv' pour chaque notification balisée
     * et 'text' pour le reste (sortie stdout Octave classique).
     */
    feed(chunk: Buffer | string): void {
        this.buffer += typeof chunk === 'string' ? chunk : chunk.toString('utf8')
        this.flush()
    }

    private flush(): void {
        const textParts: string[] = []
        let lastIndex = 0

        MFV_RE.lastIndex = 0

        let match: RegExpExecArray | null
        while ((match = MFV_RE.exec(this.buffer)) !== null) {
            const before = this.buffer.slice(lastIndex, match.index)
            if (before.length > 0) textParts.push(before)

            try {
                const msg: MfvMessage = JSON.parse(match[1])
                this.emit('mfv', msg)
            } catch {
                // JSON malformé : on ignore
            }

            lastIndex = match.index + match[0].length
        }

        // Conserve un fragment de balise éventuelle pour le prochain chunk
        const tail = this.buffer.slice(lastIndex)
        if (tail.includes(MFV_START)) {
            const startIdx = tail.lastIndexOf(MFV_START)
            textParts.push(tail.slice(0, startIdx))
            this.buffer = tail.slice(startIdx)
        } else {
            textParts.push(tail)
            this.buffer = ''
        }

        const textData = textParts.join('')
        if (textData.length > 0) {
            this.emit('text', textData)
        }
    }
}
