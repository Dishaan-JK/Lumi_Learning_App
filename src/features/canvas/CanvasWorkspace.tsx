import { useEffect, useRef, useState, type PointerEvent as ReactPointerEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Hand, Link2, Minus, Plus, Search, X } from 'lucide-react'
import { createCanvas, getCanvases, lumiQueryKeys, updateCanvas, type LumiCanvas, type LumiCanvasConnection, type LumiCanvasPosition, type LumiNote } from '../../lib/lumi-api'

const WORLD_WIDTH = 3200
const WORLD_HEIGHT = 2200
const MAX_CANVAS_POSITION = 10_000
const MIN_NOTE_WIDTH = 220
const MIN_NOTE_HEIGHT = 156
const MAX_NOTE_WIDTH = 1_200
const MAX_NOTE_HEIGHT = 900
const clampZoom = (value: number) => Math.min(2.25, Math.max(.4, value))
const defaultPosition = (index: number): LumiCanvasPosition => ({ x: 120 + (index % 3) * 390, y: 130 + Math.floor(index / 3) * 270 })
type CanvasNoteSize = { width: number; height: number }

function readCanvasNoteSizes(canvasId: string): Record<string, CanvasNoteSize> {
  try {
    const stored = localStorage.getItem(`lumi-canvas-note-sizes:${canvasId}`)
    if (!stored) return {}
    const value = JSON.parse(stored) as Record<string, unknown>
    return Object.fromEntries(Object.entries(value).flatMap(([id, size]) => {
      if (!size || typeof size !== 'object') return []
      const { width, height } = size as Partial<CanvasNoteSize>
      return typeof width === 'number' && Number.isFinite(width) && typeof height === 'number' && Number.isFinite(height)
        ? [[id, { width: Math.min(MAX_NOTE_WIDTH, Math.max(MIN_NOTE_WIDTH, width)), height: Math.min(MAX_NOTE_HEIGHT, Math.max(MIN_NOTE_HEIGHT, height)) }]]
        : []
    }))
  } catch { return {} }
}

export function CanvasWorkspace({ notes, selectedCanvasId, onOpenCanvas, onBackToCanvases, onOpenNote, onCreateNote }: { notes: LumiNote[]; selectedCanvasId: string | null; onOpenCanvas: (id: string) => void; onBackToCanvases: () => void; onOpenNote: (id: string) => void; onCreateNote: () => void }) {
  const client = useQueryClient()
  const canvases = useQuery({ queryKey: lumiQueryKeys.canvases, queryFn: getCanvases })
  const [title, setTitle] = useState('')
  const [selectedNoteIds, setSelectedNoteIds] = useState<string[]>([])
  const [noteSearch, setNoteSearch] = useState('')
  const create = useMutation({ mutationFn: () => createCanvas({ title: title.trim(), noteIds: selectedNoteIds }), onSuccess: async (canvas) => { setTitle(''); setSelectedNoteIds([]); await client.invalidateQueries({ queryKey: lumiQueryKeys.canvases }); onOpenCanvas(canvas.id) } })
  const selected = canvases.data?.find((canvas) => canvas.id === selectedCanvasId)
  const normalizedSearch = noteSearch.trim().toLocaleLowerCase()
  const filteredNotes = normalizedSearch ? notes.filter((note) => (note.title + ' ' + note.content).toLocaleLowerCase().includes(normalizedSearch)) : []
  if (selectedCanvasId) {
    return <section className="canvas-file-view" aria-label={`${selected?.title ?? 'Canvas'} workspace`}>
      {canvases.isLoading ? <p className="canvas-loading">Loading canvas…</p> : canvases.isError ? <p className="canvas-loading" role="alert">Canvases are unavailable. Check the local service and retry.</p> : selected ? <CanvasBoard key={selected.id} canvas={selected} notes={notes} onOpenNote={onOpenNote} onCreateNote={onCreateNote} /> : <div className="canvas-loading"><p>This canvas could not be found.</p><button type="button" onClick={onBackToCanvases}>Back to canvases</button></div>}
    </section>
  }
  return <section className="learning-view canvas-library-view">
    <header><p className="eyebrow">Connected thinking</p><h1>Canvas</h1><p>Create a visual study space from a name and the notes you want to bring together.</p></header>
    <form className="canvas-create" onSubmit={(event) => { event.preventDefault(); if (title.trim()) create.mutate() }}>
      <label htmlFor="canvas-title">Canvas name</label>
      <input id="canvas-title" required value={title} maxLength={120} onChange={(event) => setTitle(event.target.value)} placeholder="For example, Cell biology" />
      <fieldset className="canvas-note-picker">
        <legend>Add notes (optional) <span>({selectedNoteIds.length} selected)</span></legend>
        <label className="canvas-note-search" htmlFor="canvas-note-search"><span>Search notes</span><input id="canvas-note-search" type="search" value={noteSearch} onChange={(event) => setNoteSearch(event.target.value)} placeholder="Search by title or content" /></label>
        {notes.length ? normalizedSearch ? filteredNotes.length ? filteredNotes.map((note) => <label className="canvas-note-option" key={note.id}><input type="checkbox" checked={selectedNoteIds.includes(note.id)} onChange={(event) => setSelectedNoteIds((ids) => event.target.checked ? [...ids, note.id] : ids.filter((id) => id !== note.id))} /><span>{note.title || 'Untitled note'}</span></label>) : <p className="canvas-note-empty">No notes match “{noteSearch}”.</p> : <p className="canvas-note-empty">Search to find and select notes. You can also add them to this canvas later.</p> : <p className="canvas-note-empty">No notes yet. You can create this canvas now and link notes later.</p>}
      </fieldset>
      <div className="canvas-create-actions"><p>A canvas only needs a name. Notes are optional.</p><button disabled={!title.trim() || create.isPending}>{create.isPending ? 'Creating…' : 'Create canvas'}</button></div>
      {create.isError && <p role="alert">{create.error instanceof Error ? create.error.message : 'Could not create this canvas.'}</p>}
    </form>
    <section className="canvas-library" aria-labelledby="canvas-library-title">
      <div className="section-heading"><div><p className="eyebrow">Your files</p><h2 id="canvas-library-title">Saved canvases</h2></div><span>{canvases.data?.length ?? 0}</span></div>
      {canvases.isLoading ? <p>Loading canvases…</p> : canvases.isError ? <p role="alert">Canvases are unavailable. Check the local service and retry.</p> : canvases.data?.length ? <div className="canvas-library-grid">{canvases.data.map((canvas) => <button type="button" className="canvas-file-card" key={canvas.id} onClick={() => onOpenCanvas(canvas.id)}><span className="canvas-file-icon" aria-hidden="true">▤</span><span className="canvas-file-copy"><strong>{canvas.title}</strong><span>{canvas.description || (canvas.noteIds.length + ' notes')}</span></span><span className="canvas-file-arrow" aria-hidden="true">↗</span></button>)}</div> : <div className="empty-state"><h3>No canvases yet</h3><p>Create your first canvas above. It will be saved here for easy access.</p></div>}
    </section>
  </section>
}

function CanvasBoard({ canvas, notes, onOpenNote, onCreateNote }: { canvas: LumiCanvas; notes: LumiNote[]; onOpenNote: (id: string) => void; onCreateNote: () => void }) {
  const client = useQueryClient()
  const viewportRef = useRef<HTMLDivElement>(null)
  const moveRef = useRef<{ id: string; pointerX: number; pointerY: number; startX: number; startY: number } | null>(null)
  const resizeRef = useRef<{ id: string; pointerId: number; pointerX: number; pointerY: number; width: number; height: number } | null>(null)
  const panRef = useRef<{ pointerX: number; pointerY: number; startX: number; startY: number } | null>(null)
  const paletteDragRef = useRef<{ pointerX: number; pointerY: number; startX: number; startY: number } | null>(null)
  const zoomRef = useRef(1)
  const [noteIds, setNoteIds] = useState(canvas.noteIds ?? [])
  const [positions, setPositions] = useState<Record<string, LumiCanvasPosition>>(() => Object.fromEntries((canvas.noteIds ?? []).map((id, index) => [id, canvas.positions?.[id] ?? defaultPosition(index)])))
  const positionsRef = useRef(positions)
  const [noteSizes, setNoteSizes] = useState<Record<string, CanvasNoteSize>>(() => readCanvasNoteSizes(canvas.id))
  const noteSizesRef = useRef(noteSizes)
  const [connections, setConnections] = useState<LumiCanvasConnection[]>(canvas.connections ?? [])
  const [pan, setPan] = useState({ x: 40, y: 30 })
  const [zoom, setZoom] = useState(1)
  const [isPanning, setIsPanning] = useState(false)
  const [panMode, setPanMode] = useState(false)
  const [connectMode, setConnectMode] = useState(false)
  const [connectFrom, setConnectFrom] = useState<string | null>(null)
  const [selectedNoteId, setSelectedNoteId] = useState<string | null>(null)
  const [addingNotes, setAddingNotes] = useState(false)
  const [search, setSearch] = useState('')
  const [palettePosition, setPalettePosition] = useState<{ x: number; y: number } | null>(null)
  const update = useMutation({
    mutationFn: (changes: Parameters<typeof updateCanvas>[1]) => updateCanvas(canvas.id, changes),
    onSuccess: (updated) => client.setQueryData<LumiCanvas[]>(lumiQueryKeys.canvases, (items) => items?.map((item) => item.id === updated.id ? updated : item)),
  })
  const attachedNotes = noteIds.map((id, index) => ({ id, note: notes.find((item) => item.id === id), position: positions[id] ?? defaultPosition(index) }))
  const availableNotes = notes.filter((note) => !noteIds.includes(note.id) && (note.title + ' ' + note.content).toLocaleLowerCase().includes(search.trim().toLocaleLowerCase()))

  useEffect(() => { zoomRef.current = zoom }, [zoom])

  useEffect(() => {
    const element = viewportRef.current
    if (!element) return
    const handleWheel = (event: WheelEvent) => {
      if ((event.target as HTMLElement).closest('.canvas-note-content')) return
      event.preventDefault()
      if (event.ctrlKey) {
        const rect = element.getBoundingClientRect()
        const cursorX = event.clientX - rect.left
        const cursorY = event.clientY - rect.top
        const current = zoomRef.current
        const next = clampZoom(current * (event.deltaY < 0 ? 1.1 : 1 / 1.1))
        const ratio = next / current
        zoomRef.current = next
        setZoom(next)
        setPan((point) => ({ x: cursorX - (cursorX - point.x) * ratio, y: cursorY - (cursorY - point.y) * ratio }))
      } else {
        setPan((point) => ({ x: point.x - event.deltaX, y: point.y - event.deltaY }))
      }
    }
    element.addEventListener('wheel', handleWheel, { passive: false })
    return () => element.removeEventListener('wheel', handleWheel)
  }, [])

  useEffect(() => {
    const move = (event: PointerEvent) => {
      if (panRef.current) {
        const drag = panRef.current
        setPan({ x: drag.startX + event.clientX - drag.pointerX, y: drag.startY + event.clientY - drag.pointerY })
      }
      if (paletteDragRef.current) {
        const drag = paletteDragRef.current
        setPalettePosition({ x: Math.max(8, drag.startX + event.clientX - drag.pointerX), y: Math.max(8, drag.startY + event.clientY - drag.pointerY) })
      }
    }
    const up = () => { panRef.current = null; paletteDragRef.current = null; setIsPanning(false) }
    window.addEventListener('pointermove', move)
    window.addEventListener('pointerup', up)
    return () => { window.removeEventListener('pointermove', move); window.removeEventListener('pointerup', up) }
  }, [])

  function persistGraph(nextIds: string[], nextPositions: Record<string, LumiCanvasPosition>, nextConnections: LumiCanvasConnection[]) {
    positionsRef.current = nextPositions
    setNoteIds(nextIds); setPositions(nextPositions); setConnections(nextConnections)
    update.mutate({ noteIds: nextIds, positions: nextPositions, connections: nextConnections })
  }

  function addNote(id: string) {
    const position = defaultPosition(noteIds.length)
    persistGraph([...noteIds, id], { ...positions, [id]: position }, connections)
  }

  function removeNote(id: string) {
    const nextIds = noteIds.filter((item) => item !== id)
    const nextPositions = Object.fromEntries(Object.entries(positions).filter(([key]) => nextIds.includes(key)))
    persistGraph(nextIds, nextPositions, connections.filter((edge) => edge.sourceId !== id && edge.targetId !== id))
  }

  function connect(port: 'source' | 'target', id: string) {
    if (!connectMode) return
    if (port === 'source') { setConnectFrom(id); return }
    if (!connectFrom || connectFrom === id) return
    const exists = connections.some((edge) => edge.sourceId === connectFrom && edge.targetId === id)
    if (!exists) persistGraph(noteIds, positions, [...connections, { sourceId: connectFrom, targetId: id }])
    setConnectFrom(null)
    setConnectMode(false)
  }

  function startMove(event: ReactPointerEvent<HTMLElement>, id: string) {
    if (panMode || connectMode) return
    if ((event.target as HTMLElement).closest('button')) return
    const point = positions[id] ?? defaultPosition(noteIds.indexOf(id))
    moveRef.current = { id, pointerX: event.clientX, pointerY: event.clientY, startX: point.x, startY: point.y }
    event.currentTarget.setPointerCapture(event.pointerId)
  }

  function moveNode(event: ReactPointerEvent<HTMLElement>, id: string) {
    const drag = moveRef.current
    if (!drag || drag.id !== id) return
    const next = { ...positionsRef.current, [id]: { x: Math.min(MAX_CANVAS_POSITION, Math.max(0, drag.startX + (event.clientX - drag.pointerX) / zoom)), y: Math.min(MAX_CANVAS_POSITION, Math.max(0, drag.startY + (event.clientY - drag.pointerY) / zoom)) } }
    positionsRef.current = next
    setPositions(next)
  }

  function finishMove(id: string) {
    if (moveRef.current?.id !== id) return
    moveRef.current = null
    update.mutate({ positions: positionsRef.current })
  }

  function startResize(event: ReactPointerEvent<HTMLButtonElement>, id: string) {
    event.preventDefault()
    event.stopPropagation()
    const noteElement = event.currentTarget.closest<HTMLElement>('.canvas-note')
    if (!noteElement) return
    resizeRef.current = { id, pointerId: event.pointerId, pointerX: event.clientX, pointerY: event.clientY, width: noteElement.offsetWidth, height: noteElement.offsetHeight }
    event.currentTarget.setPointerCapture(event.pointerId)
  }

  function resizeNote(event: ReactPointerEvent<HTMLButtonElement>) {
    const resize = resizeRef.current
    if (!resize || resize.pointerId !== event.pointerId) return
    const next = {
      ...noteSizesRef.current,
      [resize.id]: {
        width: Math.min(MAX_NOTE_WIDTH, Math.max(MIN_NOTE_WIDTH, resize.width + (event.clientX - resize.pointerX) / zoom)),
        height: Math.min(MAX_NOTE_HEIGHT, Math.max(MIN_NOTE_HEIGHT, resize.height + (event.clientY - resize.pointerY) / zoom)),
      },
    }
    noteSizesRef.current = next
    setNoteSizes(next)
  }

  function finishResize(event: ReactPointerEvent<HTMLButtonElement>) {
    if (resizeRef.current?.pointerId !== event.pointerId) return
    resizeRef.current = null
    try { localStorage.setItem(`lumi-canvas-note-sizes:${canvas.id}`, JSON.stringify(noteSizesRef.current)) } catch { /* keep the current layout for this session */ }
  }

  return <div className="canvas-board-shell">
    <div ref={viewportRef} className={`canvas-board ${panMode ? 'is-pan-mode' : ''} ${isPanning ? 'is-panning' : ''}`} aria-label={`${canvas.title} board`} onPointerDown={(event) => { const target = event.target as HTMLElement; if ((panMode || event.shiftKey) && event.button === 0 && !target.closest('.canvas-tool-palette, .canvas-add-popover, .canvas-note-remove')) { panRef.current = { pointerX: event.clientX, pointerY: event.clientY, startX: pan.x, startY: pan.y }; setIsPanning(true); event.preventDefault() } }}>
      <div className="canvas-world" style={{ width: WORLD_WIDTH, height: WORLD_HEIGHT, transform: `translate(${pan.x}px, ${pan.y}px) scale(${zoom})` }}>
        <svg className="canvas-edges" width={WORLD_WIDTH} height={WORLD_HEIGHT} aria-label="Note connections">
          <defs><marker id="canvas-arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path className="canvas-arrow-head" d="M 0 0 L 10 5 L 0 10 z" /></marker></defs>
          {connections.map((edge) => {
            const source = positions[edge.sourceId] ?? defaultPosition(noteIds.indexOf(edge.sourceId))
            const target = positions[edge.targetId] ?? defaultPosition(noteIds.indexOf(edge.targetId))
            if (!noteIds.includes(edge.sourceId) || !noteIds.includes(edge.targetId)) return null
            const x1 = source.x + (window.innerWidth <= 760 ? 270 : 320); const y1 = source.y + 78; const x2 = target.x; const y2 = target.y + 78; const bend = Math.max(70, Math.abs(x2 - x1) * .46)
            return <path className="canvas-edge-path" key={`${edge.sourceId}:${edge.targetId}`} d={`M ${x1} ${y1} C ${x1 + bend} ${y1}, ${x2 - bend} ${y2}, ${x2} ${y2}`} markerEnd="url(#canvas-arrow)" />
          })}
        </svg>
        {attachedNotes.map(({ id, note, position }) => <article className={`canvas-note ${noteSizes[id] ? 'is-resized' : ''} ${selectedNoteId === id ? 'is-selected' : ''} ${connectFrom === id ? 'is-connect-source' : ''}`} key={id} style={{ left: position.x, top: position.y, width: noteSizes[id]?.width, height: noteSizes[id]?.height }} onPointerDown={(event) => startMove(event, id)} onPointerMove={(event) => moveNode(event, id)} onPointerUp={() => finishMove(id)} onClick={(event) => { if ((event.target as HTMLElement).closest('button')) return; if (connectMode) connect(connectFrom ? 'target' : 'source', id); else setSelectedNoteId(id) }} onDoubleClick={(event) => { if ((event.target as HTMLElement).closest('button') || connectMode || panMode) return; onOpenNote(id) }}>
          <button className="canvas-note-remove" type="button" aria-label={`Remove ${note?.title || 'note'} from canvas`} title="Remove from canvas" onClick={() => removeNote(id)}><X aria-hidden="true" /></button>
          <span className="canvas-note-label">Note</span>
          <button className="canvas-note-title" type="button" onClick={() => connectMode ? connect(connectFrom ? 'target' : 'source', id) : panMode ? undefined : onOpenNote(id)} onDoubleClick={(event) => { event.stopPropagation(); if (!connectMode && !panMode) onOpenNote(id) }}>{note?.title || 'Untitled note'}</button>
          <p className="canvas-note-content">{(note?.content || 'No preview available.').replace(/[#*_`>]/g, '')}</p>
          <button className="canvas-note-resize" type="button" aria-label={`Resize ${note?.title || 'note'}`} title="Drag to resize note" onPointerDown={(event) => startResize(event, id)} onPointerMove={resizeNote} onPointerUp={finishResize} onPointerCancel={finishResize} onLostPointerCapture={finishResize}><span aria-hidden="true" /></button>
        </article>)}
      </div>
      {noteIds.length === 0 && <div className="canvas-empty-state"><span className="canvas-empty-orb"><Plus aria-hidden="true" /></span><strong>A clear space for your ideas</strong><span>Add notes from the floating panel, then connect related thoughts.</span></div>}
      <div className="canvas-tool-palette" style={palettePosition ? { left: palettePosition.x, top: palettePosition.y, right: 'auto' } : undefined} aria-label="Canvas controls">
        <div className="canvas-palette-grip" title="Drag to move the controls" onPointerDown={(event) => { paletteDragRef.current = { pointerX: event.clientX, pointerY: event.clientY, startX: palettePosition?.x ?? Math.max(16, (viewportRef.current?.clientWidth ?? 600) - 80), startY: palettePosition?.y ?? 18 }; event.preventDefault() }}><span /><span /><span /><span /><span /><span /></div>
        <button type="button" className={addingNotes ? 'is-active' : ''} aria-label="Add notes to canvas" title="Add notes" onClick={() => { setAddingNotes((value) => !value); setSearch('') }}><Plus aria-hidden="true" /></button>
        <button type="button" className={connectMode ? 'is-active' : ''} aria-label={connectMode ? 'Exit connection mode' : 'Connect notes'} title={connectMode ? 'Exit connection mode' : 'Connect notes'} onClick={() => { if (connectMode) { setConnectMode(false); setConnectFrom(null) } else { setPanMode(false); setConnectMode(true); setConnectFrom(selectedNoteId) } }}><Link2 aria-hidden="true" /></button>
        <span className="canvas-palette-divider" />
        <button type="button" aria-label="Zoom out" title="Zoom out" onClick={() => setZoom((value) => clampZoom(value / 1.15))}><Minus aria-hidden="true" /></button>
        <span className="canvas-zoom-readout" aria-live="polite">{Math.round(zoom * 100)}%</span>
        <button type="button" aria-label="Zoom in" title="Zoom in" onClick={() => setZoom((value) => clampZoom(value * 1.15))}><Plus aria-hidden="true" /></button>
        <span className="canvas-palette-divider" />
        <button type="button" className={`canvas-pan-hint ${panMode ? 'is-active' : ''}`} aria-label={panMode ? 'Exit pan mode' : 'Enter pan mode'} title={panMode ? 'Exit pan mode' : 'Pan mode'} aria-pressed={panMode} onClick={() => { setConnectMode(false); setConnectFrom(null); setPanMode((value) => !value) }}><Hand aria-hidden="true" /></button>
      </div>
      {addingNotes && <section className="canvas-add-popover" aria-label="Add notes to canvas"><header><div><strong>Add notes</strong><span>Choose notes to place on the board</span></div><button type="button" aria-label="Close note search" onClick={() => setAddingNotes(false)}><X aria-hidden="true" /></button></header><button type="button" className="canvas-create-note" onClick={() => { setAddingNotes(false); onCreateNote() }}>Create a new note</button><label className="canvas-add-search"><Search aria-hidden="true" /><input autoFocus type="search" value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search your notes" /></label><div className="canvas-add-results">{availableNotes.length ? availableNotes.slice(0, 8).map((note) => <button type="button" key={note.id} onClick={() => addNote(note.id)}><span><strong>{note.title || 'Untitled note'}</strong><small>{note.content.replace(/[#*_`>]/g, '').slice(0, 70) || 'No preview'}</small></span><Plus aria-hidden="true" /></button>) : <p>{search ? 'No matching notes available.' : 'All your notes are already on this canvas.'}</p>}</div></section>}
      <div className="canvas-board-hint"><span>{connectMode ? connectFrom ? 'Click the note you want to connect to' : 'Click a note to start a connection' : panMode ? 'Pan mode · Drag the board to move around' : 'Drag to move · Double-click to open · Resize from corner · Scroll to move · Ctrl + scroll to zoom'}</span>{update.isPending ? <span>Saving…</span> : update.isError ? <span role="alert" title={update.error instanceof Error ? update.error.message : 'Unknown save error'}>Save failed: {update.error instanceof Error ? update.error.message : 'Please retry.'}</span> : null}</div>
    </div>
  </div>
}
