import { useEffect, useRef, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { getCanvases, lumiQueryKeys, updateCanvas, updateNote, type LumiApplicationSettings, type LumiCanvas, type LumiFolder, type LumiNote, type LumiWorkspace } from '../../lib/lumi-api'
import { uploadAttachment } from '../../lib/lumi-api'
import { ImagePlus, Pencil, Eye, PanelsTopLeft, X } from 'lucide-react'
import { MarkdownPreview } from './MarkdownPreview'

type SaveStatus = 'saved' | 'unsaved' | 'saving' | 'error'
type NoteDraft = { title: string; content: string; folderId: string }

function readNoteDraft(note: LumiNote): NoteDraft | null {
  try {
    const value: unknown = JSON.parse(localStorage.getItem(`lumi.note.draft:${note.id}`) ?? 'null')
    if (!value || typeof value !== 'object') return null
    const draft = value as Partial<NoteDraft>
    if (typeof draft.title !== 'string' || typeof draft.content !== 'string' || typeof draft.folderId !== 'string') return null
    return { title: draft.title, content: draft.content, folderId: draft.folderId }
  } catch { return null }
}

interface NoteEditorProps {
  note: LumiNote
  notes: LumiNote[]
  folders: LumiFolder[]
  preferences: LumiApplicationSettings
  onSaveStatus: (status: SaveStatus) => void
  onDelete: () => void
  onOpenNote: (noteId: string) => void
}

export function NoteEditor({ note, notes, folders, preferences, onSaveStatus, onDelete, onOpenNote }: NoteEditorProps) {
  const queryClient = useQueryClient()
  const [initialDraft] = useState(() => readNoteDraft(note))
  const [title, setTitle] = useState(initialDraft?.title ?? note.title)
  const [content, setContent] = useState(initialDraft?.content ?? note.content)
  const [folderId, setFolderId] = useState(initialDraft?.folderId ?? note.folderId ?? '')
  const [previewOverride, setPreviewOverride] = useState<{ noteId: string; value: boolean } | null>(null)
  const [showSavedToast, setShowSavedToast] = useState(false)
  const [showCanvasPicker, setShowCanvasPicker] = useState(false)
  const [selectedCanvasIds, setSelectedCanvasIds] = useState<string[]>([])
  const isPreview = previewOverride?.noteId === note.id ? previewOverride.value : preferences.editorMode === 'preview'
  const [isDirty, setDirty] = useState(Boolean(initialDraft))
  const editorDelay = Number(preferences.autosaveDelay ?? 700)
  const imageInput = useRef<HTMLInputElement>(null)
  const bodyInput = useRef<HTMLTextAreaElement>(null)
  const savedToastTimer = useRef<number | null>(null)
  const canvases = useQuery({ queryKey: lumiQueryKeys.canvases, queryFn: getCanvases })
  const addToCanvases = useMutation({
    mutationFn: async (canvasIds: string[]) => Promise.all(canvasIds.flatMap((canvasId) => {
      const canvas = canvases.data?.find((item) => item.id === canvasId)
      if (!canvas || canvas.noteIds.includes(note.id)) return []
      const noteIds = [...canvas.noteIds, note.id]
      const position = { x: 120 + ((noteIds.length - 1) % 3) * 390, y: 130 + Math.floor((noteIds.length - 1) / 3) * 270 }
      return [updateCanvas(canvas.id, { noteIds, positions: { ...canvas.positions, [note.id]: position } })]
    })),
    onSuccess: (updatedCanvases) => {
      queryClient.setQueryData<LumiCanvas[]>(lumiQueryKeys.canvases, (current) => current?.map((canvas) => updatedCanvases.find((updated) => updated.id === canvas.id) ?? canvas))
      setShowCanvasPicker(false)
    },
    onSettled: () => { void queryClient.invalidateQueries({ queryKey: lumiQueryKeys.canvases }) },
  })
  const { mutate: saveNote, isError, isPending: isSaving } = useMutation({
    mutationFn: ({ nextTitle, nextContent, nextFolderId }: { nextTitle: string; nextContent: string; nextFolderId: string }) => updateNote(note, nextTitle, nextContent, nextFolderId || undefined),
    onMutate: () => onSaveStatus('saving'),
    onSuccess: (savedNote) => {
      queryClient.setQueryData<LumiWorkspace>(lumiQueryKeys.workspace, (current) => current && ({
        ...current,
        notes: current.notes.map((item) => item.id === savedNote.id ? savedNote : item),
      }))
      void queryClient.invalidateQueries({ queryKey: lumiQueryKeys.graph })
      setTitle(savedNote.title)
      setContent(savedNote.content)
      setFolderId(savedNote.folderId ?? '')
      setDirty(false)
      try { localStorage.removeItem(`lumi.note.draft:${note.id}`) } catch { /* The saved note remains available from the workspace. */ }
      onSaveStatus('saved')
      setShowSavedToast(true)
      if (savedToastTimer.current !== null) window.clearTimeout(savedToastTimer.current)
      savedToastTimer.current = window.setTimeout(() => setShowSavedToast(false), 2400)
    },
    onError: () => onSaveStatus('error'),
  })
  const imageUpload = useMutation({ mutationFn: uploadAttachment, onSuccess: (path) => {
    const current = bodyInput.current?.value ?? content
    const start = bodyInput.current?.selectionStart ?? current.length
    const end = bodyInput.current?.selectionEnd ?? current.length
    const snippet = `![image](${path})`
    updateDraft(() => setContent(`${current.slice(0, start)}${snippet}${current.slice(end)}`))
  } })

  useEffect(() => {
    if (!isDirty || isSaving) return
    const timeout = window.setTimeout(() => saveNote({ nextTitle: title, nextContent: content, nextFolderId: folderId }), editorDelay)
    return () => window.clearTimeout(timeout)
  }, [content, editorDelay, folderId, isDirty, isSaving, saveNote, title])

  useEffect(() => {
    if (!isDirty) return
    try { localStorage.setItem(`lumi.note.draft:${note.id}`, JSON.stringify({ title, content, folderId })) } catch { /* Editing remains available if browser storage is full. */ }
  }, [content, folderId, isDirty, note.id, title])

  useEffect(() => () => {
    if (savedToastTimer.current !== null) window.clearTimeout(savedToastTimer.current)
  }, [])

  function updateDraft(update: () => void) {
    update()
    setDirty(true)
    onSaveStatus('unsaved')
  }

  function saveNow() {
    if (!isDirty || isSaving) return
    saveNote({ nextTitle: title, nextContent: content, nextFolderId: folderId })
  }

  return (
    <article className={`editor-surface ${preferences.editorWidth === 'wide' ? 'is-wide' : ''}`}>
      {showSavedToast && <div className="note-saved-toast" role="status" aria-live="polite"><span aria-hidden="true" />Saved</div>}
      <div className="editor-toolbar">
        <p className="editor-kicker">{folderId ? folders.find((folder) => folder.id === folderId)?.name ?? 'Folder note' : 'Unfiled note'}</p>
        <div className="editor-actions">
          <label className="sr-only" htmlFor="note-folder">Move note to folder</label>
          <select id="note-folder" value={folderId} onChange={(event) => updateDraft(() => setFolderId(event.target.value))}><option value="">No folder</option>{folders.map((folder) => <option key={folder.id} value={folder.id}>{folder.name}</option>)}</select>
          <input ref={imageInput} className="sr-only" type="file" accept="image/png,image/jpeg,image/gif,image/webp" aria-label="Choose note image" onChange={(event) => { const file = event.target.files?.[0]; if (file) imageUpload.mutate(file); event.target.value = '' }} />
          <button className="editor-tool-button" type="button" aria-label="Attach image" onClick={() => imageInput.current?.click()} disabled={imageUpload.isPending}><ImagePlus aria-hidden="true" />{imageUpload.isPending ? 'Uploading…' : 'Image'}</button>
          <button className="editor-tool-button" type="button" aria-label={isPreview ? 'Edit note' : 'Preview Markdown'} onClick={() => setPreviewOverride({ noteId: note.id, value: !isPreview })}>{isPreview ? <Pencil aria-hidden="true" /> : <Eye aria-hidden="true" />}{isPreview ? 'Edit' : 'Preview'}</button>
          <button className="editor-tool-button" type="button" aria-expanded={showCanvasPicker} aria-controls="note-canvas-picker" onClick={() => { setSelectedCanvasIds(canvases.data?.filter((canvas) => canvas.noteIds.includes(note.id)).map((canvas) => canvas.id) ?? []); setShowCanvasPicker((value) => !value) }}><PanelsTopLeft aria-hidden="true" />Add to Canvas</button>
          <button className="editor-delete-button" type="button" onClick={() => { if (window.confirm(`Delete “${title || 'Untitled note'}”?`)) onDelete() }}>Delete note</button>
          <button className="editor-save-button" type="button" onClick={saveNow} disabled={!isDirty || isSaving}>{isSaving ? 'Saving…' : 'Save now'}</button>
        </div>
      </div>
      {showCanvasPicker && <section className="note-canvas-picker" id="note-canvas-picker" aria-label="Add note to canvases">
        <header><div><strong>Add to Canvas</strong><span>Choose one or more boards for “{title || 'Untitled note'}”.</span></div><button type="button" aria-label="Close Canvas picker" onClick={() => setShowCanvasPicker(false)}><X aria-hidden="true" /></button></header>
        {canvases.isLoading ? <p>Loading canvases…</p> : canvases.isError ? <p role="alert">Could not load your canvases. Try again in a moment.</p> : canvases.data?.length ? <fieldset>{canvases.data.map((canvas) => <label key={canvas.id}><input type="checkbox" checked={selectedCanvasIds.includes(canvas.id)} onChange={(event) => setSelectedCanvasIds((ids) => event.target.checked ? [...ids, canvas.id] : ids.filter((id) => id !== canvas.id))} /><span>{canvas.title}</span>{canvas.noteIds.includes(note.id) && <small>Already added</small>}</label>)}</fieldset> : <p>No canvases yet. Create a Canvas first, then add this note here.</p>}
        {addToCanvases.isError && <p role="alert">Could not add the note to every selected Canvas. Please try again.</p>}
        {canvases.data?.length ? <footer><button type="button" onClick={() => setShowCanvasPicker(false)}>Cancel</button><button type="button" className="editor-save-button" disabled={addToCanvases.isPending || selectedCanvasIds.length === 0} onClick={() => addToCanvases.mutate(selectedCanvasIds)}>{addToCanvases.isPending ? 'Adding…' : `Add to ${selectedCanvasIds.length || ''} Canvas${selectedCanvasIds.length === 1 ? '' : 'es'}`}</button></footer> : null}
      </section>}
      <label className="sr-only" htmlFor="note-title">Note title</label>
      <input id="note-title" className="note-title-input" value={title} onChange={(event) => updateDraft(() => setTitle(event.target.value))} />
      <label className="sr-only" htmlFor="note-content">Note body</label>
      {isPreview ? <div className="note-preview-pane"><MarkdownPreview content={content} notes={notes} onOpenNote={onOpenNote} /></div> : <textarea ref={bodyInput} id="note-content" className="note-body-input" spellCheck={preferences.spellcheck !== false} value={content} onChange={(event) => updateDraft(() => setContent(event.target.value))} placeholder="Write freely, or use Markdown for headings, lists, code, links and note references." />}
      {imageUpload.isError && <p className="save-error" role="alert">{imageUpload.error instanceof Error ? imageUpload.error.message : 'Could not attach that image.'}</p>}
      {isError && <p className="save-error" role="alert">Couldn’t save this note. Your edits are still in this browser—try again when the local service is available.</p>}
    </article>
  )
}
