import { useEffect, useMemo, useState, type ReactNode } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  BookOpen,
  Bot,
  ChevronRight,
  FileText,
  Folder,
  Home,
  Menu,
  PanelRightClose,
  Plus,
  Pencil,
  Search,
  Settings,
  Trash2,
  Timer,
  X,
} from 'lucide-react'
import { createFolder, createNote, deleteFolder, deleteNote, getApplicationSettings, getCanvases, getWorkspace, lumiQueryKeys, updateFolder, type LumiApplicationSettings, type LumiFolder, type LumiNote } from './lib/lumi-api'
import { CanvasWorkspace } from './features/canvas/CanvasWorkspace'
import { GraphWorkspace } from './features/graph/GraphWorkspace'
import { NoteEditor } from './features/notes/NoteEditor'
import { SearchDialog } from './features/search/SearchDialog'
import { ArtifactsLibrary } from './features/artifacts/ArtifactsLibrary'
import { SettingsWorkspace } from './features/settings/SettingsWorkspace'
import { CoachPanel } from './features/coach/CoachPanel'
import { RECENT_CHATS_UPDATED_EVENT, readRecentChats, type RecentChat } from './features/coach/recent-chats'
import { RecentChatRow } from './features/coach/RecentChatRow'
import { StudentOnboarding } from './features/profile/StudentOnboarding'
import { hasStudentProfile } from './features/profile/student-profile'
import { HomeWorkspace } from './features/home/HomeWorkspace'
import { useWorkspaceNavigation, type WorkspaceView } from './features/navigation/workspace-navigation'
import { PanelWidthSlider } from './features/layout/PanelWidthSlider'
import { LAYOUT_WIDTHS_UPDATED_EVENT, readLayoutWidths } from './lib/layout-widths'
import { useFocusMode } from './features/focus/useFocusMode'
import { FocusWorkspace } from './features/focus/FocusWorkspace'
import { FocusCompletionDialog } from './features/focus/FocusCompletionDialog'
import { FocusWidget } from './features/focus/FocusWidget'
import './App.css'
import './features/coach/coach.css'

type SaveStatus = 'saved' | 'unsaved' | 'saving' | 'error'

const navItems: Array<{ view: WorkspaceView; label: string; icon: typeof FileText }> = [
  { view: 'home', label: 'Home', icon: Home },
  { view: 'artifacts', label: 'Artifacts', icon: BookOpen },
  { view: 'canvas', label: 'Canvas', icon: PanelRightClose },
  { view: 'focus', label: 'Focus mode', icon: Timer },
  { view: 'settings', label: 'Settings', icon: Settings },
]

function displayTitle(note: LumiNote) {
  return note.title.trim() || 'Untitled note'
}

function recentChatTime(chat: RecentChat) {
  const timestamp = Date.parse(chat.updatedAt ?? '')
  return Number.isFinite(timestamp) ? timestamp : 0
}

function App() {
  const queryClient = useQueryClient()
  const focus = useFocusMode()
  const [isCreatingFolder, setCreatingFolder] = useState(false)
  const [newFolderName, setNewFolderName] = useState('')
  const [newFolderParentId, setNewFolderParentId] = useState('')
  const [collapsedFolderIds, setCollapsedFolderIds] = useState<Set<string>>(new Set())
  const [movingFolderId, setMovingFolderId] = useState<string | null>(null)
  const [moveParentId, setMoveParentId] = useState('')
  const [isNavigationOpen, setNavigationOpen] = useState(false)
  const [isCoachOpen, setCoachOpen] = useState(false)
  const [recentChats, setRecentChats] = useState<RecentChat[]>(readRecentChats)
  const [coachSessionRequest, setCoachSessionRequest] = useState<{ sessionId: string; request: number } | null>(null)
  const [isSearchOpen, setSearchOpen] = useState(false)
  const [searchQuery, setSearchQuery] = useState('')
  const [saveStatus, setSaveStatus] = useState<SaveStatus>('saved')
  useEffect(() => {
    const refreshRecentChats = () => setRecentChats(readRecentChats())
    window.addEventListener(RECENT_CHATS_UPDATED_EVENT, refreshRecentChats)
    return () => window.removeEventListener(RECENT_CHATS_UPDATED_EVENT, refreshRecentChats)
  }, [])
  useEffect(() => {
    const applyLayoutWidths = () => {
      const widths = readLayoutWidths()
      const root = document.documentElement
      root.style.setProperty('--sidebar-width', `${widths.sidebar}px`)
      root.style.setProperty('--coach-width', `${widths.coach}px`)
    }
    applyLayoutWidths()
    window.addEventListener(LAYOUT_WIDTHS_UPDATED_EVENT, applyLayoutWidths)
    return () => window.removeEventListener(LAYOUT_WIDTHS_UPDATED_EVENT, applyLayoutWidths)
  }, [])
  const workspace = useQuery({ queryKey: lumiQueryKeys.workspace, queryFn: getWorkspace })
  const canvases = useQuery({ queryKey: lumiQueryKeys.canvases, queryFn: getCanvases })
  const preferences = useQuery({ queryKey: lumiQueryKeys.settings, queryFn: getApplicationSettings })
  const startPage = preferences.data?.startPage
  const savedStartPage = typeof startPage === 'string' && ['home', 'notes', 'artifacts', 'canvas'].includes(startPage) ? startPage as WorkspaceView : undefined
  const { route, navigate } = useWorkspaceNavigation(savedStartPage)
  const view = route.view
  const selectedNoteId = route.noteId
  const selectedCanvas = canvases.data?.find((canvas) => canvas.id === route.fileId)
  const selectedFolderId = route.folderId
  useEffect(() => {
    const settings = preferences.data ?? {}
    const root = document.documentElement
    const theme = String(settings.theme ?? 'light')
    const media = typeof window.matchMedia === 'function' ? window.matchMedia('(prefers-color-scheme: dark)') : null
    const applyTheme = () => {
      const effective = focus.active ? focus.theme === 'midnight' ? 'dark' : 'light' : theme === 'system' ? media?.matches ? 'dark' : 'light' : theme
      if (focus.active) root.dataset.focusTheme = focus.theme
      else delete root.dataset.focusTheme
      root.dataset.theme = effective
      const suffix = effective === 'dark' ? 'Dark' : 'Light'
      root.style.setProperty('--canvas-background', focus.active ? 'var(--focus-bg)' : String(settings[`canvasBackground${suffix}`] ?? (effective === 'dark' ? '#191C19' : '#F4F1E8')))
      root.style.setProperty('--canvas-pattern', focus.active ? 'var(--focus-border)' : String(settings[`canvasPattern${suffix}`] ?? (effective === 'dark' ? '#465046' : '#C4C7BC')))
    }
    applyTheme()
    if (theme === 'system') media?.addEventListener('change', applyTheme)
    root.dataset.accent = String(settings.accent ?? 'sage')
    root.dataset.density = String(settings.density ?? 'comfortable')
    root.dataset.textSize = String(settings.textSize ?? 'standard')
    root.dataset.reduceMotion = String(Boolean(settings.reduceMotion))
    root.dataset.canvasPattern = String(settings.canvasPattern ?? 'dots')
    return () => { media?.removeEventListener('change', applyTheme); delete root.dataset.focusTheme }
  }, [preferences.data, focus.active, focus.theme])
  const createNoteMutation = useMutation({
    mutationFn: () => createNote(selectedFolderId ?? undefined),
    onSuccess: async (note) => {
      navigate('notes', { noteId: note.id, folderId: selectedFolderId })
      setSaveStatus('saved')
      await queryClient.invalidateQueries({ queryKey: lumiQueryKeys.workspace })
    },
  })
  const createFolderMutation = useMutation({
    mutationFn: ({ name, parentId }: { name: string; parentId?: string }) => createFolder(name, parentId),
    onSuccess: async (folder) => {
      navigate('notes', { folderId: folder.id })
      setCreatingFolder(false)
      setNewFolderName('')
      setNewFolderParentId('')
      await queryClient.invalidateQueries({ queryKey: lumiQueryKeys.workspace })
    },
  })
  const renameFolderMutation = useMutation({
    mutationFn: ({ folder, name }: { folder: LumiFolder; name: string }) => updateFolder(folder.id, name, folder.parentId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: lumiQueryKeys.workspace }),
  })
  const removeFolderMutation = useMutation({
    mutationFn: deleteFolder,
    onSuccess: async (_, folderId) => {
      if (selectedFolderId === folderId) navigate('notes')
      await queryClient.invalidateQueries({ queryKey: lumiQueryKeys.workspace })
    },
  })
  const removeNoteMutation = useMutation({
    mutationFn: deleteNote,
    onSuccess: async (_, noteId) => {
      if (selectedNoteId === noteId) navigate('notes', { folderId: selectedFolderId })
      await queryClient.invalidateQueries({ queryKey: lumiQueryKeys.workspace })
      await queryClient.invalidateQueries({ queryKey: lumiQueryKeys.canvases })
      await queryClient.invalidateQueries({ queryKey: lumiQueryKeys.graph })
    },
  })
  const moveFolderMutation = useMutation({
    mutationFn: ({ folder, parentId }: { folder: LumiFolder; parentId?: string }) => updateFolder(folder.id, folder.name, parentId),
    onSuccess: async () => { setMovingFolderId(null); await queryClient.invalidateQueries({ queryKey: lumiQueryKeys.workspace }) },
  })

  const visibleNotes = useMemo(() => {
    const notes = workspace.data?.notes ?? []
    return selectedFolderId ? notes.filter((note) => note.folderId === selectedFolderId) : notes
  }, [selectedFolderId, workspace.data?.notes])

  const selectedNote = useMemo(
    () => visibleNotes.find((note) => note.id === selectedNoteId) ?? visibleNotes[0],
    [selectedNoteId, visibleNotes],
  )
  const allFolders = workspace.data?.folders ?? []
  const folderCreationParentId = allFolders.some((folder) => folder.id === newFolderParentId) ? newFolderParentId : ''
  const childFolderIds = (parentId: string): Set<string> => {
    const result = new Set<string>()
    const visit = (id: string) => allFolders.filter((folder) => folder.parentId === id).forEach((folder) => { result.add(folder.id); visit(folder.id) })
    visit(parentId)
    return result
  }
  const renderFolder = (folder: LumiFolder, depth = 0): ReactNode => {
    const children = allFolders.filter((candidate) => candidate.parentId === folder.id)
    const collapsed = collapsedFolderIds.has(folder.id)
    return <div className="folder-tree-node" key={folder.id}>
      <div className={`folder-row-wrap ${selectedFolderId === folder.id ? 'is-selected' : ''}`} style={{ paddingLeft: depth * 12 }}>
        {children.length ? <button className="folder-action folder-disclosure" type="button" aria-label={`${collapsed ? 'Expand' : 'Collapse'} ${folder.name}`} aria-expanded={!collapsed} onClick={() => setCollapsedFolderIds((current) => { const next = new Set(current); if (collapsed) next.delete(folder.id); else next.add(folder.id); return next })}><ChevronRight aria-hidden="true" className={collapsed ? '' : 'is-expanded'} /></button> : <span className="folder-disclosure-spacer" />}
        <button className="folder-row" type="button" onClick={() => navigate('notes', { folderId: folder.id })}><Folder aria-hidden="true" /><span>{folder.name}</span></button>
        <button className="folder-action" type="button" aria-label={`Rename ${folder.name}`} onClick={() => { const name = window.prompt('Rename folder', folder.name)?.trim(); if (name && name !== folder.name) renameFolderMutation.mutate({ folder, name }) }}><Pencil aria-hidden="true" /></button>
        <button className="folder-action" type="button" aria-label={`Move ${folder.name}`} onClick={() => { setMovingFolderId(movingFolderId === folder.id ? null : folder.id); setMoveParentId(folder.parentId ?? '') }}><ChevronRight aria-hidden="true" /></button>
        <button className="folder-action" type="button" aria-label={`Delete ${folder.name}`} onClick={() => { if (window.confirm(`Delete “${folder.name}”? Notes in this folder will be kept and moved to the workspace. Child folders will move to the workspace root.`)) removeFolderMutation.mutate(folder.id) }}><Trash2 aria-hidden="true" /></button>
      </div>
      {movingFolderId === folder.id && <form className="folder-move-form" style={{ marginLeft: depth * 12 + 24 }} onSubmit={(event) => { event.preventDefault(); moveFolderMutation.mutate({ folder, parentId: moveParentId || undefined }) }}><label className="sr-only" htmlFor={`folder-parent-${folder.id}`}>Parent folder for {folder.name}</label><select id={`folder-parent-${folder.id}`} value={moveParentId} onChange={(event) => setMoveParentId(event.target.value)}><option value="">Workspace root</option>{allFolders.filter((candidate) => candidate.id !== folder.id && !childFolderIds(folder.id).has(candidate.id)).map((candidate) => <option key={candidate.id} value={candidate.id}>{candidate.name}</option>)}</select><button type="submit" disabled={moveFolderMutation.isPending}>Move</button></form>}
      {!collapsed && children.map((child) => renderFolder(child, depth + 1))}
    </div>
  }

  useEffect(() => {
    function handleShortcut(event: KeyboardEvent) {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault()
        setSearchOpen(true)
      }
    }

    window.addEventListener('keydown', handleShortcut)
    return () => window.removeEventListener('keydown', handleShortcut)
  }, [])

  function closeSearch() {
    setSearchOpen(false)
    setSearchQuery('')
  }

  if (preferences.isPending) return <main className="student-welcome"><p role="status">Opening your workspace…</p></main>
  if (preferences.isError) return <main className="student-welcome"><section className="student-welcome-content"><h1>Couldn’t load your profile.</h1><p role="alert">Check that the local Lumi service is running.</p><button type="button" onClick={() => void preferences.refetch()}>Try again</button></section></main>
  if (!hasStudentProfile(preferences.data)) return <StudentOnboarding settings={preferences.data} />

  return (
    <div className={`app-shell ${focus.session ? 'has-focus-timer' : ''}`}>
      <button
        className="mobile-nav-toggle icon-button"
        type="button"
        aria-label="Open navigation"
        onClick={() => setNavigationOpen(true)}
      >
        <Menu aria-hidden="true" />
      </button>

      <aside className={`workspace-nav ${isNavigationOpen ? 'is-open' : ''}`} aria-label="Workspace navigation">
        <div className="nav-header">
          <div className="brand" aria-label="Lumi">
            <img className="brand-mark" src="/lumi-mark.svg" alt="" />
            <span>Lumi</span>
          </div>
          <button className="mobile-nav-close icon-button" type="button" aria-label="Close navigation" onClick={() => setNavigationOpen(false)}>
            <X aria-hidden="true" />
          </button>
          <button
            className="new-note-button"
            type="button"
            onClick={() => createNoteMutation.mutate()}
            disabled={createNoteMutation.isPending}
          >
            <Plus aria-hidden="true" />
            {createNoteMutation.isPending ? 'Creating note…' : 'New note'}
          </button>
          <button className="search-button" type="button" onClick={() => setSearchOpen(true)}>
            <Search aria-hidden="true" />
            <span>Search</span>
            <kbd>⌘K</kbd>
          </button>
        </div>

        <nav className="nav-scroll">
          <div className="nav-group" aria-label="Workspace views">
            {navItems.map(({ view: targetView, label, icon: Icon }) => (
              <button
                className={`nav-item ${view === targetView ? 'is-active' : ''}`}
                type="button"
                key={targetView}
                onClick={() => {
                  navigate(targetView)
                  setNavigationOpen(false)
                }}
              >
                <Icon aria-hidden="true" />
                <span>{label}</span>
              </button>
            ))}
          </div>

          <section className="nav-section" aria-labelledby="folders-heading">
            <div className="section-heading">
              <h2 id="folders-heading">Folders</h2>
              <button className="small-icon-button" type="button" aria-label="Create folder" onClick={() => { setCreatingFolder((creating) => !creating); setNewFolderParentId(selectedFolderId ?? '') }}>
                <Plus aria-hidden="true" />
              </button>
            </div>
            {isCreatingFolder && <form className="folder-create-form" onSubmit={(event) => { event.preventDefault(); const name = newFolderName.trim(); if (name) createFolderMutation.mutate({ name, parentId: folderCreationParentId || undefined }) }}><label className="sr-only" htmlFor="new-folder-name">New folder name</label><input id="new-folder-name" value={newFolderName} onChange={(event) => setNewFolderName(event.target.value)} placeholder="Folder name" autoFocus /><label className="sr-only" htmlFor="new-folder-parent">Parent folder</label><select id="new-folder-parent" value={folderCreationParentId} onChange={(event) => setNewFolderParentId(event.target.value)}><option value="">Default path</option>{allFolders.map((folder) => <option key={folder.id} value={folder.id}>Inside {folder.name}</option>)}</select><button type="submit" disabled={!newFolderName.trim() || createFolderMutation.isPending}>Add</button></form>}
            {workspace.data?.folders.length ? (
              <div className="folder-tree">{allFolders.filter((folder) => !folder.parentId || !allFolders.some((candidate) => candidate.id === folder.parentId)).map((folder) => renderFolder(folder))}</div>
            ) : (
              <p className="nav-empty">No folders yet</p>
            )}
          </section>

          <section className="nav-section" aria-labelledby="recent-heading">
            <div className="section-heading"><h2 id="recent-heading">Recent</h2></div>
            {recentChats.length ? (
              [...recentChats]
                .sort((a, b) => recentChatTime(b) - recentChatTime(a))
                .slice(0, Math.min(20, Math.max(1, Number(preferences.data?.recentLimit ?? 12))))
                .map((chat) => <RecentChatRow key={chat.sessionId} chat={chat} selected={isCoachOpen && coachSessionRequest?.sessionId === chat.sessionId} onOpen={() => { setCoachSessionRequest((current) => ({ sessionId: chat.sessionId, request: (current?.request ?? 0) + 1 })); setCoachOpen(true); setNavigationOpen(false) }} onDeleted={() => setCoachSessionRequest((current) => current?.sessionId === chat.sessionId ? null : current)} />)
            ) : (
              <p className="nav-empty">Your recent Coach chats will appear here.</p>
            )}
          </section>
        </nav>

        <div className="nav-footer">
          <PanelWidthSlider panel="sidebar" label="Sidebar width" />
          <span className="local-label">Local workspace</span>
        </div>
      </aside>

      {isNavigationOpen && <button className="nav-backdrop" type="button" aria-label="Close navigation" onClick={() => setNavigationOpen(false)} />}

      <main className={`workspace-main ${view === 'canvas' && route.fileId ? 'is-canvas-file-main' : ''}`}>
        <header className="workspace-topbar">
          <div className={`crumbs ${view === 'canvas' && route.fileId ? 'canvas-file-crumb' : ''}`} aria-label="Current location">
            {!(view === 'canvas' && route.fileId) && <><span>Workspace</span><ChevronRight aria-hidden="true" /></>}
            <strong>{view === 'notes' ? displayTitle(selectedNote ?? { title: 'Notes' } as LumiNote) : view === 'canvas' && selectedCanvas ? selectedCanvas.title : navItems.find((item) => item.view === view)?.label ?? 'Settings'}</strong>
          </div>
          {!(view === 'canvas' && route.fileId) && <div className={`save-indicator is-${saveStatus}`} aria-live="polite">
            <span className="save-dot" aria-hidden="true" />
            {saveStatus === 'saved' ? 'Saved locally' : saveStatus === 'unsaved' ? 'Unsaved changes' : saveStatus === 'saving' ? 'Saving…' : 'Save failed'}
          </div>}
        </header>

        <section className={`workspace-content ${view === 'canvas' && route.fileId ? 'is-canvas-file-content' : ''}`} aria-label="Workspace content">
          {view === 'focus' ? <FocusWorkspace focus={focus} /> : view === 'settings' ? (
            <WorkspaceSurface view={view} settingsSection={route.settingsSection} note={selectedNote} notes={workspace.data?.notes ?? []} folders={workspace.data?.folders ?? []} canvases={canvases.data ?? []} preferences={preferences.data ?? {}} fileId={route.fileId} onOpenCanvas={(fileId) => navigate('canvas', { fileId })} onBackToCanvases={() => navigate('canvas')} onSaveStatus={setSaveStatus} onDeleteNote={(noteId) => removeNoteMutation.mutate(noteId)} onCreateNote={() => createNoteMutation.mutate()} onOpenNote={(noteId) => navigate('notes', { noteId })} onOpenView={navigate} onOpenSettingsSection={(settingsSection) => navigate('settings', { settingsSection })} />
          ) : workspace.isLoading ? <LoadingState /> : workspace.isError ? <ErrorState onRetry={() => workspace.refetch()} /> : (
            <WorkspaceSurface view={view} settingsSection={route.settingsSection} note={selectedNote} notes={workspace.data?.notes ?? []} folders={workspace.data?.folders ?? []} canvases={canvases.data ?? []} preferences={preferences.data ?? {}} fileId={route.fileId} onOpenCanvas={(fileId) => navigate('canvas', { fileId })} onBackToCanvases={() => navigate('canvas')} onSaveStatus={setSaveStatus} onDeleteNote={(noteId) => removeNoteMutation.mutate(noteId)} onCreateNote={() => createNoteMutation.mutate()} onOpenNote={(noteId) => navigate('notes', { noteId })} onOpenView={navigate} onOpenSettingsSection={(settingsSection) => navigate('settings', { settingsSection })} />
          )}
        </section>
      </main>

      <aside className="coach-panel" aria-label="Coach Agent">
        <button className="coach-trigger" type="button" aria-label={isCoachOpen ? 'Close Coach Agent' : 'Open Coach Agent'} title={isCoachOpen ? 'Close Coach Agent' : 'Open Coach Agent'} onClick={() => setCoachOpen((open) => !open)}>
          {isCoachOpen ? <X aria-hidden="true" /> : <Bot aria-hidden="true" />}
          <span>Coach Agent</span>
        </button>
      </aside>
      {isCoachOpen && <CoachPanel onNewChat={() => setCoachSessionRequest(null)} settings={preferences.data} note={view === 'notes' ? selectedNote : undefined} canvas={view === 'canvas' ? selectedCanvas : undefined} notes={workspace.data?.notes ?? []} openSessionId={coachSessionRequest?.sessionId} openSessionRequest={coachSessionRequest?.request} onOpenNote={(note) => { navigate('notes', { noteId: note.id, folderId: note.folderId ?? null }); setSaveStatus('saved') }} onOpenCanvas={(canvas) => navigate('canvas', { fileId: canvas.id })} onStartFocus={(action) => {
        const started = focus.start(action.minutes, action.label)
        if (started) {
          if (action.theme) focus.setTheme(action.theme)
          navigate('focus')
        }
        return started
      }} onClose={() => setCoachOpen(false)} />}

      {focus.session && <FocusWidget focus={focus} onOpenFocus={() => { navigate('focus'); setCoachOpen(false) }} />}
      {focus.session?.status === 'completed' && <FocusCompletionDialog onEnd={focus.stop} />}
      {focus.notice && <div className="focus-notice" role="status" aria-label="Focus reminder"><p>{focus.notice}</p>{focus.active && <button type="button" onClick={() => { navigate('focus'); setCoachOpen(false); focus.setNotice('') }}>Go to Focus mode</button>}<button type="button" aria-label="Dismiss focus reminder" onClick={() => focus.setNotice('')}><X size={16} /></button></div>}
      {isSearchOpen && (
        <SearchDialog
          query={searchQuery}
          onQueryChange={setSearchQuery}
          onClose={closeSearch}
          onChooseNote={(noteId) => {
            navigate('notes', { noteId })
            closeSearch()
          }}
        />
      )}
    </div>
  )
}

function WorkspaceSurface({ view, settingsSection, note, notes, folders, canvases, preferences, fileId, onOpenCanvas, onBackToCanvases, onSaveStatus, onDeleteNote, onCreateNote, onOpenNote, onOpenView, onOpenSettingsSection }: { view: WorkspaceView; settingsSection: import('./features/navigation/workspace-navigation').SettingsSection; note?: LumiNote; notes: LumiNote[]; folders: LumiFolder[]; canvases: import('./lib/lumi-api').LumiCanvas[]; preferences: LumiApplicationSettings; fileId: string | null; onOpenCanvas: (id: string) => void; onBackToCanvases: () => void; onSaveStatus: (status: SaveStatus) => void; onDeleteNote: (noteId: string) => void; onCreateNote: () => void; onOpenNote: (id: string) => void; onOpenView: (view: WorkspaceView) => void; onOpenSettingsSection: (section: import('./features/navigation/workspace-navigation').SettingsSection) => void }) {
  if (view === 'home') return <HomeWorkspace notes={notes} folders={folders} canvases={canvases} recentLimit={Number(preferences.recentLimit ?? 12)} onOpenNote={onOpenNote} onOpenCanvas={onOpenCanvas} onCreateNote={onCreateNote} onOpenView={(target) => onOpenView(target)} />
  if (view === 'artifacts') return <ArtifactsLibrary preferences={preferences} />
  if (view === 'canvas') return <CanvasWorkspace notes={notes} selectedCanvasId={fileId} onOpenCanvas={onOpenCanvas} onBackToCanvases={onBackToCanvases} onOpenNote={onOpenNote} onCreateNote={onCreateNote} />
  if (view === 'graph') return <GraphWorkspace onOpenNote={onOpenNote} />
  if (view === 'settings') return <SettingsWorkspace activeTab={settingsSection} onTabChange={onOpenSettingsSection} />

  if (view !== 'notes') {
    const title = navItems.find((item) => item.view === view)?.label ?? 'Settings'
    return <section className="placeholder-surface"><p className="eyebrow">Lumi workspace</p><h1>{title}</h1><p>This view will be migrated in the next React slice. Your existing Lumi data and backend remain unchanged.</p></section>
  }

  if (!note) {
    return <section className="welcome-surface"><p className="eyebrow">Your learning space</p><h1>Start with a thought worth keeping.</h1><p>Create a note to build a calm, connected record of what you are learning.</p></section>
  }

  return <NoteEditor key={note.id} note={note} notes={notes} folders={folders} preferences={preferences} onSaveStatus={onSaveStatus} onDelete={() => onDeleteNote(note.id)} onOpenNote={onOpenNote} />
}

function LoadingState() {
  return <section className="loading-surface" aria-live="polite"><span className="loading-orb" aria-hidden="true" /><p>Opening your workspace…</p></section>
}

function ErrorState({ onRetry }: { onRetry: () => void }) {
  return <section className="error-surface" role="alert"><p className="eyebrow">Workspace unavailable</p><h1>Couldn’t reach the local Lumi service.</h1><p>Check that the Dart/Genkit backend is running, then try again.</p><button type="button" onClick={onRetry}>Try again</button></section>
}

export default App
