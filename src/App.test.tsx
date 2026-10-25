import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import App from './App'

const fetchMock = vi.fn()
let canvasFixtures: Array<Record<string, unknown>> = []
let startPageFixture = 'notes'
let studentSettingsFixture: Record<string, string | number | boolean> = {}
let settingsSaveFails = false
let chatDeleteFails = false
let createdAgentNote = false
let coachReplyCount = 0
let coachReplyFixture: string | ((init?: RequestInit) => string) | null = null

function renderApp() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return render(<QueryClientProvider client={client}><App /></QueryClientProvider>)
}

describe('Lumi React workspace shell', () => {
  beforeEach(() => {
    window.history.replaceState({}, '', '/')
    canvasFixtures = []
    startPageFixture = 'notes'
    studentSettingsFixture = { displayName: 'Ananya', studentClass: 'Class 10', schoolName: 'Sample School', studentProfileCompleted: true }
    settingsSaveFails = false
    chatDeleteFails = false
    createdAgentNote = false
    coachReplyCount = 0
    coachReplyFixture = null
    window.localStorage.clear()
    vi.stubGlobal('fetch', fetchMock)
    fetchMock.mockImplementation((request: URL, init?: RequestInit) => {
      if (request.pathname === '/api/notes/note-1' && init?.method === 'PUT') {
        const body = JSON.parse(String(init.body)) as { title: string; content: string; folderId?: string }
        return Promise.resolve(new Response(JSON.stringify({
          id: 'note-1', title: body.title, content: body.content, folderId: body.folderId, updatedAt: '2026-10-20T00:00:00.000Z',
        })))
      }
      if (request.pathname === '/api/search') {
        return Promise.resolve(new Response(JSON.stringify([
          { id: 'note-1', title: 'Learning the senses', content: 'A note about attention.', updatedAt: '2026-10-20T00:00:00.000Z' },
        ])))
      }
      if (request.pathname.startsWith('/api/canvases/') && init?.method === 'PUT') {
        const changes = JSON.parse(String(init.body)) as Record<string, unknown>
        canvasFixtures = canvasFixtures.map((canvas) => canvas.id === decodeURIComponent(request.pathname.split('/').at(-1)!) ? { ...canvas, ...changes, updatedAt: '2026-10-20T00:01:00.000Z' } : canvas)
        return Promise.resolve(new Response(JSON.stringify(canvasFixtures.find((canvas) => canvas.id === decodeURIComponent(request.pathname.split('/').at(-1)!)))))
      }
      if (request.pathname === '/api/canvases' && init?.method === 'POST') {
        const body = JSON.parse(String(init.body)) as { title: string; noteIds: string[] }
        const created = { id: 'canvas-2', title: body.title, description: '', noteIds: body.noteIds, positions: {}, quizzes: [], updatedAt: '2026-10-20T00:00:00.000Z' }
        canvasFixtures.push(created)
        return Promise.resolve(new Response(JSON.stringify(created), { status: 201 }))
      }
      if (request.pathname === '/api/canvases') return Promise.resolve(new Response(JSON.stringify(canvasFixtures)))
      if (request.pathname === '/api/assistant/getSnapshot' && JSON.parse(String(init?.body)).data.sessionId === 'saved-chat') return Promise.resolve(new Response(JSON.stringify({ state: { messages: [{ role: 'model', content: [{ text: 'Earlier explanation' }] }] } })))
      if (request.pathname.startsWith('/api/agent-sessions/') && init?.method === 'DELETE') return Promise.resolve(new Response(JSON.stringify(chatDeleteFails ? { error: 'Delete failed' } : { deleted: true }), { status: chatDeleteFails ? 500 : 200 }))
      if (request.pathname === '/api/application-settings' && init?.method === 'PUT') {
        if (settingsSaveFails) return Promise.resolve(new Response(JSON.stringify({ error: 'Save failed' }), { status: 500 }))
        studentSettingsFixture = { ...studentSettingsFixture, ...JSON.parse(String(init.body)) }
        return Promise.resolve(new Response(JSON.stringify({ workspaceName: 'My workspace', ...studentSettingsFixture })))
      }
      if (request.pathname === '/api/application-settings') return Promise.resolve(new Response(JSON.stringify({ workspaceName: 'My workspace', startPage: startPageFixture, theme: 'light', canvasPattern: 'dots', reduceMotion: false, teachingStyle: 'balanced', difficulty: 'adaptive', coachContext: true, ...studentSettingsFixture })))
      if (request.pathname === '/api/profile/preferences' && init?.method === 'POST') {
        const preference = JSON.parse(String(init.body)).preference
        if (preference.startsWith('Use ')) return Promise.resolve(new Response(JSON.stringify({ error: 'Save only a clear learning or communication preference.' }), { status: 400 }))
        return Promise.resolve(new Response(JSON.stringify({ preferences: ['I prefer short examples', preference] })))
      }
      if (request.pathname === '/api/profile') return Promise.resolve(new Response(JSON.stringify({ preferences: ['I prefer short examples'] })))
      if (request.pathname === '/api/learning-record') return Promise.resolve(new Response(JSON.stringify({ events: [{ kind: 'review' }], patterns: [], dueReviews: [] })))
      if (request.pathname === '/api/workspace/status') return Promise.resolve(new Response(JSON.stringify({ version: '0.1.0', service: 'Online', provider: 'Local Ollama', model: 'qwen2.5:3b', notes: 2, folders: 1, canvases: 1, artifacts: 3, storageBytes: 1200 })))
      if (request.pathname === '/api/local-models/hardware') return Promise.resolve(new Response(JSON.stringify({ supported: true, cpu: { name: 'Test CPU', threads: 8 }, memory: { totalBytes: 16 * 1024 ** 3, availableBytes: 8 * 1024 ** 3 }, gpus: [{ name: 'Test GPU', vendor: 'Test vendor', memoryType: 'shared', runtimeVerified: false, note: 'Runtime check not performed.' }], storage: { availableBytes: null, note: 'Not configured' }, ollama: { available: true, version: 'test', runningModels: [] }, checkedAt: '2026-10-20T00:00:00.000Z' })))
      if (request.pathname === '/api/settings' && init?.method === 'POST') return Promise.resolve(new Response(JSON.stringify({ saved: true, restartRequired: false, reconnecting: true, apiKeyConfigured: true })))
      if (request.pathname === '/api/settings/test') return Promise.resolve(new Response(JSON.stringify({ connected: true, message: 'Connection verified.' })))
      if (request.pathname === '/api/settings') return Promise.resolve(new Response(JSON.stringify({ provider: 'Local Ollama', providerId: 'ollama', model: 'qwen2.5:3b', baseUrl: 'http://127.0.0.1:11434/v1', apiKeyConfigured: false, restartRequired: false })))
      if (['/api/assistant', '/api/agents/study', '/api/agents/connections', '/api/agents/tester', '/api/agents/reviewer'].includes(request.pathname) && init?.method === 'POST') {
        const replyIndex = ++coachReplyCount
        const reply = typeof coachReplyFixture === 'function' ? coachReplyFixture(init) : coachReplyFixture ?? `Ready ${replyIndex}`
        const frames = [
          { message: { modelChunk: { content: [{ text: reply }] } } },
          { result: { sessionId: `session-${replyIndex}` } },
        ].map((event) => `data: ${JSON.stringify(event)}\n\n`).join('')
        return Promise.resolve(new Response(new ReadableStream({ start(controller) { controller.enqueue(new TextEncoder().encode(frames)); controller.close() } }), { headers: { 'Content-Type': 'text/event-stream' } }))
      }
      if (request.pathname === '/api/graph') return Promise.resolve(new Response(JSON.stringify({ nodes: [{ id: 'note-1', title: 'Learning the senses', content: 'A note about attention.', updatedAt: '2026-10-20T00:00:00.000Z' }, { id: 'note-2', title: 'Attention', content: 'Related ideas.', updatedAt: '2026-10-19T00:00:00.000Z' }], edges: [{ from: 'note-1', to: 'note-2' }] })))
      if (request.pathname === '/api/artifacts') {
        return Promise.resolve(new Response(JSON.stringify([
          {
            id: 'artifact-1', kind: 'Flashcards', title: 'Attention cues', content: 'Short prompts for noticing where attention goes.',
            source: 'Learning the senses', sourceId: 'note-1', updatedAt: '2026-10-20T00:00:00.000Z',
            learningObject: { type: 'flashcards', cards: [{ front: 'What directs attention?', back: 'A cue that signals what to notice.' }] },
          },
          {
            id: 'artifact-2', kind: 'Lesson', title: 'The memory loop', content: 'A concise explanation of recall and review.',
            source: 'Lumi Coach', sourceId: 'session-1', updatedAt: '2026-10-19T00:00:00.000Z',
            learningObject: { type: 'quiz', questions: [{ prompt: 'Which practice strengthens recall?', options: ['Retrieval practice', 'Skipping review', 'Copying notes', 'Guessing'] }] },
          },
        ])))
      }
      if (request.pathname === '/api/artifacts/artifact-2/attempt' && init?.method === 'POST') {
        return Promise.resolve(new Response(JSON.stringify({ score: 1, total: 1, feedback: [{ correct: true, answerIndex: 0, explanation: 'Retrieval practice strengthens recall.' }] })))
      }
      if (request.pathname === '/api/notes' && init?.method === 'POST') {
        const body = JSON.parse(String(init.body)) as { title: string; content: string; folderId?: string }
        return Promise.resolve(new Response(JSON.stringify({
          id: 'note-2', title: body.title, content: body.content, folderId: body.folderId, updatedAt: '2026-10-20T00:00:00.000Z',
        })))
      }
      if (request.pathname === '/api/folders' && init?.method === 'POST') {
        return Promise.resolve(new Response(JSON.stringify({ id: 'folder-2', name: JSON.parse(String(init.body)).name })))
      }
      if (request.pathname === '/api/notes') {
        return Promise.resolve(new Response(JSON.stringify([
          { id: 'note-1', title: 'Learning the senses', content: 'A note about attention.', folderId: 'folder-1', updatedAt: '2026-10-20T00:00:00.000Z' },
          { id: 'note-2', title: 'Attention', content: 'Related ideas.', updatedAt: '2026-10-19T00:00:00.000Z' },
          ...(createdAgentNote ? [{ id: 'agent-note', title: 'Quantum Mechanics', content: 'Quantum mechanics describes microscopic states and probabilities.', updatedAt: '2026-10-24T00:00:00.000Z' }] : []),
        ])))
      }
      if (request.pathname === '/api/folders') {
        return Promise.resolve(new Response(JSON.stringify([{ id: 'folder-1', name: 'Research' }, { id: 'folder-2', name: 'Nested', parentId: 'folder-1' }])))
      }
      return Promise.resolve(new Response(null, { status: 404 }))
    })
  })

  afterEach(() => {
    cleanup()
    vi.unstubAllGlobals()
  })

  it('collects and persists student details on first launch and skips setup after reopening', async () => {
    studentSettingsFixture = {}
    const user = userEvent.setup()
    const app = renderApp()
    expect(await screen.findByRole('heading', { name: 'Welcome to Lumi.' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Open Coach Agent' })).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Start learning' })).toBeDisabled()
    await user.type(screen.getByLabelText('Name'), '  Mira  ')
    await user.type(screen.getByLabelText('Class'), 'Class 9')
    await user.type(screen.getByLabelText('School name'), 'Sample School')
    await user.click(screen.getByRole('button', { name: 'Start learning' }))
    await screen.findByLabelText('Note title')
    expect(studentSettingsFixture).toMatchObject({ displayName: 'Mira', studentClass: 'Class 9', schoolName: 'Sample School', studentProfileCompleted: true })
    app.unmount()
    renderApp()
    await screen.findByLabelText('Note title')
    expect(screen.queryByRole('heading', { name: 'Welcome to Lumi.' })).not.toBeInTheDocument()
    await user.click(await screen.findByRole('button', { name: 'Open Coach Agent' }))
    expect(screen.getByRole('heading', { name: 'Hello, Mira.' })).toBeInTheDocument()
  })

  it('keeps entered student details after a failed save and supports retry', async () => {
    studentSettingsFixture = {}
    settingsSaveFails = true
    const user = userEvent.setup()
    renderApp()
    await user.type(await screen.findByLabelText('Name'), 'Mira')
    await user.type(screen.getByLabelText('Class'), '9')
    await user.type(screen.getByLabelText('School name'), 'Sample School')
    await user.click(screen.getByRole('button', { name: 'Start learning' }))
    expect(await screen.findByRole('alert')).toBeInTheDocument()
    expect(screen.getByLabelText('Name')).toHaveValue('Mira')
    expect(screen.queryByLabelText('Note title')).not.toBeInTheDocument()
    settingsSaveFails = false
    await user.click(screen.getByRole('button', { name: 'Start learning' }))
    await screen.findByLabelText('Note title')
  })

  it('edits the student profile through General settings', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Settings' }))
    const name = await screen.findByLabelText('Name')
    await user.clear(name)
    expect(screen.getByRole('button', { name: 'Save preferences' })).toBeDisabled()
    await user.type(name, 'Mira')
    await user.clear(screen.getByLabelText('Class'))
    await user.type(screen.getByLabelText('Class'), 'Class 9')
    await user.click(screen.getByRole('button', { name: 'Save preferences' }))
    await screen.findByText('Preferences saved.')
    await user.click(await screen.findByRole('button', { name: 'Open Coach Agent' }))
    expect(screen.getByRole('heading', { name: 'Hello, Mira.' })).toBeInTheDocument()
  })

  it('starts a fresh chat with profile context and keeps student prompts free of profile data', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(await screen.findByRole('button', { name: 'Open Coach Agent' }))
    await user.type(screen.getByLabelText('Message the Coach'), 'Explain gravity')
    await user.click(screen.getByRole('button', { name: 'Send message' }))
    await screen.findByText('Ready 1')
    await waitFor(() => expect(screen.getByRole('button', { name: 'New Chat' })).toBeEnabled())
    const group = screen.getByText('You', { selector: '.coach-speaker' })
    expect(group.parentElement?.querySelector('.coach-message')?.contains(group)).toBe(false)
    expect(screen.queryByRole('button', { name: 'Delete saved conversation' })).not.toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'New Chat' }))
    expect(screen.queryByText('Ready 1')).not.toBeInTheDocument()
    expect(screen.getByRole('heading', { name: 'Hello, Ananya.' })).toBeInTheDocument()
    await user.type(screen.getByLabelText('Message the Coach'), 'Explain light')
    await user.click(screen.getByRole('button', { name: 'Send message' }))
    await screen.findByText('Ready 2')
    const calls = fetchMock.mock.calls.filter(([url, init]) => (url as URL).pathname === '/api/assistant' && init?.method === 'POST')
    expect(calls).toHaveLength(2)
    for (const [, init] of calls) {
      const body = JSON.parse(String(init.body))
      expect(body.init).toEqual({})
      expect(body.data.message.content[0].text).toContain('"name":"Ananya"')
      expect(body.data.message.content[0].text).toContain('"studentClass":"Class 10"')
      expect(body.data.message.content[0].text).toContain('Address the student naturally by their name')
      expect(body.data.message.metadata.lumi.studentPrompt).not.toContain('Ananya')
    }
  })

  it('opens Recent chat options by right click and keyboard; cancels or deletes the selected saved conversation', async () => {
    localStorage.setItem('lumi.chat.recent', JSON.stringify([{ agentPath: '/api/assistant', sessionId: 'saved-chat', title: 'Gravity review' }]))
    localStorage.setItem('lumi.chat.session./api/assistant', 'saved-chat')
    const confirm = vi.spyOn(window, 'confirm').mockReturnValueOnce(false).mockReturnValueOnce(true)
    try {
      const user = userEvent.setup()
      renderApp()
      const row = await screen.findByRole('button', { name: 'Gravity review' })
      fireEvent.contextMenu(row, { clientX: 40, clientY: 200 })
      expect(screen.getByRole('menu', { name: 'Options for Gravity review' })).toBeInTheDocument()
      await user.click(screen.getByRole('menuitem', { name: 'Delete chat' }))
      expect(screen.getByRole('button', { name: 'Gravity review' })).toBeInTheDocument()
      expect(fetchMock.mock.calls.some(([url, init]) => (url as URL).pathname.includes('/api/agent-sessions/') && init?.method === 'DELETE')).toBe(false)
      row.focus()
      fireEvent.keyDown(row, { key: 'F10', shiftKey: true })
      expect(screen.getByRole('menuitem', { name: 'Open chat' })).toHaveFocus()
      await user.keyboard('{Escape}')
      expect(row).toHaveFocus()
      await user.click(screen.getByRole('button', { name: 'Options for Gravity review' }))
      await user.click(screen.getByRole('menuitem', { name: 'Delete chat' }))
      await waitFor(() => expect(screen.queryByRole('button', { name: 'Gravity review' })).not.toBeInTheDocument())
      expect(fetchMock).toHaveBeenCalledWith(expect.objectContaining({ pathname: '/api/agent-sessions/saved-chat' }), expect.objectContaining({ method: 'DELETE' }))
      expect(localStorage.getItem('lumi.chat.session./api/assistant')).toBeNull()
      expect(JSON.parse(localStorage.getItem('lumi.chat.recent')!)).toEqual([])
    } finally { confirm.mockRestore() }
  })

  it('keeps New Chat fresh after opening a saved chat and closing/reopening Coach', async () => {
    localStorage.setItem('lumi.chat.recent', JSON.stringify([{ agentPath: '/api/assistant', sessionId: 'saved-chat', title: 'Gravity review' }]))
    const user = userEvent.setup()
    renderApp()
    await user.click(await screen.findByRole('button', { name: 'Gravity review' }))
    await screen.findByText('Earlier explanation')
    await user.click(screen.getByRole('button', { name: 'New Chat' }))
    await user.click(screen.getByRole('button', { name: 'Close Coach' }))
    await user.click(screen.getByRole('button', { name: 'Open Coach Agent' }))
    expect(screen.queryByText('Earlier explanation')).not.toBeInTheDocument()
    expect(screen.getByRole('heading', { name: 'Hello, Ananya.' })).toBeInTheDocument()
    expect(localStorage.getItem('lumi.chat.session./api/assistant')).toBeNull()
    expect(screen.getByRole('button', { name: 'Gravity review' })).toBeInTheDocument()
  })

  it('keeps a saved chat when deletion fails', async () => {
    localStorage.setItem('lumi.chat.recent', JSON.stringify([{ agentPath: '/api/assistant', sessionId: 'saved-chat', title: 'Gravity review' }]))
    chatDeleteFails = true
    const confirm = vi.spyOn(window, 'confirm').mockReturnValue(true)
    try {
      const user = userEvent.setup()
      renderApp()
      await user.click(await screen.findByRole('button', { name: 'Options for Gravity review' }))
      await user.click(screen.getByRole('menuitem', { name: 'Delete chat' }))
      expect(await screen.findByRole('alert')).toHaveTextContent('Could not delete this chat')
      expect(screen.getByRole('button', { name: 'Gravity review' })).toBeInTheDocument()
      expect(JSON.parse(localStorage.getItem('lumi.chat.recent')!)).toHaveLength(1)
    } finally { confirm.mockRestore() }
  })

  it('opens the saved start page but yields to explicit navigation', async () => {
    startPageFixture = 'artifacts'
    const user = userEvent.setup()
    renderApp()
    expect(await screen.findByRole('heading', { name: 'Your learning, collected.' })).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'New note' }))
    expect(await screen.findByLabelText('Note title')).toBeInTheDocument()
  })

  it('renders workspace data through the Lumi API boundary', async () => {
    renderApp()
    expect(await screen.findByLabelText('Note title')).toHaveValue('Learning the senses')
    expect(screen.getByRole('button', { name: 'Research' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Nested' })).toBeInTheDocument()
  })

  it('makes Settings a primary, addressable route and keeps its section in browser history', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Settings' }))
    expect(await screen.findByRole('heading', { name: 'Settings' })).toBeInTheDocument()
    expect(window.location.pathname).toBe('/settings')

    await user.click(screen.getByRole('button', { name: 'Appearance' }))
    expect(await screen.findByLabelText('Theme')).toBeInTheDocument()
    expect(window.location.search).toBe('?section=appearance')

    window.history.replaceState({}, '', '/settings')
    window.dispatchEvent(new PopStateEvent('popstate'))
    expect(await screen.findByRole('heading', { name: 'General' })).toBeInTheDocument()
  })

  it('collapses nested folders without losing them from workspace data', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    expect(screen.getByRole('button', { name: 'Nested' })).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Collapse Research' }))
    expect(screen.queryByRole('button', { name: 'Nested' })).not.toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Expand Research' }))
    expect(screen.getByRole('button', { name: 'Nested' })).toBeInTheDocument()
  })

  it('shows a live Home summary and navigates into recent notes', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Home' }))
    expect(await screen.findByRole('heading', { name: 'Make room for curiosity.' })).toBeInTheDocument()
    const recentNote = document.querySelector('.home-note-grid button')
    expect(recentNote).not.toBeNull()
    await user.click(recentNote!)
    expect(await screen.findByLabelText('Note title')).toHaveValue('Learning the senses')
  })

  it('keeps the removed Graph view out of primary navigation', async () => {
    renderApp()
    await screen.findByLabelText('Note title')
    expect(screen.queryByRole('button', { name: 'Graph' })).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Canvas' })).toBeInTheDocument()
  })

  it('attaches and detaches notes on an existing canvas through the service', async () => {
    canvasFixtures = [{ id: 'canvas-1', title: 'Biology', description: 'Cell studies', noteIds: ['note-1'], positions: {}, quizzes: [], updatedAt: '2026-10-19T00:00:00.000Z' }]
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Canvas' }))
    expect(await screen.findByRole('heading', { name: 'Canvas' })).toBeInTheDocument()
    await user.click(screen.getByText('Biology').closest('button')!)
    expect(within(await screen.findByLabelText('Biology board')).getByText('Learning the senses')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Add notes to canvas' }))
    await user.click(screen.getByText('Attention').closest('button')!)
    const canvasUpdateSent = (noteIds: string[], positions: Record<string, unknown>) => fetchMock.mock.calls.some(([request, init]) => request instanceof URL && request.pathname === '/api/canvases/canvas-1' && init?.method === 'PUT' && JSON.stringify(JSON.parse(String(init.body))) === JSON.stringify({ noteIds, positions, connections: [] }))
    await waitFor(() => expect(canvasUpdateSent(['note-1', 'note-2'], { 'note-1': { x: 120, y: 130 }, 'note-2': { x: 510, y: 130 } })).toBe(true))
    expect(within(screen.getByLabelText('Biology board')).getByText('Attention')).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Remove Attention from canvas' }))
    await waitFor(() => expect(canvasUpdateSent(['note-1'], { 'note-1': { x: 120, y: 130 } })).toBe(true))
    await waitFor(() => expect(canvasFixtures[0].noteIds).toEqual(['note-1']))
  })

  it('opens and closes the Coach drawer with automatic specialist routing', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(await screen.findByRole('button', { name: 'Open Coach Agent' }))
    expect(screen.getByRole('heading', { name: 'Hello, Ananya.' })).toBeInTheDocument()
    expect(screen.queryByRole('combobox', { name: 'Choose Coach agent' })).not.toBeInTheDocument()
    expect(screen.getByText('Lumi automatically routes each request to the right specialist.')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Close Coach Agent' }))
    expect(screen.queryByRole('heading', { name: 'Hello, Ananya.' })).not.toBeInTheDocument()
  })

  it('ignores malformed or unknown Coach session metadata in browser storage', async () => {
    window.localStorage.setItem('lumi.chat.active-agent', 'https://untrusted.example/agent')
    window.localStorage.setItem('lumi.chat.recent', JSON.stringify([
      { agentPath: 'https://untrusted.example/agent', sessionId: 'session-1', title: 'Untrusted' },
      { agentPath: '/api/assistant', sessionId: '../bad-id', title: 'Invalid ID' },
    ]))
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(await screen.findByRole('button', { name: 'Open Coach Agent' }))
    expect(screen.queryByRole('combobox', { name: 'Choose Coach agent' })).not.toBeInTheDocument()
    expect(screen.getByText('Lumi automatically routes each request to the right specialist.')).toBeInTheDocument()
    expect(screen.queryByRole('combobox', { name: 'Recent conversations' })).not.toBeInTheDocument()
  })

  it('sends Coach turns through the orchestrator, which routes to specialists', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(await screen.findByRole('button', { name: 'Open Coach Agent' }))
    const message = screen.getByLabelText('Message the Coach')
    await user.type(message, 'Please make a quiz and review my progress.')
    await user.click(screen.getByRole('button', { name: 'Send message' }))
    expect(await screen.findByText('Ready 1')).toBeInTheDocument()
    await waitFor(() => expect(fetchMock).toHaveBeenCalledWith(
      expect.objectContaining({ pathname: '/api/assistant' }),
      expect.objectContaining({ method: 'POST', headers: expect.objectContaining({ Accept: 'text/event-stream' }) }),
    ))
    expect(fetchMock).not.toHaveBeenCalledWith(expect.objectContaining({ pathname: '/api/agents/tester' }), expect.anything())
    expect(fetchMock).not.toHaveBeenCalledWith(expect.objectContaining({ pathname: '/api/agents/reviewer' }), expect.anything())
  })

  it('renders formatted Coach replies as Markdown', async () => {
    coachReplyFixture = 'To remember rules:\n\n* **Think** about slope.\n* Picture a hill.'
    const user = userEvent.setup()
    const { container } = renderApp()
    await screen.findByLabelText('Note title')
    await user.click(await screen.findByRole('button', { name: 'Open Coach Agent' }))
    await user.type(screen.getByLabelText('Message the Coach'), 'How can I remember slope rules?')
    await user.click(screen.getByRole('button', { name: 'Send message' }))

    const boldText = await screen.findByText('Think', { selector: 'strong' })
    expect(boldText).toBeInTheDocument()
    expect(screen.getByText('Picture a hill.')).toBeInTheDocument()
    expect(container.textContent).not.toContain('**Think**')
  })

  it('creates the same seeded note as the existing Lumi client', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'New note' }))

    await waitFor(() => {
      expect(fetchMock).toHaveBeenCalledWith(
        expect.objectContaining({ pathname: '/api/notes' }),
        expect.objectContaining({ method: 'POST', body: JSON.stringify({ title: 'Untitled note', content: '' }) }),
      )
    })
  })

  it('creates folders through the existing folder endpoint', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Create folder' }))
    await user.type(screen.getByLabelText('New folder name'), 'Biology')
    await user.click(screen.getByRole('button', { name: 'Add' }))

    await waitFor(() => expect(fetchMock).toHaveBeenCalledWith(
      expect.objectContaining({ pathname: '/api/folders' }),
      expect.objectContaining({ method: 'POST', body: JSON.stringify({ name: 'Biology' }) }),
    ))
  })

  it('moves a note to a folder through the existing update endpoint', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.selectOptions(screen.getByLabelText('Move note to folder'), 'folder-1')
    await user.click(screen.getByRole('button', { name: 'Save now' }))

    await waitFor(() => expect(fetchMock).toHaveBeenCalledWith(
      expect.objectContaining({ pathname: '/api/notes/note-1' }),
      expect.objectContaining({ method: 'PUT', body: expect.stringContaining('"folderId":"folder-1"') }),
    ))
  })

  it('searches through the existing note search endpoint', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: /Search/ }))
    const dialog = screen.getByRole('dialog', { name: 'Search your notes' })
    const search = within(dialog).getByLabelText('Search titles and content')
    await user.type(search, 'attention')

    await waitFor(() => {
      expect(fetchMock).toHaveBeenCalledWith(
        expect.objectContaining({ pathname: '/api/search', search: '?q=attention' }),
        expect.anything(),
      )
    })
    await user.click(within(dialog).getByRole('button', { name: /Learning the senses/ }))
    expect(screen.queryByRole('dialog', { name: 'Search your notes' })).not.toBeInTheDocument()
  })

  it('loads and filters the durable artifacts library', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Artifacts' }))
    expect(await screen.findByRole('heading', { name: 'Your learning, collected.' })).toBeInTheDocument()
    expect(await screen.findByRole('button', { name: /Attention cues/ })).toBeInTheDocument()
    await user.type(screen.getByLabelText('Search artifacts'), 'memory')
    expect(screen.queryByRole('button', { name: /Attention cues/ })).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: /The memory loop/ })).toBeInTheDocument()
  })

  it('persists app preferences through the Dart settings endpoint', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Settings' }))
    await user.click(screen.getByRole('button', { name: 'Learning & coach' }))
    const style = await screen.findByLabelText('Teaching style')
    await user.selectOptions(style, 'socratic')
    await user.click(screen.getByRole('button', { name: 'Save preferences' }))
    await waitFor(() => expect(fetchMock).toHaveBeenCalledWith(
      expect.objectContaining({ pathname: '/api/application-settings' }),
      expect.objectContaining({ method: 'PUT', body: JSON.stringify({ teachingStyle: 'socratic' }) }),
    ))
    expect(await screen.findByText('Preferences saved.')).toBeInTheDocument()
  })

  it('loads the backend-host hardware report without claiming runtime verification', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Settings' }))
    await user.click(screen.getByRole('button', { name: 'Hardware report' }))
    expect(await screen.findByText(/Test CPU/)).toBeInTheDocument()
    expect(screen.getByText(/Device detected; runtime not verified/)).toBeInTheDocument()
  })

  it('loads local profile and learning data through privacy settings', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Settings' }))
    await user.click(screen.getByRole('button', { name: 'Privacy & data' }))
    expect(await screen.findByText('I prefer short examples')).toBeInTheDocument()
    expect(await screen.findByText(/1 learning events/)).toBeInTheDocument()
  })

  it('adds an explicit learning preference through the local profile endpoint', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Settings' }))
    await user.click(screen.getByRole('button', { name: 'Privacy & data' }))
    await user.type(await screen.findByLabelText('Remember a preference'), 'I prefer weekly reviews')
    await user.click(screen.getByRole('button', { name: 'Remember' }))
    expect(await screen.findByText('I prefer weekly reviews')).toBeInTheDocument()
    expect(fetchMock).toHaveBeenCalledWith(expect.objectContaining({ pathname: '/api/profile/preferences' }), expect.objectContaining({ method: 'POST', body: JSON.stringify({ preference: 'I prefer weekly reviews' }) }))
  })

  it('surfaces the backend preference policy when a profile preference is rejected', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Settings' }))
    await user.click(screen.getByRole('button', { name: 'Privacy & data' }))
    await user.type(await screen.findByLabelText('Remember a preference'), 'Use weekly reviews')
    await user.click(screen.getByRole('button', { name: 'Remember' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Save only a clear learning or communication preference.')
  })

  it('keeps provider keys out of browser storage and mutation state', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Settings' }))
    await user.click(screen.getByRole('button', { name: 'AI & models' }))
    await user.selectOptions(await screen.findByLabelText('Provider'), 'gemini')
    const key = await screen.findByLabelText(/API key/)
    await user.type(key, 'ephemeral-test-key')
    await user.click(screen.getByRole('button', { name: 'Test connection' }))
    await waitFor(() => expect(fetchMock).toHaveBeenCalledWith(
      expect.objectContaining({ pathname: '/api/settings/test' }),
      expect.objectContaining({ method: 'POST', body: JSON.stringify({ provider: 'gemini', model: 'gemini-2.5-flash', baseUrl: 'https://generativelanguage.googleapis.com/v1beta', apiKey: 'ephemeral-test-key' }) }),
    ))
    expect(await screen.findByText('Connection verified.')).toBeInTheDocument()
    expect(window.localStorage.getItem('lumi.chat.recent') ?? '').not.toContain('ephemeral-test-key')
  })

  it('previews safe Markdown and renders a validated local attachment path', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    const body = screen.getByLabelText('Note body')
    await user.clear(body)
    await user.type(body, '# Study guide{Enter}{Enter}- **Recall** ideas{Enter}! [diagram](/api/attachments/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.png)')
    await user.click(screen.getByRole('button', { name: 'Preview Markdown' }))
    expect(screen.getByRole('heading', { name: 'Study guide' })).toBeInTheDocument()
    expect(screen.getByText('Recall')).toBeInTheDocument()
  })

  it('renders Markdown tables and opens notes from wiki references', async () => {
    const user = userEvent.setup()
    renderApp()
    const body = await screen.findByLabelText('Note body')
    await user.clear(body)
    fireEvent.change(body, { target: { value: '| Item | Detail |\n| --- | :---: |\n| Focus | Cue |\n\nSee [[Attention]]' } })
    await user.click(screen.getByRole('button', { name: 'Preview Markdown' }))

    const table = screen.getByRole('table')
    expect(within(table).getByRole('columnheader', { name: 'Item' })).toBeInTheDocument()
    expect(within(table).getByRole('columnheader', { name: 'Detail' })).toHaveStyle({ textAlign: 'center' })
    expect(within(table).getByRole('cell', { name: 'Focus' })).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Open note: Attention' }))
    expect(await screen.findByLabelText('Note title')).toHaveValue('Attention')
  })

  it('renders inline and block math locally with accessible MathML output', async () => {
    const user = userEvent.setup()
    renderApp()
    const body = await screen.findByLabelText('Note body')
    fireEvent.change(body, { target: { value: String.raw`Inline $E = mc^2$ formula.

$$
\int_0^1 x^2 \, dx = \frac{1}{3}
$$` } })
    await user.click(screen.getByRole('button', { name: 'Preview Markdown' }))

    await waitFor(() => {
      expect(document.querySelector('.markdown-math-inline .katex')).toBeInTheDocument()
      expect(document.querySelector('.markdown-math-block .katex-display')).toBeInTheDocument()
      expect(document.querySelectorAll('.katex-mathml math')).toHaveLength(2)
    })
  })

  it('plays saved flashcards and checks quiz answers through the artifact endpoint', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Artifacts' }))
    await user.click(await screen.findByRole('button', { name: /Attention cues/ }))
    expect(screen.getByText('What directs attention?')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Reveal answer' }))
    expect(screen.getByText('A cue that signals what to notice.')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Close artifact details' }))
    await user.click(screen.getByRole('button', { name: /The memory loop/ }))
    await user.click(screen.getByRole('radio', { name: /Retrieval practice/ }))
    await user.click(screen.getByRole('button', { name: 'Check answers' }))

    await waitFor(() => expect(fetchMock).toHaveBeenCalledWith(
      expect.objectContaining({ pathname: '/api/artifacts/artifact-2/attempt' }),
      expect.objectContaining({ method: 'POST', body: JSON.stringify({ answers: [0] }) }),
    ))
    expect(await screen.findByText('Score: 1 / 1')).toBeInTheDocument()
    expect(screen.getByText(/Retrieval practice strengthens recall/)).toBeInTheDocument()
  })

  it('saves a note through the existing update endpoint', async () => {
    const user = userEvent.setup()
    renderApp()
    const title = await screen.findByLabelText('Note title')
    await user.clear(title)
    await user.type(title, 'Saved from React')
    await user.click(screen.getByRole('button', { name: 'Save now' }))

    await waitFor(() => {
      expect(fetchMock).toHaveBeenCalledWith(
        expect.objectContaining({ pathname: '/api/notes/note-1' }),
        expect.objectContaining({ method: 'PUT', body: expect.stringContaining('Saved from React') }),
      )
    })
    await waitFor(() => expect(screen.getByText('Saved locally')).toBeInTheDocument())
  })
  it('creates a focus timer through its dialog, persists it across navigation and reload, and guards leaving until switched off', async () => {
    const user = userEvent.setup()
    const modal = vi.fn(function (this: HTMLDialogElement) { this.setAttribute('open', '') })
    Object.defineProperty(HTMLDialogElement.prototype, 'showModal', { configurable: true, value: modal })
    const close = vi.fn(function (this: HTMLDialogElement) { this.removeAttribute('open') })
    Object.defineProperty(HTMLDialogElement.prototype, 'close', { configurable: true, value: close })
    const requestFullscreen = vi.fn().mockResolvedValue(undefined)
    Object.defineProperty(document.documentElement, 'requestFullscreen', { configurable: true, value: requestFullscreen })
    try {
      const app = renderApp()
      await user.click(await screen.findByRole('button', { name: 'Focus mode' }))
      expect(window.location.pathname).toBe('/focus')
      await user.click(screen.getByRole('button', { name: /Quiet night/ }))
      await user.click(screen.getByRole('button', { name: 'Create Timer' }))
      const dialog = screen.getByRole('dialog', { name: 'Create Timer' })
      await user.type(within(dialog).getByLabelText('What are you focusing on?'), 'Biology revision')
      await user.click(within(dialog).getByRole('button', { name: '50 min' }))
      await user.click(within(dialog).getByRole('button', { name: 'Start focus session' }))
      expect(requestFullscreen).toHaveBeenCalledWith({ navigationUI: 'hide' })
      expect(screen.queryByRole('status', { name: 'Focus reminder' })).not.toBeInTheDocument()
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
      expect(document.documentElement).toHaveAttribute('data-focus-theme', 'midnight')
      expect(document.documentElement).toHaveAttribute('data-theme', 'dark')
      expect(screen.getByRole('timer')).toHaveTextContent('50:00')
      expect(screen.getByRole('region', { name: 'Floating focus timer' })).toHaveAttribute('data-focus-theme', 'midnight')
      fireEvent.keyDown(screen.getByRole('button', { name: 'Move focus timer (drag or use arrow keys)' }), { key: 'ArrowDown' })
      expect(screen.getByRole('region', { name: 'Floating focus timer' })).toHaveStyle({ top: '20px' })
      await user.click(screen.getByRole('button', { name: 'Reset timer widget position' }))
      expect(screen.getByRole('region', { name: 'Floating focus timer' }).style.top).toBe('')
      await user.click(screen.getByRole('button', { name: 'Pause timer' }))
      expect(screen.getByText('Taking a breath')).toBeInTheDocument()
      const leaving = new Event('beforeunload', { cancelable: true })
      window.dispatchEvent(leaving)
      expect(leaving.defaultPrevented).toBe(true)
      const link = document.createElement('a')
      link.href = 'https://example.com/'
      document.body.append(link)
      const click = new MouseEvent('click', { bubbles: true, cancelable: true })
      fireEvent(link, click)
      expect(click.defaultPrevented).toBe(true)
      expect(screen.getByRole('status', { name: 'Focus reminder' })).toHaveTextContent('switch off the timer')
      link.remove()
      await user.click(screen.getByRole('button', { name: 'Home' }))
      expect(screen.getByRole('region', { name: 'Floating focus timer' })).toBeInTheDocument()
      expect(screen.queryByRole('button', { name: 'Switch off timer' })).not.toBeInTheDocument()
      app.unmount()
      renderApp()
      await user.click(await screen.findByRole('button', { name: 'Manage' }))
      expect(screen.getByRole('timer')).toHaveTextContent('50:00')
      expect(screen.getByText('Taking a breath')).toBeInTheDocument()
      await user.click(screen.getByRole('button', { name: 'Resume timer' }))
      await user.click(screen.getByRole('button', { name: 'Switch off timer' }))
      expect(screen.queryByRole('region', { name: 'Floating focus timer' })).not.toBeInTheDocument()
      const afterStop = new Event('beforeunload', { cancelable: true })
      window.dispatchEvent(afterStop)
      expect(afterStop.defaultPrevented).toBe(false)
      expect(localStorage.getItem('lumi.focus.v1')).toBeNull()
      expect(document.documentElement).not.toHaveAttribute('data-focus-theme')
      expect(document.documentElement).toHaveAttribute('data-theme', 'light')
    } finally { Reflect.deleteProperty(HTMLDialogElement.prototype, 'showModal'); Reflect.deleteProperty(HTMLDialogElement.prototype, 'close'); Reflect.deleteProperty(document.documentElement, 'requestFullscreen') }
  })

  it('executes a request-bound Coach focus action once and refuses to replace an active timer', async () => {
    const user = userEvent.setup()
    coachReplyFixture = (init) => {
      const request = JSON.parse(String(init?.body)).data.message.content[0].text as string
      const requestId = request.match(/"requestId":"([^"]+)"/)?.[1]
      return 'Let us focus.\n```lumi-focus\n' + JSON.stringify({ requestId, action: 'start', minutes: 25, label: 'Biology', theme: 'sand' }) + '\n```'
    }
    renderApp()
    await user.click(await screen.findByRole('button', { name: 'Open Coach Agent' }))
    await user.type(screen.getByLabelText('Message the Coach'), 'Start a 25 minute focus timer for biology')
    await user.click(screen.getByRole('button', { name: 'Send message' }))
    await screen.findByText(/Focus timer started for 25 minutes/)
    expect(window.location.pathname).toBe('/focus')
    expect(screen.getByRole('timer')).toHaveTextContent('25:00')
    expect(screen.getByRole('region', { name: 'Floating focus timer' })).toHaveAttribute('data-focus-theme', 'sand')
    const session = localStorage.getItem('lumi.focus.v1')
    await user.type(screen.getByLabelText('Message the Coach'), 'Start another 25 minute focus timer')
    await user.click(screen.getByRole('button', { name: 'Send message' }))
    await screen.findByText(/A focus timer is already active/)
    expect(localStorage.getItem('lumi.focus.v1')).toBe(session)
  })

  it('restores the workspace theme at expiry and shows a completion popup until the session is ended', async () => {
    const showModal = vi.fn(function (this: HTMLDialogElement) { this.setAttribute('open', ''); this.querySelector<HTMLElement>('button')?.focus() })
    const close = vi.fn(function (this: HTMLDialogElement) { this.removeAttribute('open') })
    Object.defineProperty(HTMLDialogElement.prototype, 'showModal', { configurable: true, value: showModal })
    Object.defineProperty(HTMLDialogElement.prototype, 'close', { configurable: true, value: close })
    const requestFullscreen = vi.fn().mockResolvedValue(undefined)
    const exitFullscreen = vi.fn().mockResolvedValue(undefined)
    Object.defineProperty(document.documentElement, 'requestFullscreen', { configurable: true, value: requestFullscreen })
    Object.defineProperty(document, 'exitFullscreen', { configurable: true, value: exitFullscreen })
    try {
      localStorage.setItem('lumi.focus.theme', 'midnight')
      localStorage.setItem('lumi.focus.v1', JSON.stringify({ durationSeconds: 60, remainingSeconds: 60, endsAt: Date.now() + 60_000, status: 'running', label: 'Study' }))
      renderApp()
      await screen.findByRole('button', { name: 'Enter fullscreen' })
      expect(document.documentElement).toHaveAttribute('data-focus-theme', 'midnight')
      await userEvent.click(screen.getByRole('button', { name: 'Enter fullscreen' }))
      expect(requestFullscreen).toHaveBeenCalledWith({ navigationUI: 'hide' })
      Object.defineProperty(document, 'fullscreenElement', { configurable: true, value: document.documentElement })
      fireEvent(document, new Event('fullscreenchange'))
      expect(screen.queryByRole('button', { name: 'Enter fullscreen' })).not.toBeInTheDocument()
      // Simulate waking up after the deadline without waiting for a real minute.
      const now = vi.spyOn(Date, 'now').mockReturnValue(Date.now() + 120_000)
      fireEvent(document, new Event('visibilitychange'))
      now.mockRestore()
      const popup = await screen.findByRole('dialog', { name: 'Your time is over.' })
      expect(document.documentElement).not.toHaveAttribute('data-focus-theme')
      expect(document.documentElement).toHaveAttribute('data-theme', 'light')
      expect(within(popup).getByRole('button', { name: 'End Focus Session' })).toHaveFocus()
      await userEvent.click(within(popup).getByRole('button', { name: 'End Focus Session' }))
      expect(screen.queryByRole('dialog', { name: 'Your time is over.' })).not.toBeInTheDocument()
      expect(screen.queryByRole('region', { name: 'Floating focus timer' })).not.toBeInTheDocument()
      expect(exitFullscreen).toHaveBeenCalledOnce()
      expect(localStorage.getItem('lumi.focus.v1')).toBeNull()
    } finally {
      cleanup()
      Reflect.deleteProperty(HTMLDialogElement.prototype, 'showModal')
      Reflect.deleteProperty(HTMLDialogElement.prototype, 'close')
      Reflect.deleteProperty(document.documentElement, 'requestFullscreen')
      Reflect.deleteProperty(document, 'exitFullscreen')
      Reflect.deleteProperty(document, 'fullscreenElement')
    }
  })

  it.each([false, true])('opens an agent-created canvas, including when supporting notes are created: %s', async (withNotes) => {
    coachReplyFixture = () => {
      createdAgentNote = withNotes
      canvasFixtures.push({ id: 'agent-canvas', title: 'Quantum study board', description: '', noteIds: withNotes ? ['agent-note'] : [], positions: {}, quizzes: [], updatedAt: '2026-10-25T00:00:00.000Z' })
      return 'Your canvas is ready.'
    }
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(await screen.findByRole('button', { name: 'Open Coach Agent' }))
    await user.type(screen.getByLabelText('Message the Coach'), 'Create a quantum study canvas')
    await user.click(screen.getByRole('button', { name: 'Send message' }))
    expect(await screen.findByLabelText('Quantum study board board')).toBeInTheDocument()
    expect(window.location.pathname + window.location.search).toBe('/canvas?file=agent-canvas')
    expect(screen.getByLabelText('Message the Coach')).toBeInTheDocument()
    if (withNotes) expect(within(screen.getByLabelText('Quantum study board board')).getByText('Quantum Mechanics')).toBeInTheDocument()
  })

  it('keeps the current screen when the agent creates nothing', async () => {
    window.history.replaceState({}, '', '/home')
    coachReplyFixture = 'Here is an explanation.'
    const user = userEvent.setup()
    renderApp()
    await user.click(await screen.findByRole('button', { name: 'Open Coach Agent' }))
    await user.type(screen.getByLabelText('Message the Coach'), 'Explain quantum mechanics')
    await user.click(screen.getByRole('button', { name: 'Send message' }))
    await screen.findByText('Here is an explanation.')
    await user.type(screen.getByLabelText('Message the Coach'), 'Next question')
    await waitFor(() => expect(screen.getByRole('button', { name: 'Send message' })).toBeEnabled())
    expect(window.location.pathname).toBe('/home')
  })

  it('refreshes agent-created notes and resolves their Canvas cards without a page reload', async () => {
    canvasFixtures = [{ id: 'canvas-1', title: 'Existing study board', description: '', noteIds: ['agent-note'], positions: {}, quizzes: [], updatedAt: '2026-10-24T00:00:00.000Z' }]
    coachReplyFixture = () => { createdAgentNote = true; return 'Created your Quantum Mechanics note.' }
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(await screen.findByRole('button', { name: 'Open Coach Agent' }))
    await user.type(screen.getByLabelText('Message the Coach'), 'Create a note and write a brief para about Quantum Mechanics')
    await user.click(screen.getByRole('button', { name: 'Send message' }))
    await screen.findByText('Created your Quantum Mechanics note.')
    await waitFor(() => expect(screen.getByLabelText('Note title')).toHaveValue('Quantum Mechanics'))
    expect(window.location.search).toBe('?note=agent-note')
    await user.click(screen.getByRole('button', { name: 'Close Coach Agent' }))
    await user.click(screen.getByRole('button', { name: 'Canvas' }))
    await user.click(await screen.findByText('Existing study board'))
    const board = await screen.findByLabelText('Existing study board board')
    expect(await within(board).findByText('Quantum Mechanics')).toBeInTheDocument()
    expect(within(board).getByText('Quantum mechanics describes microscopic states and probabilities.')).toBeInTheDocument()
    expect(within(board).queryByText('No preview available.')).not.toBeInTheDocument()
  })

})
