import { useEffect, useRef, useState, type KeyboardEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowUp, Bot, Plus, X } from 'lucide-react'
import { getWorkspace, getCanvases, loadAgentConversation, lumiQueryKeys, streamAgentMessage, type LumiApplicationSettings, type LumiCanvas, type LumiChatMessage, type LumiNote } from '../../lib/lumi-api'
import { MarkdownPreview } from '../notes/MarkdownPreview'
import { focusActionInstructions, readFocusAgentAction, withoutFocusCommands, type FocusAgentAction } from '../focus/focus-agent-action'
import { PanelWidthSlider } from '../layout/PanelWidthSlider'
import { CHAT_DELETED_EVENT, isSessionId, persistRecentChats, readRecentChats } from './recent-chats'
import { readStudentProfile, studentProfileContext } from '../profile/student-profile'
import './coach.css'

const assistant = { path: '/api/assistant', label: 'Lumi Coach' }
const defaultPrompts = ['Explain this simply', 'Quiz me one question at a time', 'Find related notes']
export function CoachPanel({ note, canvas, notes = [], settings = {}, openSessionId, openSessionRequest, onStartFocus, onOpenNote, onOpenCanvas, onNewChat, onClose }: { note?: LumiNote; canvas?: LumiCanvas; notes?: LumiNote[]; settings?: LumiApplicationSettings; openSessionId?: string | null; openSessionRequest?: number; onStartFocus?: (action: FocusAgentAction) => boolean; onOpenNote?: (note: LumiNote) => void; onOpenCanvas?: (canvas: LumiCanvas) => void; onNewChat?: () => void; onClose: () => void }) {
  const drawer = useRef<HTMLElement>(null)
  const composer = useRef<HTMLTextAreaElement>(null)
  const queryClient = useQueryClient()
  const [sessionId, setSessionId] = useState<string | null>(() => {
    if (isSessionId(openSessionId)) return openSessionId
    const stored = localStorage.getItem(`lumi.chat.session.${assistant.path}`)
    return isSessionId(stored) ? stored : null
  })
  const [messages, setMessages] = useState<LumiChatMessage[]>([])
  const [draft, setDraft] = useState('')
  const [error, setError] = useState<string | null>(null)
  const agent = assistant
  const agentPath = assistant.path
  const sessionKey = `lumi.chat.session.${assistant.path}`
  const history = useQuery({ queryKey: lumiQueryKeys.agentConversation(assistant.path, sessionId ?? ''), queryFn: () => loadAgentConversation(assistant.path, sessionId!), enabled: Boolean(sessionId) && messages.length === 0, staleTime: Infinity, retry: false })

  useEffect(() => {
    if (!sessionId || messages.length > 0 || !history.error || !/\b404\b/.test(String(history.error))) return
    let cancelled = false
    queueMicrotask(() => {
      if (cancelled) return
      localStorage.removeItem(sessionKey)
      setSessionId(null)
      setMessages([])
      persistRecentChats(readRecentChats().filter((item) => item.sessionId !== sessionId))
      setError('That saved conversation no longer exists and was removed from Recent conversations.')
    })
    return () => { cancelled = true }
  }, [history.error, messages.length, sessionId, sessionKey])

  useEffect(() => {
    if (!openSessionId) return
    localStorage.setItem(sessionKey, openSessionId)
    setSessionId(openSessionId)
    setMessages([])
    setError(null)
  }, [openSessionId, openSessionRequest, sessionKey])

  useEffect(() => {
    const onDeleted = (event: Event) => {
      if ((event as CustomEvent<string>).detail !== sessionId) return
      setSessionId(null)
      setMessages([])
      setDraft('')
      setError(null)
    }
    window.addEventListener(CHAT_DELETED_EVENT, onDeleted)
    return () => window.removeEventListener(CHAT_DELETED_EVENT, onDeleted)
  }, [sessionId])

  useEffect(() => {
    const previous = document.activeElement
    composer.current?.focus()
    return () => { if (previous instanceof HTMLElement && previous.isConnected) previous.focus() }
  }, [])

  function handleDrawerKey(event: KeyboardEvent<HTMLElement>) {
    if (event.key === 'Escape') { event.preventDefault(); onClose(); return }
    if (event.key !== 'Tab') return
    const controls = [...drawer.current!.querySelectorAll<HTMLElement>('button:not(:disabled), input:not(:disabled), textarea:not(:disabled), select:not(:disabled), a[href]')]
    const first = controls[0], last = controls.at(-1)
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus() }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus() }
  }

  const student = readStudentProfile(settings)
  const displayMessages = messages.length ? messages : history.data ?? []

  const send = useMutation({
    mutationFn: async (prompt: string) => {
      const [workspaceBefore, canvasesBefore] = await Promise.all([
        queryClient.fetchQuery({ queryKey: lumiQueryKeys.workspace, queryFn: getWorkspace }),
        queryClient.fetchQuery({ queryKey: lumiQueryKeys.canvases, queryFn: getCanvases }),
      ])
      const previousNoteIds = new Set(workspaceBefore.notes.map((item) => item.id))
      const previousCanvasIds = new Set(canvasesBefore.map((item) => item.id))
      const canvasContext = canvas ? (() => {
        const linked = canvas.noteIds.map((id) => notes.find((item) => item.id === id)).filter((item): item is LumiNote => Boolean(item))
        const links = (canvas.connections ?? []).map((edge) => `${notes.find((item) => item.id === edge.sourceId)?.title ?? edge.sourceId} → ${notes.find((item) => item.id === edge.targetId)?.title ?? edge.targetId}`)
        return `Use the currently open canvas as context.\n\nCanvas: ${canvas.title}\n${canvas.description ? `Description: ${canvas.description}\n` : ''}Notes on canvas:\n${linked.map((item) => `- ${item.title}\n${item.content.slice(0, 1800)}`).join('\n') || '(no notes attached)'}\n\nCanvas connections:\n${links.join('\n') || '(no connections yet)'}`
      })() : ''
      const noteContext = note ? `Use this open note if relevant.\n\nNote: ${note.title}\n${note.content}` : ''
      const context = [studentProfileContext(settings), canvasContext, noteContext].filter(Boolean).join('\n\n')
      const requestId = onStartFocus && /\b(?:focus|timer|pomodoro)\b/i.test(prompt) ? Array.from(crypto.getRandomValues(new Uint8Array(16)), (byte) => byte.toString(16).padStart(2, '0')).join('') : null
      const capability = requestId ? focusActionInstructions(requestId) : ''
      const contextualPrompt = capability ? [capability, context, `Request: ${prompt}`].filter(Boolean).join('\n\n') : context ? `${context}\n\nRequest: ${prompt}` : prompt
      const result = await streamAgentMessage(agentPath, sessionId, contextualPrompt, (partial) => {
        setMessages((current) => [...current.slice(0, -1), { role: 'assistant', text: withoutFocusCommands(partial) }])
      }, prompt)
      return { ...result, previousNoteIds, previousCanvasIds, focusAction: requestId ? readFocusAgentAction(result.text, requestId) : null }
    },
    onMutate: (prompt) => {
      const previousMessages = displayMessages
      setError(null)
      setMessages([...previousMessages, { role: 'user', text: prompt }, { role: 'assistant', text: '' }])
      return { previousMessages }
    },
    onSuccess: async (result, prompt, context) => {
      if (result.sessionId) {
        localStorage.setItem(sessionKey, result.sessionId)
        setSessionId(result.sessionId)
        const current = readRecentChats()
        const next = [{ agentPath, sessionId: result.sessionId, title: current.find((item) => item.agentPath === agentPath && item.sessionId === result.sessionId)?.title ?? prompt.slice(0, 72), updatedAt: new Date().toISOString() }, ...current.filter((item) => item.agentPath !== agentPath || item.sessionId !== result.sessionId)].slice(0, 12)
        persistRecentChats(next)
      }
      const started = result.focusAction ? onStartFocus?.(result.focusAction) : undefined
      const actionMessage = result.focusAction ? started
        ? `Focus timer started for ${result.focusAction.minutes} minutes. Open Focus mode to manage or switch it off. Fullscreen is available there.`
        : 'A focus timer is already active. Go to Focus mode and switch it off before starting another.' : ''
      const reply = [withoutFocusCommands(result.text), actionMessage].filter(Boolean).join('\n\n')
      const completedMessages: LumiChatMessage[] = [...(context?.previousMessages ?? []), { role: 'user', text: prompt }, { role: 'assistant', text: reply || 'The agent completed without a text response.' }]
      setMessages(completedMessages)
      if (result.sessionId) queryClient.setQueryData(lumiQueryKeys.agentConversation(agentPath, result.sessionId), completedMessages)
      // Refresh the persisted objects before opening them so cards and the editor
      // can resolve their content immediately, including notes in new canvases.
      const refreshed = await Promise.allSettled([
        queryClient.fetchQuery({ queryKey: lumiQueryKeys.workspace, queryFn: getWorkspace }),
        queryClient.fetchQuery({ queryKey: lumiQueryKeys.canvases, queryFn: getCanvases }),
      ])
      const newCanvas = refreshed[1].status === 'fulfilled'
        ? refreshed[1].value.findLast((item) => !result.previousCanvasIds.has(item.id)) : undefined
      const newNote = refreshed[0].status === 'fulfilled'
        ? refreshed[0].value.notes.findLast((item) => !result.previousNoteIds.has(item.id)) : undefined
      if (newCanvas) onOpenCanvas?.(newCanvas)
      else if (newNote) onOpenNote?.(newNote)
      await Promise.allSettled([
        lumiQueryKeys.artifacts,
        lumiQueryKeys.graph, lumiQueryKeys.profile, lumiQueryKeys.learningRecord,
        lumiQueryKeys.diagnostics, ['note-search'],
      ].map((queryKey) => queryClient.invalidateQueries({ queryKey })))
    },
    onError: (reason) => { setError(reason instanceof Error ? reason.message : 'The Coach could not complete that request.'); setMessages((current) => current.at(-1)?.role === 'assistant' && !current.at(-1)?.text ? current.slice(0, -1) : current) },
  })

  async function startNew() {
    if (send.isPending) return
    onNewChat?.()
    localStorage.removeItem(sessionKey)
    setSessionId(null)
    setMessages([])
    setDraft('')
    setError(null)
  }

  function submit(prompt = draft) {
    const value = prompt.trim()
    if (!value || send.isPending) return
    setDraft('')
    send.mutate(value)
  }

  return <div className="coach-overlay" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose() }}><aside ref={drawer} className="coach-drawer" role="dialog" aria-modal="true" aria-label={agent.label} onKeyDown={handleDrawerKey}>
    <header className="coach-header"><div className="coach-heading-mark"><Bot aria-hidden="true" /></div><div className="coach-agent-heading"><p className="eyebrow">Learning companion</p><strong>{agent.label}</strong></div><button type="button" className="coach-new-chat" disabled={send.isPending} onClick={() => void startNew()}><Plus aria-hidden="true" />New Chat</button><button type="button" className="small-icon-button" aria-label="Close Coach" onClick={onClose}><X aria-hidden="true" /></button></header>
    <div className="coach-width-control"><PanelWidthSlider panel="coach" label="Coach width" /></div>
    <p className="coach-routing-note">Lumi automatically routes each request to the right specialist.</p>
    <div className="coach-messages" aria-live="polite">{history.isFetching && sessionId && <p className="coach-loading">Restoring saved conversation…</p>}{displayMessages.length === 0 && !history.isFetching && <div className="coach-welcome"><p className="eyebrow">A thoughtful place to learn</p><h2>{student.name ? `Hello, ${student.name}.` : canvas ? `Explore “${canvas.title}”` : note ? `Study “${note.title || 'Untitled note'}”` : 'What are you curious about?'}</h2><p>Ask for an explanation, practice, or a different perspective. Your conversation is saved in your local Lumi workspace.</p><div className="coach-prompt-list">{defaultPrompts.map((prompt) => <button type="button" key={prompt} onClick={() => submit(prompt)}>{prompt}</button>)}</div></div>}{displayMessages.map((message, index) => <article className={`coach-message-group is-${message.role}`} key={`${index}-${message.role}`}><span className="coach-speaker">{message.role === 'user' ? 'You' : agent.label}</span><div className={`coach-message is-${message.role}`}>{message.role === 'assistant' ? <MarkdownPreview content={withoutFocusCommands(message.text) || (send.isPending && index === displayMessages.length - 1 ? 'Thinking…' : '')} notes={notes} onOpenNote={(id) => { const target = notes.find((item) => item.id === id); if (target) onOpenNote?.(target) }} /> : <p>{message.text}</p>}</div></article>)}{error && <p className="coach-error" role="alert">{error}</p>}</div>
    <form className="coach-compose" onSubmit={(event) => { event.preventDefault(); submit() }}><label className="sr-only" htmlFor="coach-message">Message the Coach</label><textarea ref={composer} id="coach-message" value={draft} onChange={(event) => setDraft(event.target.value)} placeholder="Ask Lumi…" rows={2} onKeyDown={(event) => { if (event.key === 'Enter' && !event.shiftKey) { event.preventDefault(); submit() } }} /><button type="submit" aria-label="Send message" disabled={!draft.trim() || send.isPending}>{send.isPending ? <span className="coach-spinner" /> : <ArrowUp aria-hidden="true" />}</button></form>
  </aside></div>
}
