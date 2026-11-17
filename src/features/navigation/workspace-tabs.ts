export type NoteOrigin = { type: 'artifacts' } | { type: 'canvas'; id: string }
export type WorkspaceTab =
  | { type: 'note'; id: string; origin?: NoteOrigin }
  | { type: 'canvas'; id: string }

const STORAGE_KEY = 'lumi.workspace.open-tabs'

export function readWorkspaceTabs(): WorkspaceTab[] {
  try {
    const value: unknown = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? '[]')
    if (!Array.isArray(value)) return []
    const seen = new Set<string>()
    return value.flatMap((item): WorkspaceTab[] => {
      if (!item || typeof item !== 'object' || typeof item.id !== 'string' || !item.id) return []
      if (item.type === 'canvas') {
        const key = `canvas:${item.id}`
        if (seen.has(key)) return []
        seen.add(key)
        return [{ type: 'canvas', id: item.id }]
      }
      if (item.type !== 'note') return []
      const key = `note:${item.id}`
      if (seen.has(key)) return []
      seen.add(key)
      const origin = item.origin && typeof item.origin === 'object' && item.origin.type === 'artifacts'
        ? { type: 'artifacts' as const }
        : item.origin && typeof item.origin === 'object' && item.origin.type === 'canvas' && typeof item.origin.id === 'string'
          ? { type: 'canvas' as const, id: item.origin.id }
          : undefined
      return [{ type: 'note', id: item.id, ...(origin ? { origin } : {}) }]
    }).slice(-32)
  } catch { return [] }
}

export function persistWorkspaceTabs(tabs: WorkspaceTab[]) {
  try { localStorage.setItem(STORAGE_KEY, JSON.stringify(tabs.slice(-32))) } catch { /* Keep the current tabs available for this session. */ }
}

export function workspaceTabKey(tab: WorkspaceTab) {
  return `${tab.type}:${tab.id}`
}
