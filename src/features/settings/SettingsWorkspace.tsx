import { useEffect, useState } from 'react'
import { Download, Upload } from 'lucide-react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  addProfilePreference, clearLearningRecord, clearProfile, exportWorkspace, getApplicationSettings,
  getHardwareReport, getLearningRecord, getProfilePreferences, getProviderSettings, getWorkspaceStatus, importWorkspace, lumiQueryKeys,
  removeProfilePreference, saveApplicationSettings, saveProviderSettings, testProviderSettings, listProviderModels, type LumiHardwareReport,
} from '../../lib/lumi-api'
import { readStudentProfile } from '../profile/student-profile'
import type { SettingsSection } from '../navigation/workspace-navigation'

type Tab = SettingsSection
const providerDefaults: Record<string, { model: string; baseUrl: string }> = {
  ollama: { model: 'qwen2.5:3b', baseUrl: 'http://127.0.0.1:11434/v1' },
  openai: { model: 'gpt-4o-mini', baseUrl: 'https://api.openai.com/v1' },
  anthropic: { model: 'claude-sonnet-4-5', baseUrl: 'https://api.anthropic.com/v1' },
  gemini: { model: 'gemini-2.5-flash', baseUrl: 'https://generativelanguage.googleapis.com/v1beta' },
  compatible: { model: 'gpt-4o-mini', baseUrl: 'https://api.openai.com/v1' },
}
const tabs: Array<{ id: Tab; label: string }> = [
  { id: 'general', label: 'General' }, { id: 'appearance', label: 'Appearance' }, { id: 'ai', label: 'AI & models' },
  { id: 'learning', label: 'Learning & coach' }, { id: 'workspace', label: 'Workspace & editor' },
  { id: 'artifacts', label: 'Artifacts' }, { id: 'privacy', label: 'Privacy & data' },
  { id: 'storage', label: 'Artifacts & storage' }, { id: 'diagnostics', label: 'Diagnostics' }, { id: 'hardware', label: 'Hardware report' },
]

export function SettingsWorkspace({ activeTab: tab, onTabChange }: { activeTab: Tab; onTabChange: (tab: Tab) => void }) {
  const client = useQueryClient()
  const settings = useQuery({ queryKey: lumiQueryKeys.settings, queryFn: getApplicationSettings })
  const [saved, setSaved] = useState(false)
  const [draft, setDraft] = useState<Record<string, string | number | boolean>>({})
  const [preferenceDraft, setPreferenceDraft] = useState('')
  const [notice, setNotice] = useState('')
  const [importFileName, setImportFileName] = useState('')
  const [apiKey, setApiKey] = useState('')
  const [availableModels, setAvailableModels] = useState<string[]>([])
  const [modelsLoading, setModelsLoading] = useState(false)
  const [modelsError, setModelsError] = useState('')
  const [modelsRetry, setModelsRetry] = useState(0)
  const providerSettings = useQuery({ queryKey: lumiQueryKeys.serviceSettings, queryFn: getProviderSettings, enabled: tab === 'ai' })
  const profile = useQuery({ queryKey: lumiQueryKeys.profile, queryFn: getProfilePreferences, enabled: tab === 'privacy' })
  const learning = useQuery({ queryKey: lumiQueryKeys.learningRecord, queryFn: getLearningRecord, enabled: tab === 'privacy' })
  const status = useQuery({ queryKey: lumiQueryKeys.diagnostics, queryFn: getWorkspaceStatus, enabled: tab === 'diagnostics' || tab === 'storage' })
  const hardware = useQuery({ queryKey: ['hardware-report'], queryFn: getHardwareReport, enabled: tab === 'hardware' })
  const save = useMutation({ mutationFn: saveApplicationSettings, onSuccess: (value) => { client.setQueryData(lumiQueryKeys.settings, value); setDraft({}); setSaved(true); window.setTimeout(() => setSaved(false), 1800) } })
  const [providerBusy, setProviderBusy] = useState(false)
  const [providerError, setProviderError] = useState('')
  const preferenceMutation = useMutation({ mutationFn: addProfilePreference, onSuccess: (value) => { client.setQueryData(lumiQueryKeys.profile, value); setPreferenceDraft('') } })
  const removePreference = useMutation({ mutationFn: removeProfilePreference, onSuccess: (value) => client.setQueryData(lumiQueryKeys.profile, value) })
  const clearProfileMutation = useMutation({ mutationFn: clearProfile, onSuccess: (value) => client.setQueryData(lumiQueryKeys.profile, value) })
  const clearLearningMutation = useMutation({ mutationFn: clearLearningRecord, onSuccess: (value) => client.setQueryData(lumiQueryKeys.learningRecord, value) })
  const values = { ...settings.data, ...draft }
  const set = (key: string, value: string | number | boolean) => { setSaved(false); setDraft((current) => ({ ...current, [key]: value })) }
  const formatBytes = (bytes?: number | null) => bytes == null ? 'Not reported' : `${(bytes / (1024 ** 3)).toFixed(1)} GB`
  const formatMegabytes = (bytes?: number | null) => bytes == null ? 'Not reported' : `${(bytes / (1024 ** 2)).toFixed(2)} MB`
  const [providerDraft, setProviderDraft] = useState<{ provider: string; model: string; baseUrl: string } | null>(null)
  const provider = providerDraft?.provider ?? providerSettings.data?.providerId ?? 'ollama'
  const model = providerDraft?.model ?? providerSettings.data?.model ?? 'qwen2.5:3b'
  const configuredBaseUrl = providerSettings.data?.providerId === provider ? providerSettings.data.baseUrl.trim() : ''
  const baseUrl = providerDraft?.baseUrl ?? (configuredBaseUrl || providerDefaults[provider]?.baseUrl || '')

  useEffect(() => {
    const savedKeyAvailable = !providerDraft && Boolean(providerSettings.data?.apiKeyConfigured)
    if (tab !== 'ai' || provider === 'ollama' || (!apiKey.trim() && !savedKeyAvailable)) {
      setAvailableModels([]); setModelsLoading(false); setModelsError('')
      return
    }
    let current = true
    const timer = window.setTimeout(() => {
      setModelsLoading(true); setModelsError('')
      void listProviderModels({ provider, baseUrl, ...(apiKey.trim() ? { apiKey: apiKey.trim() } : {}) })
        .then(({ models }) => {
          if (!current) return
          const cleanModels = [...new Set(models.filter((item) => typeof item === 'string' && item.trim()))]
          setAvailableModels(cleanModels)
          if (cleanModels.length && !cleanModels.includes(model)) setProviderDraft({ provider, model: cleanModels[0], baseUrl })
          if (!cleanModels.length) setModelsError('No models were returned for this provider.')
        })
        .catch((error: unknown) => { if (current) { setAvailableModels([]); const message = error instanceof Error ? error.message : 'Could not load models.'; setModelsError(message.includes('Cross-origin access is not allowed') ? 'The local service rejected this UI address. Restart with npm run dev:full, or add this exact UI origin to LUMI_ALLOWED_ORIGINS and restart the backend.' : message) } })
        .finally(() => { if (current) setModelsLoading(false) })
    }, 650)
    return () => { current = false; window.clearTimeout(timer) }
  }, [tab, provider, baseUrl, apiKey, modelsRetry, providerDraft, providerSettings.data?.providerId, providerSettings.data?.apiKeyConfigured])

  async function testConnection() {
    setProviderBusy(true); setProviderError(''); setNotice('')
    try { const result = await testProviderSettings({ provider, model: model.trim(), baseUrl: baseUrl.trim(), ...(apiKey ? { apiKey } : {}) }); setNotice(result.message) }
    catch (error) { setProviderError(error instanceof Error ? error.message : 'Provider connection failed.') }
    finally { setProviderBusy(false) }
  }
  async function saveConnection() {
    setProviderBusy(true); setProviderError(''); setNotice('')
    try { const result = await saveProviderSettings({ provider, model: model.trim(), baseUrl: baseUrl.trim(), ...(apiKey ? { apiKey } : {}) }); setApiKey(''); setProviderDraft(null); setNotice(result.reconnecting ? 'Connection saved. The local service is reconnecting; refresh the Coach when it is ready.' : 'Connection saved.'); void client.invalidateQueries({ queryKey: lumiQueryKeys.serviceSettings }) }
    catch (error) { setProviderError(error instanceof Error ? error.message : 'Could not save provider settings.') }
    finally { setProviderBusy(false) }
  }

  async function downloadExport() {
    try {
      const data = await exportWorkspace()
      const url = URL.createObjectURL(new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' }))
      const anchor = document.createElement('a'); anchor.href = url; anchor.download = `lumi-workspace-${new Date().toISOString().slice(0, 10)}.json`; anchor.click(); URL.revokeObjectURL(url)
      setNotice('Workspace export downloaded. Provider credentials are excluded by the local service.')
    } catch { setNotice('Export failed. Check that the local Lumi service is online.') }
  }

  async function importFile(file?: File) {
    if (!file) return
    try {
      const data = JSON.parse(await file.text()) as Record<string, unknown>
      if (data.format !== 'lumi-workspace' || !data.files || !window.confirm('Import replaces workspace notes, folders, canvases, artifacts, preferences, and attachments. Continue?')) return
      await importWorkspace(data)
      await Promise.all([client.invalidateQueries({ queryKey: lumiQueryKeys.workspace }), client.invalidateQueries({ queryKey: lumiQueryKeys.artifacts }), client.invalidateQueries({ queryKey: lumiQueryKeys.canvases }), client.invalidateQueries({ queryKey: lumiQueryKeys.graph }), client.invalidateQueries({ queryKey: lumiQueryKeys.profile }), client.invalidateQueries({ queryKey: lumiQueryKeys.learningRecord })])
      setNotice('Workspace imported. The workspace views have been refreshed.')
    } catch { setNotice('Import failed. Choose a valid Lumi workspace export.') }
  }

  if (settings.isLoading) return <section className="learning-view"><p>Loading preferences…</p></section>
  if (settings.isError) return <section className="learning-view"><h1>Settings unavailable</h1><p role="alert">Could not load preferences from the local service.</p><button onClick={() => settings.refetch()}>Try again</button></section>

  return <section className="learning-view settings-view">
    <header><p className="eyebrow">Your workspace</p><h1>Settings</h1><p>Preferences and data controls for this local Lumi workspace.</p></header>
    <div className="settings-layout">
    <nav className="settings-sidebar" aria-label="Settings categories">{tabs.map((item) => <button type="button" key={item.id} className={tab === item.id ? 'is-active' : ''} aria-current={tab === item.id ? 'page' : undefined} onClick={() => { onTabChange(item.id); setNotice('') }}>{item.label}</button>)}</nav>
    <div className="settings-panel">
    {tab === 'general' && <section className="settings-card"><h2>General</h2><label>Name<input value={String(values.displayName ?? '')} maxLength={80} onChange={(event) => set('displayName', event.target.value)} required /></label><label>Class<input value={String(values.studentClass ?? '')} maxLength={80} required onChange={(event) => set('studentClass', event.target.value)} /></label><label>School name<input value={String(values.schoolName ?? '')} maxLength={80} required onChange={(event) => set('schoolName', event.target.value)} /></label><label>Workspace name<input value={String(values.workspaceName ?? 'My workspace')} maxLength={80} onChange={(event) => set('workspaceName', event.target.value)} /></label><label>Start page<select value={String(values.startPage ?? 'artifacts')} onChange={(event) => set('startPage', event.target.value)}><option value="home">Home</option><option value="artifacts">Artifacts</option><option value="canvas">Canvas</option><option value="notes">Notes</option></select></label></section>}
    {tab === 'appearance' && <><section className="settings-card"><h2>Appearance</h2><label>Theme<select value={String(values.theme ?? 'light')} onChange={(event) => set('theme', event.target.value)}><option value="light">Light</option><option value="dark">Dark</option><option value="system">System</option></select></label><label>Accent<select value={String(values.accent ?? 'sage')} onChange={(event) => set('accent', event.target.value)}><option value="sage">Sage</option><option value="blue">Blue</option><option value="lightOrange">Light orange</option><option value="maroon">Maroon</option></select></label><label>Text size<select value={String(values.textSize ?? 'standard')} onChange={(event) => set('textSize', event.target.value)}><option value="small">Small</option><option value="standard">Standard</option><option value="large">Large</option></select></label><label>Density<select value={String(values.density ?? 'comfortable')} onChange={(event) => set('density', event.target.value)}><option value="comfortable">Comfortable</option><option value="compact">Compact</option></select></label><label>Canvas pattern<select value={String(values.canvasPattern ?? 'dots')} onChange={(event) => set('canvasPattern', event.target.value)}><option value="dots">Dots</option><option value="grid">Grid</option><option value="none">None</option></select></label><label className="settings-check"><input type="checkbox" checked={Boolean(values.reduceMotion)} onChange={(event) => set('reduceMotion', event.target.checked)} />Reduce motion</label></section><section className="settings-card"><h2>Canvas colors</h2>{(['canvasBackgroundLight', 'canvasPatternLight', 'canvasBackgroundDark', 'canvasPatternDark'] as const).map((key) => <label key={key}>{key.replace('canvas', '').replace(/([A-Z])/g, ' $1')}<input type="color" value={String(values[key] ?? '#F4F1E8')} onChange={(event) => set(key, event.target.value.toUpperCase())} /></label>)}</section></>}
    {tab === 'ai' && <section className="settings-card settings-stack"><h2>AI & models</h2>{providerSettings.isLoading ? <p>Loading provider settings…</p> : providerSettings.isError || !providerSettings.data ? <p role="alert">Could not load provider settings from the local service.</p> : <><p>Provider secrets are kept by the local Dart service. The key field is never prefilled or cached in browser storage.</p><label>Provider<select value={provider} onChange={(event) => { const next = event.target.value; const defaults = providerDefaults[next] ?? providerDefaults.openai; setApiKey(''); setAvailableModels([]); setModelsError(''); setProviderDraft({ provider: next, ...defaults }) }}><option value="ollama">Local Ollama</option><option value="openai">OpenAI</option><option value="anthropic">Anthropic</option><option value="gemini">Google Gemini</option><option value="compatible">OpenAI-compatible API</option></select></label><label>Model{availableModels.length ? <select value={availableModels.includes(model) ? model : availableModels[0]} onChange={(event) => setProviderDraft({ provider, model: event.target.value, baseUrl })}>{availableModels.map((item) => <option key={item} value={item}>{item}</option>)}</select> : <input value={model} maxLength={160} onChange={(event) => setProviderDraft({ provider, model: event.target.value, baseUrl })} />}</label>{provider !== 'ollama' && <label>API key {providerSettings.data.providerId === provider && providerSettings.data.apiKeyConfigured ? '(already configured; leave blank to keep it)' : ''}<input type="password" autoComplete="new-password" value={apiKey} onChange={(event) => setApiKey(event.target.value)} placeholder={providerSettings.data.providerId === provider && providerSettings.data.apiKeyConfigured ? 'Stored securely by the local service' : 'Enter API key'} /></label>}{provider !== 'ollama' && <p aria-live="polite">{modelsLoading ? 'Loading available models…' : modelsError ? <>{modelsError} <button type="button" onClick={() => setModelsRetry((value) => value + 1)}>Retry</button></> : availableModels.length ? `${availableModels.length} models available.` : 'Enter an API key to load available models.'}</p>}<p>Current connection: {providerSettings.data.provider} · {providerSettings.data.model}. {providerSettings.data.apiKeyConfigured ? 'API key configured.' : 'No API key configured.'}</p><div className="settings-actions"><button disabled={providerBusy || !model.trim()} onClick={() => { void testConnection() }}>{providerBusy ? 'Working…' : 'Test connection'}</button><button className="editor-save-button" disabled={providerBusy || !model.trim()} onClick={() => { void saveConnection() }}>{providerBusy ? 'Working…' : 'Save connection'}</button></div>{providerError && <p role="alert">{providerError}</p>}</>}</section>}
    {tab === 'learning' && <section className="settings-card"><h2>Learning & coach</h2><label>Teaching style<select value={String(values.teachingStyle ?? 'balanced')} onChange={(event) => set('teachingStyle', event.target.value)}><option value="balanced">Balanced</option><option value="concise">Concise</option><option value="step-by-step">Step by step</option><option value="socratic">Socratic</option></select></label><label>Difficulty<select value={String(values.difficulty ?? 'adaptive')} onChange={(event) => set('difficulty', event.target.value)}><option value="adaptive">Adaptive</option><option value="beginner">Beginner</option><option value="intermediate">Intermediate</option><option value="advanced">Advanced</option></select></label><label>Default quiz questions<select value={Number(values.questionCount ?? 5)} onChange={(event) => set('questionCount', Number(event.target.value))}>{[3, 5, 10, 15, 20].map((count) => <option key={count} value={count}>{count}</option>)}</select></label><label className="settings-check"><input type="checkbox" checked={Boolean(values.coachContext)} onChange={(event) => set('coachContext', event.target.checked)} />Allow Coach to use workspace context</label><label className="settings-check"><input type="checkbox" checked={Boolean(values.rememberPreferences ?? true)} onChange={(event) => set('rememberPreferences', event.target.checked)} />Remember preferences I explicitly share</label></section>}
    {tab === 'workspace' && <><section className="settings-card"><h2>Workspace & editor</h2><label>Editor mode<select value={String(values.editorMode ?? 'edit')} onChange={(event) => set('editorMode', event.target.value)}><option value="edit">Edit</option><option value="preview">Preview</option></select></label><label>Editor width<select value={String(values.editorWidth ?? 'focused')} onChange={(event) => set('editorWidth', event.target.value)}><option value="focused">Focused</option><option value="wide">Wide</option></select></label><label>Autosave delay<select value={Number(values.autosaveDelay ?? 700)} onChange={(event) => set('autosaveDelay', Number(event.target.value))}><option value={500}>0.5 seconds</option><option value={700}>0.7 seconds</option><option value={1500}>1.5 seconds</option><option value={3000}>3 seconds</option></select></label><label>Recent chats limit<select value={Number(values.recentLimit ?? 12)} onChange={(event) => set('recentLimit', Number(event.target.value))}><option value={5}>5</option><option value={12}>12</option><option value={20}>20</option></select></label><label className="settings-check"><input type="checkbox" checked={Boolean(values.spellcheck ?? true)} onChange={(event) => set('spellcheck', event.target.checked)} />Spellcheck in notes</label></section></>}
    {tab === 'artifacts' && <section className="settings-card"><h2>Artifacts library</h2><label>Layout<select value={String(values.artifactLayout ?? 'grid')} onChange={(event) => set('artifactLayout', event.target.value)}><option value="grid">Grid</option><option value="list">List</option></select></label><label>Sort<select value={String(values.artifactSort ?? 'Newest first')} onChange={(event) => set('artifactSort', event.target.value)}><option value="Newest first">Newest first</option><option value="Oldest first">Oldest first</option><option value="Title A–Z">Title A–Z</option></select></label></section>}
    {tab === 'privacy' && <><section className="settings-card settings-stack"><h2>Coach profile</h2><p>Preferences remembered from your learning sessions. You can remove individual items or clear this profile.</p>{profile.isLoading ? <p>Loading profile…</p> : (profile.data?.preferences ?? []).map((preference) => <div className="settings-row" key={preference}><span>{preference}</span><button onClick={() => removePreference.mutate(preference)}>Forget</button></div>)}<p>Use a clear learning or communication preference, such as “I prefer concise explanations” or “Please use short examples.”</p><form className="settings-inline-form" onSubmit={(event) => { event.preventDefault(); const value = preferenceDraft.trim(); if (value) preferenceMutation.mutate(value) }}><input aria-label="Remember a preference" value={preferenceDraft} maxLength={180} onChange={(event) => { setPreferenceDraft(event.target.value); preferenceMutation.reset() }} placeholder="I prefer concise explanations"/><button disabled={!preferenceDraft.trim() || preferenceMutation.isPending}>{preferenceMutation.isPending ? 'Saving…' : 'Remember'}</button></form>{preferenceMutation.isError && <p role="alert">{preferenceMutation.error instanceof Error ? preferenceMutation.error.message : 'Could not save this preference. Try a clear learning or communication preference.'}</p>}<button className="settings-danger" onClick={() => { if (window.confirm('Clear all Coach profile preferences?')) clearProfileMutation.mutate() }}>Clear profile</button></section><section className="settings-card settings-stack"><h2>Learning record</h2>{learning.isLoading ? <p>Loading learning record…</p> : <><p>{learning.data?.events.length ?? 0} learning events · {learning.data?.patterns.length ?? 0} patterns · {learning.data?.dueReviews.length ?? 0} due reviews</p><button className="settings-danger" onClick={() => { if (window.confirm('Permanently clear the local learning record?')) clearLearningMutation.mutate() }}>Clear learning record</button></>}</section></>}
    {tab === 'storage' && <section className="settings-card settings-stack settings-storage"><h2>Artifacts & storage</h2>{status.isLoading && <p className="storage-summary">Checking storage…</p>}{status.isError && <p className="storage-summary" role="alert">Storage usage is unavailable.</p>}{status.data && <p className="storage-summary">{status.data.artifacts} artifacts <span aria-hidden="true">·</span> {formatMegabytes(status.data.storageBytes)} used</p>}<p>Workspace exports contain notes, learning artifacts, preferences, and attachments. They never contain provider credentials.</p><button className="storage-export-button" type="button" onClick={downloadExport}><Download aria-hidden="true" />Export workspace</button><label className="settings-file"><span>Import workspace export</span><input className="settings-file-input" type="file" accept="application/json,.json" aria-label="Choose workspace export" onChange={(event) => { const file = event.currentTarget.files?.[0]; if (file) { setImportFileName(file.name); void importFile(file) } event.currentTarget.value = '' }} /><span className="settings-file-control"><span className="settings-file-button"><Upload aria-hidden="true" />Choose file</span><span className="settings-file-name" aria-live="polite">{importFileName || 'No file selected'}</span></span></label><small>Import replaces the current workspace and asks for confirmation before writing.</small></section>}
    {tab === 'diagnostics' && <section className="settings-card settings-stack"><h2>About & diagnostics</h2>{status.isLoading ? <p>Checking local service…</p> : status.isError ? <p role="alert">Local service diagnostics unavailable.</p> : status.data && <dl className="diagnostics-grid"><dt>Service</dt><dd>{status.data.service}</dd><dt>Version</dt><dd>{status.data.version}</dd><dt>AI provider</dt><dd>{status.data.provider} · {status.data.model}</dd><dt>Workspace</dt><dd>{status.data.notes} notes, {status.data.folders} folders, {status.data.canvases} canvases, {status.data.artifacts} artifacts</dd><dt>Storage</dt><dd>{formatMegabytes(status.data.storageBytes)}</dd></dl>}<button onClick={() => status.refetch()}>Refresh diagnostics</button></section>}
    {tab === 'hardware' && <section className="settings-card settings-stack"><h2>Hardware report</h2>{hardware.isLoading ? <p>Inspecting the computer running Lumi…</p> : hardware.isError || !hardware.data ? <p role="alert">Hardware information is unavailable from the local service.</p> : <HardwareDetails report={hardware.data} formatBytes={formatBytes} />}<button onClick={() => hardware.refetch()}>Refresh hardware report</button><small>Hardware data is read from the machine hosting the local Dart backend; a browser device may be different.</small></section>}
    {notice && <p className="settings-notice" role="status">{notice}</p>}
    {(['general', 'appearance', 'learning', 'workspace', 'artifacts'] as Tab[]).includes(tab) && <footer className="settings-footer"><span aria-live="polite">{save.isError ? 'Could not save preferences.' : saved ? 'Preferences saved.' : Object.keys(draft).length ? 'Unsaved changes' : 'All changes saved'}</span><button className="editor-save-button" disabled={!Object.keys(draft).length || save.isPending || !String(values.workspaceName ?? 'ok').trim() || Object.values(readStudentProfile(values)).some((value) => !value)} onClick={() => save.mutate(draft)}>{save.isPending ? 'Saving…' : 'Save preferences'}</button></footer>}
    </div>
    </div>
  </section>
}

function HardwareDetails({ report, formatBytes }: { report: LumiHardwareReport; formatBytes: (bytes?: number | null) => string }) {
  return <><p>{report.supported ? 'Hardware inventory available.' : 'Hardware inventory is not supported on this backend host.'}</p><dl className="diagnostics-grid"><dt>Processor</dt><dd>{report.cpu?.name ?? 'Not reported'}{report.cpu?.threads ? ` · ${report.cpu.threads} threads` : ''}</dd><dt>System memory</dt><dd>{formatBytes(report.memory?.totalBytes)} total · {formatBytes(report.memory?.availableBytes)} available</dd><dt>Ollama</dt><dd>{report.ollama?.available ? `Available${report.ollama.version ? ` · v${report.ollama.version}` : ''}` : 'Not detected'}</dd><dt>Model runtime</dt><dd>{report.ollama?.runningModels?.length ? report.ollama.runningModels.join(', ') : 'No models currently running'}</dd><dt>Storage</dt><dd>{formatBytes(report.storage?.availableBytes)} available · {report.storage?.note ?? report.storage?.source ?? 'No details reported'}</dd><dt>Checked</dt><dd>{report.checkedAt ? new Date(report.checkedAt).toLocaleString() : 'Not reported'}</dd></dl>{report.gpus?.length ? <div className="hardware-gpus"><h3>Graphics devices</h3>{report.gpus.map((gpu) => <article key={`${gpu.vendor}-${gpu.name}`}><strong>{gpu.name ?? 'Graphics device'}</strong><p>{gpu.vendor ?? 'Unknown vendor'} · {gpu.memoryType ?? 'memory unknown'} · {gpu.runtimeVerified ? 'Runtime verified' : 'Device detected; runtime not verified'}</p>{gpu.note && <small>{gpu.note}</small>}</article>)}</div> : <p>No graphics devices reported.</p>}</>
}
