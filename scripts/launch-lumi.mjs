import { existsSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { spawn, spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const backendRoot = join(projectRoot, 'backend')
const isWindows = process.platform === 'win32'
const npm = isWindows ? 'npm.cmd' : 'npm'
const port = Number(process.env.LUMI_FRONTEND_PORT ?? 5173)

function run(command, args, { cwd = projectRoot, env = process.env } = {}) {
  return new Promise((resolveRun, rejectRun) => {
    const child = spawn(command, args, {
      cwd,
      env,
      stdio: 'inherit',
      shell: isWindows,
    })
    child.once('error', rejectRun)
    child.once('exit', (code, signal) => {
      if (code === 0) resolveRun()
      else rejectRun(new Error(`${command} ${args.join(' ')} exited ${signal ? `from ${signal}` : `with code ${code}`}.`))
    })
  })
}

function capture(command, args) {
  return spawnSync(command, args, {
    cwd: projectRoot,
    encoding: 'utf8',
    shell: isWindows,
    stdio: ['ignore', 'pipe', 'pipe'],
  })
}

function findDartExecutable() {
  if (process.env.LUMI_DART_EXECUTABLE) return process.env.LUMI_DART_EXECUTABLE

  const where = capture(isWindows ? 'where.exe' : 'which', ['dart'])
  const dartOnPath = (where.stdout ?? '').split(/\r?\n/).find(Boolean)
  if (dartOnPath && /[\\/]flutter[\\/]bin[\\/]dart(?:\.bat|\.cmd)?$/i.test(dartOnPath)) {
    const cachedDart = join(dirname(dartOnPath), 'cache', 'dart-sdk', 'bin', isWindows ? 'dart.exe' : 'dart')
    if (existsSync(cachedDart)) return cachedDart
  }
  return 'dart'
}

function checkDart(dart) {
  const result = capture(dart, ['--version'])
  const versionOutput = `${result.stdout ?? ''}\n${result.stderr ?? ''}`
  if (result.error || result.status !== 0) {
    throw new Error(`Could not run Dart (${dart}). Install Dart 3.12 or newer, or set LUMI_DART_EXECUTABLE to its executable path.`)
  }
  const match = versionOutput.match(/Dart SDK version:\s*(\d+)\.(\d+)\.(\d+)/i)
  if (match && (Number(match[1]) < 3 || (Number(match[1]) === 3 && Number(match[2]) < 12))) {
    throw new Error(`Dart 3.12 or newer is required; found ${match[1]}.${match[2]}.${match[3]}.`)
  }
  console.log(`Using ${versionOutput.trim().split(/\r?\n/).at(-1)}.`)
}

function checkProjectFiles() {
  for (const path of ['package.json', 'package-lock.json', 'backend/pubspec.yaml', 'backend/bin/server.dart']) {
    if (!existsSync(join(projectRoot, path))) throw new Error(`Required project file is missing: ${path}`)
  }
}

async function prepareDependencies(dart, env) {
  const vite = join(projectRoot, 'node_modules', '.bin', isWindows ? 'vite.cmd' : 'vite')
  if (!existsSync(vite)) {
    console.log('Installing Node dependencies with npm ci...')
    await run(npm, ['ci'], { env })
  }

  console.log('Preparing Dart backend dependencies...')
  const pubArgs = ['pub', 'get', ...(env.LUMI_PUB_OFFLINE === '1' ? ['--offline'] : [])]
  await run(dart, pubArgs, { cwd: backendRoot, env })
}

function openDefaultBrowser(url) {
  const candidates = process.platform === 'win32'
    ? [['rundll32.exe', ['url.dll,FileProtocolHandler', url]]]
    : process.platform === 'darwin'
      ? [['open', [url]]]
      : [['xdg-open', [url]], ['gio', ['open', url]]]

  for (const [command, args] of candidates) {
    const available = capture(isWindows ? 'where.exe' : 'which', [command])
    if (available.status !== 0) continue
    const browser = spawn(command, args, { detached: true, stdio: 'ignore', shell: isWindows })
    browser.once('error', () => console.error(`Could not open a browser automatically. Open ${url} manually.`))
    browser.unref()
    return
  }
  console.error(`No default-browser launcher was found. Open ${url} manually.`)
}

async function waitForApp(child, appUrl, getServerExit, timeoutMs = 180_000) {
  let childExit
  child.once('exit', (code, signal) => { childExit = { code, signal } })
  const started = Date.now()

  while (Date.now() - started < timeoutMs) {
    const exit = childExit ?? getServerExit()
    if (exit) {
      if (exit.error) throw exit.error
      throw new Error(`The Lumi server stopped before becoming ready (${exit.signal ?? exit.code}).`)
    }
    try {
      const [page, api] = await Promise.all([
        fetch(appUrl),
        fetch(new URL('/api/notes', appUrl)),
      ])
      const html = await page.text()
      if (page.ok && html.includes('id="root"') && api.ok) return
    } catch {
      // The backend and Vite server are still starting.
    }
    await new Promise((resolveWait) => setTimeout(resolveWait, 1000))
  }
  throw new Error(`Lumi did not pass its browser and API readiness checks within ${timeoutMs / 1000} seconds.`)
}

async function main() {
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error(`LUMI_FRONTEND_PORT must be a valid TCP port; received ${process.env.LUMI_FRONTEND_PORT}.`)
  }
  checkProjectFiles()

  const nodeMajor = Number(process.versions.node.split('.')[0])
  if (nodeMajor < 22) throw new Error(`Node.js 22 or newer is required; found ${process.versions.node}.`)
  const npmVersion = capture(npm, ['--version'])
  if (npmVersion.error || npmVersion.status !== 0) throw new Error('npm is required but was not found on PATH.')

  const dart = findDartExecutable()
  checkDart(dart)
  const env = { ...process.env, LUMI_DART_EXECUTABLE: dart }

  await prepareDependencies(dart, env)
  console.log('Checking the React production build...')
  await run(npm, ['run', 'build'], { env })

  const appUrl = `http://127.0.0.1:${port}/`
  console.log('Starting Lumi backend and React app...')
  const server = spawn(npm, ['run', 'dev:full'], {
    cwd: projectRoot,
    env,
    stdio: 'inherit',
    shell: isWindows,
  })
  let serverExit
  const serverExited = new Promise((resolveExit) => {
    server.once('error', (error) => {
      serverExit = { error }
      resolveExit(serverExit)
    })
    server.once('exit', (code, signal) => {
      serverExit = { code, signal }
      resolveExit(serverExit)
    })
  })
  const stopServer = (signal) => server.kill(signal)
  process.once('SIGINT', stopServer)
  process.once('SIGTERM', stopServer)

  try {
    await waitForApp(server, appUrl, () => serverExit)
    console.log(`Lumi is ready at ${appUrl}`)
    openDefaultBrowser(appUrl)
    const result = await serverExited
    if (result.error) throw result.error
    if (result.code !== 0 && result.signal !== 'SIGINT' && result.signal !== 'SIGTERM') {
      throw new Error(`The Lumi server exited with code ${result.code}.`)
    }
  } catch (error) {
    if (!serverExit) server.kill('SIGTERM')
    throw error
  } finally {
    process.removeListener('SIGINT', stopServer)
    process.removeListener('SIGTERM', stopServer)
  }
}

main().catch((error) => {
  console.error(`Lumi could not start: ${error.message}`)
  process.exitCode = 1
})
