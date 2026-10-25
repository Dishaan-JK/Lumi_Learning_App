// Disposable browser checks against the built React app and synthetic API data.
// Never connects to the user's backend, saved chats, or model provider.
import assert from 'node:assert/strict'
import { createServer } from 'node:http'
import { mkdtemp, mkdir, readFile, writeFile, rm } from 'node:fs/promises'
import { spawn } from 'node:child_process'
import { tmpdir } from 'node:os'
import { join, resolve, extname } from 'node:path'

const output = resolve(process.env.LUMI_UI_PROOF_DIR ?? join(tmpdir(), 'lumi-student-chat-proof'))
const browserProfile = await mkdtemp(join(tmpdir(), 'lumi-student-chat-browser-'))
await mkdir(output, { recursive: true })
let settings = { workspaceName: 'My workspace', theme: 'light', startPage: 'notes' }
let notes = [{ id: 'note-1', title: 'A place for curiosity', content: 'Keep learning.', updatedAt: '2026-10-25T00:00:00Z' }]
let deleted = false
const server = createServer(async (request, response) => {
  try {
    const url = new URL(request.url, 'http://localhost')
    const chunks = []
    for await (const chunk of request) chunks.push(chunk)
    const body = chunks.length ? JSON.parse(Buffer.concat(chunks).toString()) : {}
    const json = (value) => { response.writeHead(200, { 'Content-Type': 'application/json' }); response.end(JSON.stringify(value)) }
    if (url.pathname === '/api/application-settings') { if (request.method === 'PUT') settings = { ...settings, ...body }; return json(settings) }
    if (url.pathname === '/api/notes') return json(notes)
    if (url.pathname === '/api/assistant/getSnapshot') return json({ state: { messages: [] } })
    if (url.pathname === '/api/assistant') {
      notes = [...notes, { id: 'agent-note', title: 'Quantum Mechanics', content: 'A study note on quantum mechanics.', updatedAt: '2026-10-25T01:00:00Z' }]
      response.writeHead(200, { 'Content-Type': 'text/event-stream' })
      return response.end([{ message: { modelChunk: { content: [{ text: 'Mira, your Quantum Mechanics note is ready.' }] } } }, { result: { sessionId: 'test-session' } }].map((value) => `data: ${JSON.stringify(value)}\n\n`).join(''))
    }
    if (url.pathname === '/api/agent-sessions/test-session' && request.method === 'DELETE') { deleted = true; return json({ deleted: true }) }
    if (url.pathname.startsWith('/api/')) return json([])
    const path = url.pathname.startsWith('/assets/') || url.pathname.endsWith('.svg') ? join(resolve('dist'), url.pathname) : resolve('dist/index.html')
    const content = await readFile(path)
    response.writeHead(200, { 'Content-Type': ({ '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.html': 'text/html' })[extname(path)] ?? 'application/octet-stream' })
    response.end(content)
  } catch { response.writeHead(500); response.end('Fixture server failed') }
})
await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve))
const origin = `http://127.0.0.1:${server.address().port}`
const browser = spawn(process.env.LUMI_CHROME_BINARY ?? 'google-chrome', ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${browserProfile}`, '--no-first-run', '--disable-default-apps', '--disable-background-networking', 'about:blank'], { stdio: 'ignore' })
let socket
try {
  let port
  for (let attempt = 0; attempt < 100; attempt++) {
    try { port = (await readFile(join(browserProfile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]; break } catch { await new Promise((resolve) => setTimeout(resolve, 100)) }
  }
  assert(port, 'Disposable Chrome did not start')
  const pages = await (await fetch(`http://127.0.0.1:${port}/json`)).json()
  socket = new WebSocket(pages.find((page) => page.type === 'page').webSocketDebuggerUrl)
  await new Promise((resolve, reject) => { socket.addEventListener('open', resolve, { once: true }); socket.addEventListener('error', reject, { once: true }) })
  let nextId = 0
  const pending = new Map(), runtimeErrors = []
  socket.addEventListener('message', ({ data }) => {
    const message = JSON.parse(data)
    if (message.method === 'Runtime.exceptionThrown') runtimeErrors.push(message.params.exceptionDetails.text)
    if (!message.id) return
    const callback = pending.get(message.id); pending.delete(message.id)
    if (message.error) callback?.reject(new Error(message.error.message)); else callback?.resolve(message.result)
  })
  const call = (method, params = {}) => new Promise((resolve, reject) => { const id = ++nextId; pending.set(id, { resolve, reject }); socket.send(JSON.stringify({ id, method, params })) })
  const evaluate = async (expression) => {
    const result = await call('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true })
    if (result.exceptionDetails) throw new Error(result.exceptionDetails.text)
    return result.result.value
  }
  const waitFor = async (expression) => {
    for (let attempt = 0; attempt < 80; attempt++) { if (await evaluate(expression)) return; await new Promise((resolve) => setTimeout(resolve, 100)) }
    throw new Error(`Timed out: ${expression}`)
  }
  const screenshot = async (name) => { const result = await call('Page.captureScreenshot', { format: 'png' }); await writeFile(join(output, name), Buffer.from(result.data, 'base64')) }
  const input = async (selector, value) => evaluate(`(() => { const el = document.querySelector(${JSON.stringify(selector)}); const prototype = el.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype; Object.getOwnPropertyDescriptor(prototype, 'value').set.call(el, ${JSON.stringify(value)}); el.dispatchEvent(new Event('input', { bubbles: true })); })()`)
  await call('Page.enable'); await call('Runtime.enable')
  await call('Emulation.setDeviceMetricsOverride', { width: 1440, height: 1000, deviceScaleFactor: 1, mobile: false })
  await call('Page.navigate', { url: `${origin}/notes` })
  await waitFor("Boolean(document.querySelector('#student-name'))")
  await screenshot('onboarding-desktop.png')
  await input('#student-name', 'Mira'); await input('#student-studentClass', 'Class 9'); await input('#student-schoolName', 'Sample School')
  await evaluate("document.querySelector('.student-profile-form button').click()")
  await waitFor("Boolean(document.querySelector('.app-shell'))")
  assert.equal(settings.studentProfileCompleted, true)
  await evaluate("document.querySelector('.coach-trigger').click()")
  await waitFor("document.querySelector('.coach-welcome h2')?.textContent === 'Hello, Mira.'")
  await input('#coach-message', 'Create a quantum mechanics note')
  await evaluate("document.querySelector('.coach-compose button').click()")
  await waitFor("document.querySelector('#note-title')?.value === 'Quantum Mechanics' && document.querySelector('.coach-messages')?.textContent.includes('Mira, your Quantum Mechanics note is ready.')")
  assert.equal(await evaluate("document.querySelector('.coach-speaker')?.parentElement.querySelector('.coach-message').contains(document.querySelector('.coach-speaker'))"), false)
  assert.equal(await evaluate("getComputedStyle(document.querySelector('#panel-width-coach')).backgroundImage.includes('linear-gradient')"), true)
  await screenshot('chat-desktop.png')
  await evaluate("document.querySelector('.coach-new-chat').click()")
  await waitFor("Boolean(document.querySelector('.coach-welcome'))")
  await evaluate("document.querySelector('[aria-label=\"Close Coach\"]').click(); document.querySelector('.coach-trigger').click()")
  await waitFor("document.querySelector('.coach-welcome h2')?.textContent === 'Hello, Mira.'")
  await call('Emulation.setDeviceMetricsOverride', { width: 375, height: 812, deviceScaleFactor: 1, mobile: true })
  await waitFor("document.querySelector('.coach-drawer').getBoundingClientRect().width <= 375")
  assert.equal(await evaluate('document.documentElement.scrollWidth <= window.innerWidth'), true)
  await screenshot('chat-mobile.png')
  await call('Emulation.setDeviceMetricsOverride', { width: 1440, height: 1000, deviceScaleFactor: 1, mobile: false })
  await evaluate("document.querySelector('[aria-label=\"Close Coach\"]').click()")
  await evaluate("document.querySelector('.recent-chat-row .note-row').dispatchEvent(new MouseEvent('contextmenu', { bubbles: true, cancelable: true, clientX: 80, clientY: 500 }))")
  await waitFor("Boolean(document.querySelector('[role=menu]'))")
  await screenshot('chat-options-desktop.png')
  await evaluate("window.confirm = () => true; document.querySelector('.chat-menu-delete').click()")
  await waitFor("!document.querySelector('.recent-chat-row')")
  assert.equal(deleted, true)
  await call('Page.reload')
  await waitFor("Boolean(document.querySelector('.app-shell'))")
  assert.equal(await evaluate("Boolean(document.querySelector('.student-welcome'))"), false)
  assert.deepEqual(runtimeErrors, [])
  console.log(JSON.stringify({ passed: ['onboarding save', 'returning student', 'personalized greeting', 'agent-created note opens', 'external speaker labels', 'visible slider track', 'New Chat', '375px reflow', 'right-click menu', 'saved chat deletion'], screenshots: output, runtimeErrors }, null, 2))
} finally {
  socket?.close()
  browser.kill('SIGTERM')
  await new Promise((resolve) => browser.exitCode !== null ? resolve() : browser.once('exit', resolve))
  await new Promise((resolve) => server.close(resolve))
  await rm(browserProfile, { recursive: true, force: true })
}
