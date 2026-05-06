/**
 * MsgParser.ts — matlab-free-vscode
 * Separe le flux stdout d'Octave en LSP et notifications MFV.
 * Protocole MFV : __MFV__{JSON}__MFV__
 */
import { EventEmitter } from 'events'

export type MfvMessageType =
    | 'figure' | 'patch' | 'surf'
    | 'colormap' | 'colorbar'
    | 'camlight' | 'lighting'
    | 'axis' | 'drawnow' | 'title'
    | 'vrml' | '3d' | 'error'

export interface MfvMessage {
    type: MfvMessageType
    [key: string]: any
}

const MFV_START = '__MFV__'
const MFV_RE    = /__MFV__([^_][\s\S]*?)__MFV__/g

export class MsgParser extends EventEmitter {
    private buffer = ''

    feed(chunk: Buffer | string): void {
        this.buffer += typeof chunk === 'string' ? chunk : chunk.toString('utf8')
        this.flush()
    }

    private flush(): void {
        let lspParts: string[] = []
        let lastIndex = 0
        MFV_RE.lastIndex = 0
        let match: RegExpExecArray | null
        while ((match = MFV_RE.exec(this.buffer)) !== null) {
            const before = this.buffer.slice(lastIndex, match.index)
            if (before.length > 0) lspParts.push(before)
            try {
                const msg: MfvMessage = JSON.parse(match[1])
                this.emit('mfv', msg)
            } catch { /* ignore */ }
            lastIndex = match.index + match[0].length
        }
        const tail = this.buffer.slice(lastIndex)
        if (tail.includes(MFV_START)) {
            const startIdx = tail.lastIndexOf(MFV_START)
            lspParts.push(tail.slice(0, startIdx))
            this.buffer = tail.slice(startIdx)
        } else {
            lspParts.push(tail)
            this.buffer = ''
        }
        const lspData = lspParts.join('')
        if (lspData.length > 0) this.emit('lsp', Buffer.from(lspData, 'utf8'))
    }
}
