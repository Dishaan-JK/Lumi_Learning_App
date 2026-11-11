import { existsSync } from 'node:fs'
import { join } from 'node:path'
import { spawn } from 'node:child_process'

const projectRoot = join(import.meta.dirname, '..')
const backendRoot = join(projectRoot, 'backend')
const backendUrl = process.env.LUMI_BACKEND_URL ?? 'http://127.0.0.1:8080'
const frontendPort = process.env.LUMI_FRONTEND_PORT ?? '5173'
const localDevOrigins = `http://127.0.0.1:${frontendPort},http://localhost:${frontendPort}`
const dart = process.env.LUMI_DART_EXECUTABLE ?? 'dart'

async function isReachable() {
  try {
    return (await fetch(`${backendUrl}/api/notes`)).ok
  } catch {
    return false
  }
}

if (await isReachable()) {
  console.log(`Lumi backend is already available at ${backendUrl}; not starting a duplicate process.`)
  process.exit(0)
}

if (!existsSync(join(backendRoot, '.dart_tool/package_config.json'))) {
  const setup = spawn(dart, ['pub', 'get'], { cwd: backendRoot, stdio: 'inherit' })
  const code = await new Promise((resolve) => setup.on('exit', resolve))
  if (code !== 0) throw new Error('Could not prepare the bundled Lumi backend dependencies with dart pub get.')
}

const child = spawn(dart, ['run', 'bin/server.dart'], {
  cwd: backendRoot,
  env: {
    ...process.env,
    // The backend rejects every browser origin unless it is explicitly named.
    // Keep the default limited to this local Vite instance; deployments should
    // set LUMI_ALLOWED_ORIGINS themselves.
    LUMI_ALLOWED_ORIGINS: process.env.LUMI_ALLOWED_ORIGINS ?? localDevOrigins,
  },
  stdio: 'inherit',
})

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => child.kill(signal))
}

child.on('exit', (code) => process.exit(code ?? 1))
