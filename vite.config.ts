import react from '@vitejs/plugin-react'
import { defineConfig } from 'vitest/config'

// https://vite.dev/config/
const apiProxy = {
  '/api': {
    target: process.env.LUMI_BACKEND_URL ?? 'http://127.0.0.1:8080',
    changeOrigin: true,
  },
}

export default defineConfig({
  plugins: [react()],
  build: {
    outDir: process.env.LUMI_WEB_DIR ?? 'dist',
  },
  server: {
    port: Number(process.env.LUMI_FRONTEND_PORT ?? 5173),
    strictPort: true,
    proxy: apiProxy,
  },
  preview: {
    port: Number(process.env.LUMI_FRONTEND_PORT ?? 5173),
    strictPort: true,
    proxy: apiProxy,
  },
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
  },
})
