import { useCallback, useEffect, useRef, useState, type KeyboardEvent } from 'react'
import { createPortal } from 'react-dom'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { MessageSquare, MoreHorizontal, Trash2 } from 'lucide-react'
import { deleteAgentConversation, lumiQueryKeys } from '../../lib/lumi-api'
import { CHAT_DELETED_EVENT, persistRecentChats, readRecentChats, type RecentChat } from './recent-chats'
import './coach.css'

type MenuPosition = { x: number; y: number; trigger: HTMLElement }

function ChatMenu({ chat, position, pending, onOpen, onDelete, onDismiss }: { chat: RecentChat; position: MenuPosition; pending: boolean; onOpen: () => void; onDelete: () => void; onDismiss: () => void }) {
  const menu = useRef<HTMLDivElement>(null)
  useEffect(() => {
    menu.current?.querySelector<HTMLButtonElement>('[role="menuitem"]')?.focus()
    const outside = (event: PointerEvent) => { if (event.target instanceof Node && !menu.current?.contains(event.target)) onDismiss() }
    const dismiss = () => onDismiss()
    document.addEventListener('pointerdown', outside)
    window.addEventListener('resize', dismiss)
    window.addEventListener('scroll', dismiss, true)
    return () => {
      document.removeEventListener('pointerdown', outside)
      window.removeEventListener('resize', dismiss)
      window.removeEventListener('scroll', dismiss, true)
    }
  }, [onDismiss])
  const closeWithFocus = () => { onDismiss(); position.trigger.focus() }
  function onKeyDown(event: KeyboardEvent) {
    if (event.key === 'Escape' || event.key === 'Tab') { if (event.key === 'Escape') event.preventDefault(); closeWithFocus(); return }
    if (!['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) return
    event.preventDefault()
    const items = [...menu.current!.querySelectorAll<HTMLButtonElement>('[role="menuitem"]')]
    const index = items.indexOf(document.activeElement as HTMLButtonElement)
    const next = event.key === 'Home' ? 0 : event.key === 'End' ? items.length - 1 : (index + (event.key === 'ArrowDown' ? 1 : -1) + items.length) % items.length
    items[next]?.focus()
  }
  return createPortal(<div ref={menu} className="recent-chat-menu" role="menu" aria-label={`Options for ${chat.title}`} style={{ left: Math.max(8, Math.min(position.x, window.innerWidth - 220)), top: Math.max(8, Math.min(position.y, window.innerHeight - 110)) }} onKeyDown={onKeyDown}>
    <button type="button" role="menuitem" disabled={pending} onClick={() => { onDismiss(); onOpen() }}><MessageSquare aria-hidden="true" />Open chat</button>
    <button type="button" role="menuitem" className="chat-menu-delete" disabled={pending} onClick={() => { onDelete(); position.trigger.focus() }}><Trash2 aria-hidden="true" />{pending ? 'Deleting…' : 'Delete chat'}</button>
  </div>, document.body)
}

export function RecentChatRow({ chat, selected, onOpen, onDeleted }: { chat: RecentChat; selected: boolean; onOpen: () => void; onDeleted: () => void }) {
  const client = useQueryClient()
  const [position, setPosition] = useState<MenuPosition | null>(null)
  const dismiss = useCallback(() => setPosition(null), [])
  const remove = useMutation({
    mutationFn: () => deleteAgentConversation(chat.sessionId),
    onSuccess: () => {
      const key = `lumi.chat.session.${chat.agentPath}`
      if (localStorage.getItem(key) === chat.sessionId) localStorage.removeItem(key)
      client.removeQueries({ queryKey: lumiQueryKeys.agentConversation(chat.agentPath, chat.sessionId), exact: true })
      window.dispatchEvent(new CustomEvent(CHAT_DELETED_EVENT, { detail: chat.sessionId }))
      persistRecentChats(readRecentChats().filter((item) => item.sessionId !== chat.sessionId || item.agentPath !== chat.agentPath))
      onDeleted()
    },
  })
  function openMenu(trigger: HTMLElement, x?: number, y?: number) {
    if (remove.isPending) return
    const rect = trigger.getBoundingClientRect()
    remove.reset()
    setPosition({ trigger, x: x ?? rect.left, y: y ?? rect.bottom + 4 })
  }
  function confirmDelete() {
    if (!remove.isPending && window.confirm(`Delete “${chat.title}”? This permanently removes this saved Coach conversation.`)) remove.mutate()
    dismiss()
  }
  return <div className={`recent-chat-row ${selected ? 'is-selected' : ''}`}>
    <button className="note-row" type="button" aria-haspopup="menu" onClick={onOpen} onContextMenu={(event) => { event.preventDefault(); openMenu(event.currentTarget, event.clientX, event.clientY) }} onKeyDown={(event) => { if (event.key === 'ContextMenu' || (event.shiftKey && event.key === 'F10')) { event.preventDefault(); openMenu(event.currentTarget) } }}><MessageSquare aria-hidden="true" /><span>{chat.title}</span></button>
    <button className="recent-chat-options" type="button" aria-label={`Options for ${chat.title}`} aria-haspopup="menu" aria-expanded={Boolean(position)} disabled={remove.isPending} onClick={(event) => openMenu(event.currentTarget)}><MoreHorizontal aria-hidden="true" /></button>
    {position && <ChatMenu chat={chat} position={position} pending={remove.isPending} onOpen={onOpen} onDelete={confirmDelete} onDismiss={dismiss} />}
    {remove.isError && <p className="recent-chat-error" role="alert">Could not delete this chat. Try again.</p>}
  </div>
}
