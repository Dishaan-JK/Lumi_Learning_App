const assistant = { path: '/api/assistant' }
export const RECENT_CHATS_UPDATED_EVENT = 'lumi:recent-chats-updated'
export interface RecentChat { agentPath: string; sessionId: string; title: string; updatedAt?: string }
const validAgentPaths = new Set([assistant.path])
const sessionIdPattern = /^[A-Za-z0-9_-]{1,128}$/

function isKnownAgentPath(value: unknown): value is string {
  return typeof value === 'string' && validAgentPaths.has(value)
}

export function isSessionId(value: unknown): value is string {
  return typeof value === 'string' && sessionIdPattern.test(value)
}

export function readRecentChats(): RecentChat[] {
  try {
    const value: unknown = JSON.parse(localStorage.getItem('lumi.chat.recent') ?? '[]')
    if (!Array.isArray(value)) return []
    const seen = new Set<string>()
    return value.flatMap((item) => {
      if (!item || typeof item !== 'object') return []
      const chat = item as Partial<RecentChat>
      if (!isKnownAgentPath(chat.agentPath) || !isSessionId(chat.sessionId) || typeof chat.title !== 'string') return []
      const title = chat.title.trim().slice(0, 72)
      const key = `${chat.agentPath}:${chat.sessionId}`
      if (!title || seen.has(key)) return []
      seen.add(key)
      return [{ agentPath: chat.agentPath, sessionId: chat.sessionId, title, ...(typeof chat.updatedAt === 'string' ? { updatedAt: chat.updatedAt } : {}) }]
    }).slice(0, 12)
  } catch { return [] }
}

export function persistRecentChats(chats: RecentChat[]) {
  localStorage.setItem('lumi.chat.recent', JSON.stringify(chats))
  window.dispatchEvent(new Event(RECENT_CHATS_UPDATED_EVENT))
}


export const CHAT_DELETED_EVENT = 'lumi:chat-deleted'
