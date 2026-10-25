# Shared primitives
React 19 / TypeScript / Vite, custom CSS, Lucide icons, no component library. Buttons, cards and form controls are inline HTML.
## src/features/layout/PanelWidthSlider.tsx

```tsx
import { useEffect, useState } from 'react'
import { LAYOUT_WIDTHS_UPDATED_EVENT, readLayoutWidths, saveLayoutWidths, type LayoutWidths } from '../../lib/layout-widths'

type ResizablePanel = keyof LayoutWidths

const panelRanges: Record<ResizablePanel, { min: number; max: number; step: number }> = {
  sidebar: { min: 200, max: 360, step: 8 },
  coach: { min: 360, max: 760, step: 20 },
}

export function PanelWidthSlider({ panel, label }: { panel: ResizablePanel; label: string }) {
  const [width, setWidth] = useState(() => readLayoutWidths()[panel])
  const id = `panel-width-${panel}`

  useEffect(() => {
    const syncWidth = () => setWidth(readLayoutWidths()[panel])
    window.addEventListener(LAYOUT_WIDTHS_UPDATED_EVENT, syncWidth)
    return () => window.removeEventListener(LAYOUT_WIDTHS_UPDATED_EVENT, syncWidth)
  }, [panel])

  function updateWidth(value: number) {
    setWidth(value)
    saveLayoutWidths({ ...readLayoutWidths(), [panel]: value })
  }

  return <label className={`panel-width-control panel-width-control--${panel}`} htmlFor={id}>
    <span>{label}</span>
    <output htmlFor={id}>{width} px</output>
    <input id={id} type="range" aria-label={`${label} in pixels`} min={panelRanges[panel].min} max={panelRanges[panel].max} step={panelRanges[panel].step} value={width} onChange={(event) => updateWidth(Number(event.currentTarget.value))} />
  </label>
}

```
