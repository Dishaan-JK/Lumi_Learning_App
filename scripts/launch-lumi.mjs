import { existsSync } from 'node:fs'
import { cp, readFile, writeFile } from 'node:fs/promises'
import { dirname, join, resolve } from 'node:path'
import { spawn, spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { createInterface } from 'node:readline/promises'
import { stdin, stdout } from 'node:process'
import { createHash } from 'node:crypto'

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

async function hashFiles(paths) {
  try {
    const hash = createHash('sha256')
    for (const path of paths) hash.update(await readFile(path))
    return hash.digest('hex')
  } catch {
    return null
  }
}

async function prepareDependencies(dart, env) {
  const vite = join(projectRoot, 'node_modules', '.bin', isWindows ? 'vite.cmd' : 'vite')
  const npmState = join(projectRoot, 'node_modules', '.lumi-package-lock-hash')
  const packageLockHash = await hashFiles([join(projectRoot, 'package-lock.json')])
  let installedPackageLockHash
  try { installedPackageLockHash = await readFile(npmState, 'utf8') } catch { installedPackageLockHash = '' }
  if (!existsSync(vite) || !packageLockHash || installedPackageLockHash.trim() !== packageLockHash) {
    console.log('Installing or updating the React app packages with npm ci...')
    await run(npm, ['ci'], { env })
    if (packageLockHash) await writeFile(npmState, packageLockHash, 'utf8')
  }

  const dartConfig = join(backendRoot, '.dart_tool', 'package_config.json')
  const dartState = join(backendRoot, '.dart_tool', '.lumi-package-lock-hash')
  const dartLockHash = await hashFiles([join(backendRoot, 'pubspec.yaml'), join(backendRoot, 'pubspec.lock')])
  let installedDartLockHash
  try { installedDartLockHash = await readFile(dartState, 'utf8') } catch { installedDartLockHash = '' }
  if (!existsSync(dartConfig) || !dartLockHash || installedDartLockHash.trim() !== dartLockHash) {
    console.log('Preparing or updating the Lumi backend packages...')
    const pubArgs = ['pub', 'get', ...(env.LUMI_PUB_OFFLINE === '1' ? ['--offline'] : [])]
    await run(dart, pubArgs, { cwd: backendRoot, env })
    if (dartLockHash) await writeFile(dartState, dartLockHash, 'utf8')
  }
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

async function waitForBackend(backendUrl, getExit, timeoutMs = 180_000) {
  const started = Date.now()
  while (Date.now() - started < timeoutMs) {
    const exit = getExit()
    if (exit && (exit.error || exit.code !== 0)) {
      if (exit.error) throw exit.error
      throw new Error(`Lumi's backend stopped before becoming ready (${exit.signal ?? exit.code}).`)
    }
    try {
      if ((await fetch(new URL('/api/notes', backendUrl))).ok) return
    } catch {
      // The local Dart service is still starting.
    }
    await new Promise((resolveWait) => setTimeout(resolveWait, 1000))
  }
  throw new Error(`Lumi's backend did not respond at ${backendUrl} within ${timeoutMs / 1000} seconds.`)
}

async function isCorsAllowed(backendUrl, frontendPort) {
  const origins = [`http://127.0.0.1:${frontendPort}`, `http://localhost:${frontendPort}`]
  const results = await Promise.all(origins.map(async (origin) => {
    try {
      const response = await fetch(new URL('/api/settings/models', backendUrl), {
        method: 'OPTIONS',
        headers: {
          Origin: origin,
          'Access-Control-Request-Method': 'POST',
          'Access-Control-Request-Headers': 'content-type',
        },
      })
      return response.status === 204 && response.headers.get('access-control-allow-origin') === origin
    } catch {
      return false
    }
  }))
  return results.every(Boolean)
}

async function askToOpenBrowser(marker) {
  if (process.env.LUMI_PROMPT_OPEN !== '1' || !marker || existsSync(marker)) return true

  const prompt = createInterface({ input: stdin, output: stdout })
  let answer
  try {
    answer = await prompt.question('Open Lumi Web App in your default browser? [Y/n] ')
  } finally {
    prompt.close()
  }
  await writeFile(marker, new Date().toISOString(), 'utf8')
  return !/^(n|no)$/i.test(answer.trim())
}

async function reuseRunningApp(appUrl, backendUrl) {
  let page
  try {
    page = await fetch(appUrl)
  } catch {
    return false
  }
  const html = await page.text()
  if (!page.ok || !html.includes('id="root"')) {
    throw new Error(`Port ${port} is already serving another page. Close it or set LUMI_FRONTEND_PORT to a free port.`)
  }
  try {
    if ((await fetch(new URL('/api/notes', appUrl))).ok) return true
  } catch {
    // The page exists but its local backend is unavailable.
  }
  throw new Error(`Lumi's page is already open on port ${port}, but its backend is not responding at ${backendUrl}.`)
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
  const appUrl = `http://127.0.0.1:${port}/`
  const backendUrl = process.env.LUMI_BACKEND_URL ?? 'http://127.0.0.1:8080'

  if (await reuseRunningApp(appUrl, backendUrl)) {
    console.log(`Lumi is already running at ${appUrl}`)
    if (await askToOpenBrowser(process.env.LUMI_SETUP_MARKER)) openDefaultBrowser(appUrl)
    else console.log(`Lumi is running. Open ${appUrl} in a browser when you want to use it.`)
    return
  }

  await prepareDependencies(dart, env)

  const webDirectory = resolve(projectRoot, env.LUMI_WEB_DIR ?? 'lumi-web')
  if (!existsSync(join(webDirectory, 'index.html'))) {
    const bundledDirectory = join(projectRoot, 'dist')
    if (!existsSync(join(bundledDirectory, 'index.html'))) throw new Error('The React web bundle is missing. Extract the branch dist/ bundle into lumi-web first.')
    await cp(bundledDirectory, webDirectory, { recursive: true })
  }
  const indexHtml = await readFile(join(webDirectory, 'index.html'), 'utf8')
  if (!indexHtml.includes('id="root"')) throw new Error(`The React bundle at ${webDirectory} does not contain the Lumi app entry point.`)

  console.log('Starting the Lumi backend...')
  const backendProcess = spawn(process.execPath, ['scripts/start-lumi-backend.mjs'], {
    cwd: projectRoot,
    env: { ...env, LUMI_FRONTEND_PORT: String(port) },
    stdio: 'inherit',
  })
  let backendExit
  backendProcess.once('error', (error) => { backendExit = { error } })
  backendProcess.once('exit', (code, signal) => {
    backendExit = { code, signal }
  })
  let frontendProcess
  let frontendExit
  const stopServices = (signal) => {
    frontendProcess?.kill(signal)
    if (!backendExit) backendProcess.kill(signal)
  }
  process.once('SIGINT', stopServices)
  process.once('SIGTERM', stopServices)

  try {
    await waitForBackend(backendUrl, () => backendExit)
    if (backendExit?.error) throw backendExit.error
    if (!await isCorsAllowed(backendUrl, port)) {
      throw new Error(`The backend does not allow the Lumi address on port ${port}. Close any old backend and run lumi again.`)
    }

    console.log('Starting the React Web App...')
    frontendProcess = spawn(npm, ['run', 'preview', '--', '--host', '127.0.0.1', '--port', String(port), '--strictPort'], {
      cwd: projectRoot,
      env: { ...env, LUMI_WEB_DIR: webDirectory, LUMI_FRONTEND_PORT: String(port) },
      stdio: 'inherit',
      shell: isWindows,
    })
    const frontendExited = new Promise((resolveExit) => {
      frontendProcess.once('error', (error) => {
        frontendExit = { error }
        resolveExit(frontendExit)
      })
      frontendProcess.once('exit', (code, signal) => {
        frontendExit = { code, signal }
        resolveExit(frontendExit)
      })
    })

    await waitForApp(frontendProcess, appUrl, () => frontendExit)
    console.log(`Lumi's frontend and backend are ready at ${appUrl}`)
    const openBrowser = await askToOpenBrowser(process.env.LUMI_SETUP_MARKER)
    if (openBrowser) openDefaultBrowser(appUrl)
    else console.log(`Lumi is running. Open ${appUrl} in a browser when you want to use it.`)

    const result = await frontendExited
    if (result.error) throw result.error
    if (result.code !== 0 && result.signal !== 'SIGINT' && result.signal !== 'SIGTERM') {
      throw new Error(`The Lumi Web App exited with code ${result.code}.`)
    }
  } catch (error) {
    frontendProcess?.kill('SIGTERM')
    if (!backendExit) backendProcess.kill('SIGTERM')
    throw error
  } finally {
    process.removeListener('SIGINT', stopServices)
    process.removeListener('SIGTERM', stopServices)
  }
}

main().catch((error) => {
  console.error(`Lumi could not start: ${error.message}`)
  process.exitCode = 1
})
