import { useCallback, useEffect, useState } from 'react'

export const workspaceViews = ['home', 'notes', 'artifacts', 'canvas', 'graph', 'focus', 'settings'] as const
export type WorkspaceView = typeof workspaceViews[number]
export type SettingsSection = 'general' | 'appearance' | 'ai' | 'learning' | 'workspace' | 'artifacts' | 'privacy' | 'storage' | 'diagnostics' | 'hardware'

export type WorkspaceRoute = {
  view: WorkspaceView
  noteId: string | null
  fileId: string | null
  artifactId: string | null
  folderId: string | null
  settingsSection: SettingsSection
  isExplicit: boolean
}

const routePath: Record<WorkspaceView, string> = {
  home: '/home',
  notes: '/notes',
  artifacts: '/artifacts',
  canvas: '/canvas',
  graph: '/graph',
  focus: '/focus',
  settings: '/settings',
}

const settingsSections: SettingsSection[] = ['general', 'appearance', 'ai', 'learning', 'workspace', 'artifacts', 'privacy', 'storage', 'diagnostics', 'hardware']

function isWorkspaceView(value: string): value is WorkspaceView {
  return (workspaceViews as readonly string[]).includes(value)
}

function isSettingsSection(value: string | null): value is SettingsSection {
  return value !== null && settingsSections.includes(value as SettingsSection)
}

function readRoute(fallback: WorkspaceView, location: Pick<Location, 'pathname' | 'search'> = window.location): WorkspaceRoute {
  const path = location.pathname.split('/').filter(Boolean).at(-1) ?? ''
  const params = new URLSearchParams(location.search)
  const view = isWorkspaceView(path) ? path : fallback
  const section = params.get('section')
  return {
    view,
    noteId: params.get('note'),
    fileId: view === 'canvas' ? params.get('file') : null,
    artifactId: view === 'artifacts' ? params.get('artifact') : null,
    folderId: params.get('folder'),
    settingsSection: isSettingsSection(section) ? section : 'general',
    isExplicit: isWorkspaceView(path),
  }
}

function routeUrl(route: WorkspaceRoute): string {
  const params = new URLSearchParams()
  if (route.view === 'notes' && route.noteId) params.set('note', route.noteId)
  if (route.view === 'canvas' && route.fileId) params.set('file', route.fileId)
  if (route.view === 'artifacts' && route.artifactId) params.set('artifact', route.artifactId)
  if (route.view === 'notes' && route.folderId) params.set('folder', route.folderId)
  if (route.view === 'settings' && route.settingsSection !== 'general') params.set('section', route.settingsSection)
  const query = params.toString()
  return `${routePath[route.view]}${query ? `?${query}` : ''}`
}

const LAST_ROUTE_KEY = 'lumi.workspace.last-route'

function initialRoute(fallback: WorkspaceView): WorkspaceRoute {
  const current = readRoute(fallback)
  if (current.isExplicit || window.location.pathname !== '/') return current
  try {
    const saved = localStorage.getItem(LAST_ROUTE_KEY)
    if (saved) {
      const url = new URL(saved, window.location.origin)
      if (url.origin === window.location.origin && /^\/(home|notes|artifacts|canvas|graph|focus|settings)$/.test(url.pathname)) {
        return readRoute(fallback, url)
      }
    }
  } catch { /* Browser storage can be unavailable or invalid. */ }
  return current
}

export function useWorkspaceNavigation(defaultView: WorkspaceView | undefined) {
  const [route, setRoute] = useState<WorkspaceRoute>(() => initialRoute(defaultView ?? 'notes'))

  useEffect(() => {
    if (!route.isExplicit) return
    const url = routeUrl(route)
    try { localStorage.setItem(LAST_ROUTE_KEY, url) } catch { /* Keep navigation usable without storage. */ }
    if (window.location.pathname === '/') window.history.replaceState({}, '', url)
  }, [route])

  const commit = useCallback((next: WorkspaceRoute, replace = false) => {
    const url = routeUrl(next)
    window.history[replace ? 'replaceState' : 'pushState']({}, '', url)
    setRoute(next)
  }, [])

  useEffect(() => {
    const onPopState = () => setRoute(readRoute(defaultView ?? 'notes'))
    window.addEventListener('popstate', onPopState)
    return () => window.removeEventListener('popstate', onPopState)
  }, [defaultView])

  const navigate = useCallback((view: WorkspaceView, details: Partial<Pick<WorkspaceRoute, 'noteId' | 'fileId' | 'artifactId' | 'folderId' | 'settingsSection'>> = {}, replace = false) => {
    commit({
      view,
      noteId: details.noteId ?? null,
      fileId: details.fileId ?? null,
      artifactId: details.artifactId ?? null,
      folderId: details.folderId ?? null,
      settingsSection: details.settingsSection ?? (view === 'settings' ? route.settingsSection : 'general'),
      isExplicit: true,
    }, replace)
  }, [commit, route.settingsSection])

  const resolvedRoute = route.isExplicit || !defaultView ? route : { ...route, view: defaultView }
  return { route: resolvedRoute, navigate }
}
