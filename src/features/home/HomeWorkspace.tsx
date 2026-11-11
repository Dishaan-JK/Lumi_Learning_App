import { ArrowUpRight, BookOpen, Bot, FileText, Folder, Network, PanelRightClose, Plus } from 'lucide-react'
import { displayTitle } from '../../lib/format'
import type { LumiCanvas, LumiFolder, LumiNote } from '../../lib/lumi-api'

interface HomeWorkspaceProps {
  notes: LumiNote[]
  folders: LumiFolder[]
  canvases: LumiCanvas[]
  recentLimit: number
  onOpenNote: (id: string) => void
  onOpenCanvas: (id: string) => void
  onCreateNote: () => void
  onOpenView: (view: 'artifacts' | 'canvas' | 'graph') => void
  onStudyWithAgent: () => void
}

export function HomeWorkspace({ notes, folders, canvases, recentLimit, onOpenNote, onOpenCanvas, onCreateNote, onOpenView, onStudyWithAgent }: HomeWorkspaceProps) {
  const recent = [
    ...notes.map((item) => ({ kind: 'note' as const, id: item.id, title: displayTitle(item), updatedAt: item.updatedAt, preview: item.content || 'A quiet page, ready for your next thought.', folderId: item.folderId })),
    ...canvases.map((item) => ({ kind: 'canvas' as const, id: item.id, title: item.title, updatedAt: item.updatedAt, preview: item.description || (item.noteIds.length + ' notes in this study space'), folderId: null })),
  ].sort((a, b) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt)).slice(0, Math.min(20, Math.max(1, recentLimit)))
  return <section className="home-view"><header className="home-hero"><p className="eyebrow">Your learning space</p><h1>Make room for curiosity.</h1><p>A calm place to write, connect ideas, and keep what you learn.</p><button className="new-note-button home-create" type="button" onClick={onCreateNote}><Plus aria-hidden="true"/>New note</button></header><button type="button" className="home-study-agent" onClick={onStudyWithAgent}><span className="home-agent-mark"><Bot aria-hidden="true" /></span><span className="home-agent-copy"><span className="eyebrow">Your learning companion</span><strong>Study with Agent</strong><span>Ask a question, explore a topic, or get practice tailored to you.</span></span><span className="home-agent-action">Get started <ArrowUpRight aria-hidden="true" /></span></button><div className="home-stats"><button type="button" onClick={() => onOpenView('artifacts')}><BookOpen aria-hidden="true"/><strong>{notes.length}</strong><span>notes & saved learning</span><ArrowUpRight aria-hidden="true"/></button><button type="button" onClick={() => onOpenView('canvas')}><Folder aria-hidden="true"/><strong>{canvases.length}</strong><span>study canvases</span><ArrowUpRight aria-hidden="true"/></button><button type="button" onClick={() => onOpenView('graph')}><Network aria-hidden="true"/><strong>{folders.length}</strong><span>notebook folders</span><ArrowUpRight aria-hidden="true"/></button></div><section className="home-section"><header><div><p className="eyebrow">Pick up where you left off</p><h2>Recent files</h2></div><button type="button" onClick={() => onOpenView('canvas')}>View canvases <ArrowUpRight aria-hidden="true"/></button></header>{recent.length ? <div className="home-note-grid">{recent.map((item) => <button type="button" key={item.kind + '-' + item.id} onClick={() => item.kind === 'note' ? onOpenNote(item.id) : onOpenCanvas(item.id)}><span>{item.kind === 'note' ? <FileText aria-hidden="true"/> : <PanelRightClose aria-hidden="true"/>}{item.kind === 'note' ? item.folderId ? folders.find((folder) => folder.id === item.folderId)?.name : 'Unfiled' : 'Canvas file'}</span><strong>{item.title}</strong><p>{item.preview}</p></button>)}</div> : <div className="home-empty"><p>Your recent files will show up here.</p><button className="new-note-button" type="button" onClick={onCreateNote}><Plus aria-hidden="true"/>Create your first note</button></div>}</section></section>
}
