import { act, renderHook } from '@testing-library/react'
import { beforeEach, describe, expect, it } from 'vitest'
import { useWorkspaceNavigation } from './workspace-navigation'

beforeEach(() => {
  localStorage.clear()
  window.history.replaceState({}, '', '/')
})

describe('workspace session navigation', () => {
  it('restores the last selected canvas when reopened at the root', () => {
    const first = renderHook(() => useWorkspaceNavigation('home'))
    act(() => first.result.current.navigate('canvas', { fileId: 'board-1' }))
    first.unmount()
    window.history.replaceState({}, '', '/')
    const reopened = renderHook(() => useWorkspaceNavigation('home'))
    expect(reopened.result.current.route).toMatchObject({ view: 'canvas', fileId: 'board-1' })
    expect(window.location.pathname + window.location.search).toBe('/canvas?file=board-1')
  })

  it('honors explicit links and ignores invalid saved locations', () => {
    localStorage.setItem('lumi.workspace.last-route', 'https://example.com/canvas?file=other')
    window.history.replaceState({}, '', '/notes?note=existing')
    const explicit = renderHook(() => useWorkspaceNavigation('home'))
    expect(explicit.result.current.route).toMatchObject({ view: 'notes', noteId: 'existing' })
    explicit.unmount()
    localStorage.setItem('lumi.workspace.last-route', 'https://example.com/canvas?file=other')
    window.history.replaceState({}, '', '/')
    const root = renderHook(() => useWorkspaceNavigation('home'))
    expect(root.result.current.route.view).toBe('home')
  })
})
