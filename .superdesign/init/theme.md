# Tokens
Warm paper #F4F1E8, warm white #FFFCF5, ink #292D28, sage #71836A, terracotta #B8795E. UI: DM Sans with system sans fallback, editorial titles: Lora. Dark theme via data-theme. 4/8px spacing, 8-12px control radii, thin borders. Coach width 360-760px, default 460px. Breakpoints and exact theme overrides follow.
## src/index.css

```css
:root {
  color: #292d28;
  background: #f4f1e8;
  font-family: "DM Sans", ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  font-synthesis: none;
  text-rendering: optimizeLegibility;
  -webkit-font-smoothing: antialiased;
}

* { box-sizing: border-box; }
body { margin: 0; min-width: 320px; min-height: 100vh; }
button, input { font: inherit; }
button { cursor: pointer; }
button:focus-visible { outline: 3px solid #b8795e; outline-offset: 3px; }
.sr-only { position: absolute; width: 1px; height: 1px; padding: 0; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }

```
## src/App.css

```css
.app-shell { min-height: 100svh; display: grid; grid-template-columns: var(--sidebar-width, 264px) minmax(0, 1fr) 84px; background: #f4f1e8; color: #292d28; }
.workspace-nav { display: flex; flex-direction: column; min-height: 100svh; border-right: 1px solid #e2ddd2; background: #f8f5ed; z-index: 3; }
.nav-header { padding: 24px 16px 14px; }
.brand { display: flex; align-items: center; gap: 10px; margin: 0 8px 26px; font: 600 22px/1 "Lora", Georgia, serif; letter-spacing: -.03em; }
.brand-mark { display: block; width: 32px; height: 32px; flex: 0 0 auto; border-radius: 9px; }
.new-note-button, .search-button, .nav-item, .folder-row, .note-row { width: 100%; border: 0; background: transparent; color: #596056; display: flex; align-items: center; gap: 11px; text-align: left; }
.new-note-button { justify-content: center; min-height: 42px; border-radius: 10px; background: #71836a; color: #fffcf5; font-weight: 650; }
.new-note-button:disabled { cursor: wait; opacity: .72; }
.new-note-button svg { width: 17px; }
.search-button { margin-top: 10px; padding: 10px 12px; border-radius: 9px; background: rgba(41,45,40,.05); font-size: 14px; }
.search-button span { flex: 1; }
kbd { border-radius: 5px; padding: 2px 5px; background: rgba(41,45,40,.06); color: #737a70; font: 12px ui-monospace, monospace; }
.nav-scroll { flex: 1; overflow-y: auto; padding: 6px 10px 24px; }
.nav-group { display: grid; gap: 2px; margin-bottom: 28px; }
.nav-item { min-height: 40px; border-radius: 9px; padding: 0 12px; font-size: 14px; }
.nav-item svg, .folder-row svg, .note-row svg { flex: 0 0 auto; width: 17px; }
.nav-item:hover, .folder-row:hover, .note-row:hover { background: rgba(41,45,40,.05); color: #292d28; }
.nav-item.is-active, .note-row.is-selected { background: rgba(113,131,106,.14); color: #587150; font-weight: 650; }
.nav-section { margin: 0 0 27px; }
.section-heading { display: flex; align-items: center; justify-content: space-between; padding: 0 10px 7px; }
.section-heading h2, .eyebrow, .editor-kicker { margin: 0; color: #747a6e; font-size: 11px; font-weight: 750; letter-spacing: .09em; text-transform: uppercase; }
.small-icon-button { display: grid; place-items: center; width: 26px; height: 26px; border: 0; border-radius: 7px; background: transparent; color: #747a6e; }
.small-icon-button:disabled { cursor: not-allowed; opacity: .45; }
.folder-row-wrap { display: flex; align-items: center; border-radius: 8px; }.folder-row-wrap.is-selected { background: rgba(113,131,106,.14); color: #587150; }.folder-row-wrap:hover { background: rgba(41,45,40,.05); }.folder-row, .note-row { min-height: 34px; border-radius: 8px; padding: 0 10px; font-size: 13px; }.folder-row { flex: 1; min-width: 0; }.folder-row-wrap.is-selected .folder-row { color: #587150; font-weight: 650; }.folder-action { display: grid; flex: 0 0 auto; place-items: center; width: 25px; height: 25px; border: 0; border-radius: 6px; background: transparent; color: #858b80; opacity: 0; }.folder-row-wrap:hover .folder-action, .folder-row-wrap:focus-within .folder-action { opacity: 1; }.folder-action:hover { background: rgba(41,45,40,.08); color: #42483f; }.folder-action svg { width: 13px; }.folder-create-form { display: grid; grid-template-columns: minmax(0,1fr) auto; gap: 5px; margin: 4px 4px 8px; }.folder-create-form input,.folder-create-form select { min-width: 0; width: 100%; height: 31px; border: 1px solid #d9d3c6; border-radius: 7px; background: #fffcf5; padding: 0 7px; color: #292d28; font-size: 12px; }.folder-create-form input { grid-column: 1 / -1; }.folder-create-form button { border: 0; border-radius: 7px; background: #71836a; color: #fffcf5; padding: 0 8px; font-size: 11px; font-weight: 700; }.folder-create-form button:disabled { opacity: .5; }
.note-row span { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.nav-empty { margin: 2px 10px; color: #8b9087; font-size: 13px; line-height: 1.45; }
.nav-loading { height: 78px; margin: 0 10px; border-radius: 10px; background: linear-gradient(90deg, #ede8dc 20%, #f8f5ed 40%, #ede8dc 60%); background-size: 200% 100%; animation: pulse 1.3s linear infinite; }
.nav-footer { border-top: 1px solid #e2ddd2; padding: 12px 10px 16px; }
.local-label { display: block; padding: 9px 12px 0; color: #858b80; font-size: 11px; }
.workspace-main { width: min(100%, var(--workspace-width, 1200px)); min-width: 0; min-height: 100svh; justify-self: center; display: grid; grid-template-rows: 60px minmax(0, 1fr); }
.workspace-topbar { display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 0 32px; border-bottom: 1px solid #e2ddd2; }
.crumbs, .save-indicator { display: flex; align-items: center; gap: 7px; color: #747a6e; font-size: 13px; white-space: nowrap; overflow: hidden; }
.crumbs strong { overflow: hidden; color: #3f453d; font-weight: 650; text-overflow: ellipsis; }
.crumbs svg { width: 14px; flex: 0 0 auto; }.save-indicator { flex: 0 0 auto; }.save-dot { width: 7px; height: 7px; border-radius: 50%; background: #71836a; }.save-indicator.is-unsaved .save-dot { background: #b8795e; }.save-indicator.is-saving .save-dot { animation: pulse 1.3s linear infinite; }.save-indicator.is-error { color: #9c4d38; }.save-indicator.is-error .save-dot { background: #9c4d38; }
.workspace-content { overflow: auto; padding: 52px clamp(24px, 6vw, 96px); }
.editor-surface, .welcome-surface, .placeholder-surface, .error-surface { width: min(100%, 810px); min-height: min(720px, calc(100svh - 164px)); margin: 0 auto; border: 1px solid #e2ddd2; border-radius: 16px; background: #fffcf5; box-shadow: 0 12px 28px rgba(66, 58, 43, .06); padding: clamp(36px, 7vw, 76px); }
.editor-kicker { margin-bottom: 17px; }.welcome-surface h1, .placeholder-surface h1, .error-surface h1, .coach-card h2 { margin: 0; font-family: "Lora", Georgia, serif; font-weight: 500; letter-spacing: -.035em; color: #292d28; }
.editor-toolbar { display: flex; align-items: center; justify-content: space-between; gap: 16px; }.editor-toolbar .editor-kicker { margin: 0; }.editor-actions { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 7px; }.editor-actions select { min-height: 34px; max-width: 170px; border: 1px solid #d9d3c6; border-radius: 8px; background: #fffcf5; color: #53634e; padding: 0 8px; font-size: 12px; }.editor-save-button, .editor-delete-button { min-height: 34px; border: 1px solid #d9d3c6; border-radius: 8px; background: #f8f5ed; color: #53634e; padding: 0 11px; font-size: 12px; font-weight: 700; }.editor-delete-button { color: #9c4d38; }.editor-save-button:disabled { cursor: default; color: #92978f; background: transparent; }.note-title-input { width: 100%; margin: 17px 0 0; padding: 0; border: 0; outline: 0; background: transparent; color: #292d28; font: 500 clamp(31px, 4vw, 48px)/1.1 "Lora", Georgia, serif; letter-spacing: -.035em; }.note-title-input::placeholder, .note-body-input::placeholder { color: #9a9c91; }.note-body-input { display: block; width: 100%; min-height: 410px; resize: vertical; margin-top: 32px; padding: 0; border: 0; outline: 0; background: transparent; color: #42483f; font: 17px/1.8 "DM Sans", ui-sans-serif, system-ui, sans-serif; }.save-error { margin: 18px 0 0; color: #9c4d38; font-size: 14px; line-height: 1.5; }
.welcome-surface, .placeholder-surface, .error-surface { display: flex; flex-direction: column; justify-content: center; max-width: 700px; min-height: 420px; }.welcome-surface h1, .placeholder-surface h1, .error-surface h1 { max-width: 520px; margin-top: 15px; font-size: clamp(32px, 5vw, 52px); line-height: 1.08; }.welcome-surface p:not(.eyebrow), .placeholder-surface p:not(.eyebrow), .error-surface p:not(.eyebrow) { max-width: 510px; margin: 20px 0 0; color: #656b61; font-size: 16px; line-height: 1.65; }.error-surface button { align-self: flex-start; margin-top: 28px; min-height: 42px; border: 0; border-radius: 9px; background: #71836a; color: #fffcf5; padding: 0 17px; font-weight: 650; }
.loading-surface { display: grid; place-items: center; min-height: 340px; color: #656b61; gap: 14px; }.loading-orb { width: 28px; height: 28px; border: 3px solid #d6d1c5; border-top-color: #71836a; border-radius: 50%; animation: spin .7s linear infinite; }
.artifact-library { width: min(100%, 1100px); margin: 0 auto; }.library-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 24px; margin-bottom: 30px; }.library-header h1 { max-width: 560px; margin: 10px 0 0; color: #292d28; font: 500 clamp(34px, 4vw, 48px)/1.08 "Lora", Georgia, serif; letter-spacing: -.04em; }.library-header p:not(.eyebrow) { max-width: 600px; margin: 13px 0 0; color: #656b61; font-size: 16px; line-height: 1.6; }.library-refresh { min-height: 38px; flex: 0 0 auto; border: 1px solid #d9d3c6; border-radius: 8px; background: #fffcf5; color: #53634e; padding: 0 12px; font-size: 13px; font-weight: 700; }.library-refresh:disabled { cursor: wait; color: #92978f; }.artifact-search { display: flex; align-items: center; gap: 11px; border: 1px solid #d9d3c6; border-radius: 10px; background: #fffcf5; padding: 0 13px; color: #71836a; box-shadow: 0 4px 15px rgba(66,58,43,.03); }.artifact-search svg { width: 18px; }.artifact-search input { width: 100%; height: 50px; border: 0; outline: 0; background: transparent; color: #292d28; font: 15px "DM Sans", ui-sans-serif, system-ui, sans-serif; }.artifact-filters { display: flex; gap: 8px; overflow-x: auto; margin: 16px -2px 25px; padding: 2px; }.artifact-filters button { display: inline-flex; flex: 0 0 auto; align-items: center; gap: 7px; min-height: 32px; border: 1px solid #ded9cd; border-radius: 999px; background: #fffcf5; color: #656b61; padding: 0 10px 0 12px; font-size: 12px; font-weight: 650; }.artifact-filters button.is-active { border-color: #71836a; background: #71836a; color: #fffcf5; }.artifact-filters span { display: grid; min-width: 17px; height: 17px; place-items: center; border-radius: 50%; background: rgba(41,45,40,.07); font-size: 10px; }.artifact-filters button.is-active span { background: rgba(255,252,245,.18); }.artifact-layout { display: grid; grid-template-columns: minmax(0, 1fr); align-items: start; gap: 22px; }.artifact-layout.has-detail { grid-template-columns: minmax(0, 1fr) minmax(250px, 310px); }.artifact-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(210px, 1fr)); gap: 14px; }.artifact-card { min-height: 190px; display: flex; flex-direction: column; align-items: flex-start; border: 1px solid #e2ddd2; border-radius: 13px; background: #fffcf5; padding: 18px; color: #3f453d; text-align: left; box-shadow: 0 8px 20px rgba(66,58,43,.035); transition: transform 160ms ease, border-color 160ms ease, box-shadow 160ms ease; }.artifact-card:hover, .artifact-card:focus-visible, .artifact-card.is-selected { border-color: #aab8a5; box-shadow: 0 10px 24px rgba(66,58,43,.08); outline: 0; transform: translateY(-2px); }.artifact-kind { display: inline-flex; align-items: center; min-height: 21px; border-radius: 999px; background: rgba(113,131,106,.12); color: #587150; padding: 0 8px; font-size: 10px; font-weight: 750; letter-spacing: .045em; text-transform: uppercase; }.artifact-card strong { display: -webkit-box; overflow: hidden; margin-top: 13px; color: #292d28; font: 500 19px/1.2 "Lora", Georgia, serif; letter-spacing: -.02em; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }.artifact-summary { display: -webkit-box; overflow: hidden; margin-top: 9px; color: #686e64; font-size: 13px; line-height: 1.45; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }.artifact-card small { margin-top: auto; padding-top: 13px; color: #888d84; font-size: 11px; }.artifact-detail { position: sticky; top: 22px; min-height: 280px; border: 1px solid #d9d3c6; border-radius: 13px; background: #fffcf5; padding: 24px; box-shadow: 0 10px 25px rgba(66,58,43,.06); }.artifact-detail > .small-icon-button { float: right; margin: -7px -7px 0 12px; }.artifact-detail h2 { margin: 11px 0 0; color: #292d28; font: 500 26px/1.18 "Lora", Georgia, serif; letter-spacing: -.03em; }.artifact-source { margin: 11px 0 0; color: #7a8076; font-size: 12px; }.artifact-content { max-height: 42vh; overflow: auto; margin-top: 20px; color: #4f554c; font-size: 14px; line-height: 1.65; white-space: pre-wrap; }.artifact-empty { display: flex; min-height: 260px; flex-direction: column; align-items: flex-start; justify-content: center; border: 1px dashed #d4cfc3; border-radius: 13px; background: rgba(255,252,245,.54); padding: 34px; }.artifact-empty h2 { margin: 0; color: #3f453d; font: 500 25px/1.2 "Lora", Georgia, serif; }.artifact-empty p { max-width: 450px; margin: 10px 0 0; color: #737a70; line-height: 1.55; }.artifact-empty button { margin-top: 18px; min-height: 38px; border: 0; border-radius: 8px; background: #71836a; color: #fffcf5; padding: 0 13px; font-weight: 700; }.artifact-loading { display: grid; min-height: 300px; place-items: center; align-content: center; gap: 14px; color: #656b61; }
.learning-player { margin-top: 22px; }.player-progress { margin: 0; color: #687064; font-size: 13px; font-weight: 700; }.player-progress-track { height: 5px; overflow: hidden; margin-top: 10px; border-radius: 999px; background: #e7e2d7; }.player-progress-track span { display: block; height: 100%; border-radius: inherit; background: #71836a; transition: width 180ms ease; }.player-guidance { margin: 17px 0 0; color: #6c7269; font-size: 13px; line-height: 1.5; }.flashcard { min-height: 180px; margin-top: 13px; border: 1px solid #ded8ca; border-radius: 11px; background: #f8f5ed; padding: 20px; }.flashcard p { margin: 0; color: #798073; font-size: 11px; font-weight: 750; letter-spacing: .08em; text-transform: uppercase; }.flashcard strong { display: block; margin-top: 10px; color: #32372f; font: 500 20px/1.35 "Lora", Georgia, serif; }.flashcard hr { border: 0; border-top: 1px solid #ded8ca; margin: 20px 0; }.flashcard span { display: block; margin-top: 9px; color: #4e554b; font-size: 14px; line-height: 1.55; }.player-actions { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 15px; }.player-actions button { min-height: 34px; border: 1px solid #d7d1c4; border-radius: 8px; background: #fffcf5; color: #576352; padding: 0 10px; font-size: 12px; font-weight: 700; }.player-actions button:disabled { cursor: not-allowed; color: #9da198; }.player-actions .primary-player-action { border-color: #71836a; background: #71836a; color: #fffcf5; }.player-actions .text-player-action { border-color: transparent; background: transparent; color: #757c72; }.quiz-question { min-width: 0; margin: 20px 0 0; border: 0; padding: 0; }.quiz-question legend { padding: 0; color: #3f453d; font: 500 16px/1.4 "Lora", Georgia, serif; }.quiz-question label { display: flex; gap: 10px; align-items: flex-start; margin-top: 9px; border: 1px solid #dfd9cd; border-radius: 8px; background: #fffcf5; padding: 10px; color: #545b51; font-size: 13px; line-height: 1.4; }.quiz-question label.is-selected { border-color: #9dac96; background: rgba(113,131,106,.1); color: #394636; }.quiz-question input { margin: 2px 0 0; accent-color: #71836a; }.quiz-feedback { margin: 11px 0 0; color: #9c4d38; font-size: 13px; line-height: 1.5; }.quiz-feedback.is-correct { color: #55704f; }
.search-dialog-layer { position: fixed; z-index: 10; inset: 0; display: grid; place-items: start center; padding: min(13vh, 110px) 20px 20px; background: rgba(41,45,40,.32); }
.search-dialog { width: min(100%, 620px); overflow: hidden; border: 1px solid #e2ddd2; border-radius: 15px; background: #fffcf5; box-shadow: 0 24px 70px rgba(43,39,30,.25); }
.search-dialog-header { display: flex; align-items: center; justify-content: space-between; padding: 20px 22px 12px; }.search-dialog-header h2 { margin: 0; font: 500 23px/1.2 "Lora", Georgia, serif; letter-spacing: -.025em; }.search-dialog-header .small-icon-button { width: 32px; height: 32px; }
.search-input-wrap { display: flex; align-items: center; gap: 10px; margin: 0 22px; border: 1px solid #d9d3c6; border-radius: 10px; background: #f8f5ed; padding: 0 11px; color: #6d7769; }.search-input-wrap svg { width: 18px; flex: 0 0 auto; }.search-input-wrap input { width: 100%; min-width: 0; height: 48px; border: 0; outline: 0; background: transparent; color: #292d28; font: 15px "DM Sans", ui-sans-serif, system-ui, sans-serif; }.search-input-wrap kbd { flex: 0 0 auto; }
.search-results { min-height: 126px; max-height: min(48vh, 420px); overflow: auto; padding: 12px; }.search-results > p { margin: 12px 10px; color: #747a6e; font-size: 14px; }.search-results .search-error { color: #9c4d38; }.search-result { display: flex; width: 100%; gap: 12px; border: 0; border-radius: 9px; background: transparent; padding: 11px 10px; color: #3f453d; text-align: left; }.search-result:hover, .search-result:focus-visible { background: rgba(113,131,106,.12); outline: 0; }.search-result svg { flex: 0 0 auto; width: 17px; margin-top: 2px; color: #71836a; }.search-result span { min-width: 0; display: grid; gap: 4px; }.search-result strong { overflow: hidden; font-size: 14px; text-overflow: ellipsis; white-space: nowrap; }.search-result small { display: block; overflow: hidden; color: #747a6e; font-size: 13px; line-height: 1.35; text-overflow: ellipsis; white-space: nowrap; }
.coach-panel { position: relative; display: flex; flex-direction: column; align-items: center; min-height: 100svh; padding: 14px 10px; border-left: 1px solid #e2ddd2; background: #f8f5ed; z-index: 2; }.coach-trigger { display: grid; place-items: center; width: 42px; height: 42px; border: 1px solid #dcd6c8; border-radius: 50%; background: #fffcf5; color: #71836a; box-shadow: 0 3px 10px rgba(66,58,43,.08); }.coach-trigger:hover { background: #71836a; color: #fffcf5; }.coach-card { position: absolute; top: 66px; right: 10px; width: min(330px, calc(100vw - 92px)); border: 1px solid #e2ddd2; border-radius: 14px; background: #fffcf5; box-shadow: 0 18px 40px rgba(52,46,35,.14); padding: 25px; }.coach-card h2 { margin-top: 11px; font-size: 25px; }.coach-card p:not(.eyebrow) { color: #656b61; line-height: 1.55; }.coach-start { width: 100%; min-height: 40px; margin-top: 18px; border: 1px solid #d7d1c4; border-radius: 9px; background: #f1ede3; color: #767c73; cursor: not-allowed; }
.mobile-nav-toggle, .mobile-nav-close, .nav-backdrop { display: none; }
@keyframes spin { to { transform: rotate(360deg); } } @keyframes pulse { to { background-position: -200% 0; } }
@media (max-width: 1120px) { .app-shell { grid-template-columns: minmax(200px, var(--sidebar-width, 264px)) minmax(0, 1fr) 56px; }.workspace-nav { padding-inline: 12px; }.workspace-content { padding-inline: 32px; }.editor-surface { padding: 52px; } }
@media (max-width: 760px) { .app-shell { display: block; }.workspace-nav { position: fixed; inset: 0 auto 0 0; width: min(var(--sidebar-width, 280px), calc(100vw - 56px)); transform: translateX(-100%); transition: transform 180ms ease-out; box-shadow: 10px 0 28px rgba(52,46,35,.16); }.workspace-nav.is-open { transform: translateX(0); }.workspace-nav .brand > span:last-child, .workspace-nav .new-note-button > :last-child, .workspace-nav .search-button span, .workspace-nav kbd, .workspace-nav .nav-item span, .workspace-nav .folder-row span, .workspace-nav .note-row span, .workspace-nav .nav-section, .workspace-nav .local-label { display: revert; }.nav-header { padding: 20px 16px 14px; }.brand { justify-content: flex-start; margin: 0 8px 22px; }.new-note-button, .search-button, .nav-item { justify-content: flex-start; padding-inline: 12px; }.nav-footer { padding-inline: 10px; }.mobile-nav-close { display: grid; position: absolute; right: 14px; top: 20px; }.nav-backdrop { display: block; position: fixed; z-index: 2; inset: 0; border: 0; background: rgba(41,45,40,.28); }.workspace-main { min-height: 100svh; grid-template-rows: 58px minmax(0, 1fr); }.workspace-topbar { padding: 0 24px 0 62px; }.save-indicator { font-size: 0; }.workspace-content { padding: 22px 16px 32px; }.editor-surface, .welcome-surface, .placeholder-surface, .error-surface { min-height: calc(100svh - 112px); border-radius: 12px; padding: 34px 25px; }.artifact-library { padding-top: 8px; }.library-header { display: block; margin-bottom: 23px; }.library-refresh { margin-top: 17px; }.artifact-layout { grid-template-columns: 1fr; }.artifact-detail { position: static; }.artifact-grid { grid-template-columns: 1fr; }.artifact-card { min-height: 154px; }.note-body { font-size: 16px; }.coach-panel { position: fixed; right: 12px; bottom: 14px; min-height: 0; padding: 0; border: 0; background: transparent; }.coach-card { position: absolute; top: auto; bottom: 56px; right: 0; width: min(340px, calc(100vw - 32px)); }.mobile-nav-toggle { display: grid; position: fixed; z-index: 1; top: 13px; left: 14px; }.icon-button { width: 34px; height: 34px; place-items: center; border: 0; border-radius: 8px; background: transparent; color: #4a5048; }.icon-button svg { width: 21px; }.crumbs { max-width: calc(100vw - 160px); } }
@media (prefers-reduced-motion: reduce) { *, *::before, *::after { animation-duration: .01ms !important; transition-duration: .01ms !important; } }
.learning-view { width: min(1080px, 100%); margin: 0 auto; padding: 28px 0; }.learning-view > header { margin-bottom: 25px; }.learning-view h1 { margin: 8px 0; font: 500 clamp(30px, 4vw, 42px)/1.12 "Lora", Georgia, serif; letter-spacing: -.035em; }.learning-view > header p:last-child { margin: 0; color: #747a70; }.canvas-create { display: flex; gap: 9px; margin: 0 0 15px; }.canvas-create input { flex: 1; min-width: 0; height: 42px; border: 1px solid #ded9cd; border-radius: 9px; background: #fffcf5; padding: 0 12px; color: #292d28; }.canvas-create button { border: 0; border-radius: 9px; background: #71836a; color: #fffcf5; padding: 0 16px; font-weight: 650; }.canvas-note-picker { display: flex; flex-wrap: wrap; gap: 8px 16px; margin: 0 0 18px; border: 1px solid #e2ddd2; border-radius: 10px; background: #fffcf5; padding: 10px 14px 13px; }.canvas-note-picker legend { padding: 0 5px; color: #747a6e; font-size: 11px; text-transform: uppercase; letter-spacing: .07em; }.canvas-note-picker label { display: flex; align-items: center; gap: 6px; color: #555c52; font-size: 13px; }.canvas-tabs { display: flex; gap: 8px; overflow-x: auto; margin: 16px 0; }.canvas-tabs button { flex: 0 0 auto; border: 1px solid #ded9cd; border-radius: 999px; background: #fffcf5; padding: 8px 13px; color: #656b61; }.canvas-tabs button.is-active { border-color: #71836a; background: #71836a; color: #fffcf5; }.canvas-board { position: relative; min-height: 420px; overflow: auto; border: 1px solid #e2ddd2; border-radius: 13px; background-color: #fbf8f0; background-image: radial-gradient(#d8d3c8 1px, transparent 1px); background-size: 22px 22px; padding: 18px; }.canvas-board > p { margin: 0; color: #767c72; font-size: 12px; }.canvas-note { position: absolute; width: min(200px, 45vw); min-height: 110px; border: 1px solid #d7d2c6; border-radius: 10px; background: #fffcf5; padding: 14px; box-shadow: 0 5px 16px rgba(52,46,35,.08); cursor: grab; }.canvas-note:active { cursor: grabbing; }.canvas-note span { color: #71836a; font-size: 10px; text-transform: uppercase; letter-spacing: .07em; }.canvas-note strong { display: block; margin-top: 6px; font: 500 16px "Lora", Georgia, serif; }.canvas-note p { display: -webkit-box; overflow: hidden; margin: 6px 0 0; color: #747a70; font-size: 12px; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }.canvas-empty { position: absolute; inset: 0; display: grid; place-items: center; color: #82877e; }.canvas-save-state { position: absolute; right: 14px; bottom: 12px; border-radius: 20px; background: #fffcf5; padding: 6px 10px; color: #71836a; font-size: 12px; }.graph-list { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 12px; margin-top: 20px; }.graph-list article { border: 1px solid #e2ddd2; border-radius: 12px; background: #fffcf5; padding: 16px; }.graph-list strong { font: 500 17px "Lora", Georgia, serif; }.graph-list p { display: -webkit-box; overflow: hidden; margin: 8px 0 0; color: #747a70; font-size: 13px; -webkit-box-orient: vertical; -webkit-line-clamp: 3; }
.settings-view { max-width: 800px; }.settings-card { display: grid; grid-template-columns: repeat(2, minmax(0,1fr)); gap: 16px 22px; margin: 0 0 14px; border: 1px solid #e2ddd2; border-radius: 12px; background: #fffcf5; padding: 18px 20px; }.settings-card h2 { grid-column: 1 / -1; margin: 0; color: #454b43; font: 500 19px "Lora", Georgia, serif; }.settings-card label:not(.settings-check) { display: grid; gap: 6px; color: #62695f; font-size: 12px; font-weight: 650; }.settings-card input:not([type=checkbox]), .settings-card select { min-width: 0; height: 38px; border: 1px solid #ded9cd; border-radius: 8px; background: #fffefa; padding: 0 10px; color: #292d28; font: 13px "DM Sans", sans-serif; }.settings-check { display: flex; align-items: center; gap: 8px; color: #62695f; font-size: 13px; }.settings-footer { display: flex; align-items: center; justify-content: flex-end; gap: 14px; padding: 8px 0; color: #737a70; font-size: 12px; }.settings-footer button { min-height: 38px; border: 0; border-radius: 8px; background: #71836a; color: #fffcf5; padding: 0 14px; font-weight: 650; }.settings-footer button:disabled { opacity: .55; }
.coach-overlay { position: fixed; z-index: 10; inset: 0; display: flex; justify-content: flex-end; background: rgba(40,43,38,.24); }.coach-drawer { display: flex; width: min(var(--coach-width, 460px), 100vw); height: 100%; flex-direction: column; border-left: 1px solid #ded9cd; background: #f8f5ed; box-shadow: -18px 0 50px rgba(47,43,34,.12); }.coach-header { display: flex; align-items: center; gap: 10px; min-height: 66px; border-bottom: 1px solid #e2ddd2; padding: 0 16px; }.coach-heading-mark { display: grid; width: 34px; height: 34px; place-items: center; border-radius: 10px; background: #71836a; color: #fffcf5; }.coach-agent-heading { flex: 1; }.coach-agent-heading strong { display: block; margin-top: 3px; color: #3c433a; font: 500 17px "Lora", Georgia, serif; }.coach-agent-select { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin: 13px 16px 0; color: #686e64; font-size: 12px; }.coach-agent-select select { min-width: 0; max-width: 205px; height: 34px; border: 1px solid #ded9cd; border-radius: 8px; background: #fffcf5; padding: 0 8px; color: #4e554b; }.coach-messages { flex: 1; overflow: auto; padding: 18px 16px; }.coach-welcome { margin: 12px 0 0; border: 1px solid #e2ddd2; border-radius: 12px; background: #fffcf5; padding: 20px; }.coach-welcome h2 { margin: 10px 0 7px; color: #353b34; font: 500 24px/1.2 "Lora", Georgia, serif; }.coach-welcome > p:not(.eyebrow) { color: #73796f; font-size: 13px; line-height: 1.55; }.coach-prompt-list { display: grid; gap: 7px; margin-top: 16px; }.coach-prompt-list button { min-height: 36px; border: 1px solid #e1dcd0; border-radius: 8px; background: #faf7ef; padding: 0 10px; color: #596056; text-align: left; font-size: 12px; }.coach-message { max-width: 90%; margin: 0 0 12px; border: 1px solid #e2ddd2; border-radius: 11px; background: #fffcf5; padding: 11px 13px; }.coach-message.is-user { margin-left: auto; border-color: #c9d1c3; background: #edf0e8; }.coach-message > span { color: #7a8076; font-size: 10px; font-weight: 750; text-transform: uppercase; letter-spacing: .06em; }.coach-message p { margin: 5px 0 0; color: #3f453d; font-size: 13px; line-height: 1.55; white-space: pre-wrap; }.coach-error { border-radius: 8px; background: #fae8e2; padding: 10px; color: #873e2b; font-size: 12px; }.coach-loading { color: #777d73; font-size: 12px; }.coach-compose { display: flex; align-items: flex-end; gap: 8px; margin: 0 14px 16px; border: 1px solid #ded9cd; border-radius: 12px; background: #fffcf5; padding: 8px; }.coach-compose textarea { flex: 1; min-height: 40px; max-height: 130px; resize: vertical; border: 0; outline: 0; background: transparent; padding: 8px; color: #30362f; font: 13px/1.45 "DM Sans", sans-serif; }.coach-compose > button { display: grid; width: 36px; height: 36px; flex: 0 0 auto; place-items: center; border: 0; border-radius: 9px; background: #71836a; color: #fffdf7; }.coach-compose > button:disabled { opacity: .45; }.coach-spinner { width: 15px; height: 15px; border: 2px solid rgba(255,255,255,.5); border-top-color: white; border-radius: 50%; animation: spin .8s linear infinite; }
@media (max-width: 760px) { .settings-card { grid-template-columns: 1fr; }.settings-card h2 { grid-column: auto; } }
.home-view { width: min(980px,100%); margin: 0 auto; padding: 34px 0; }.home-hero { position: relative; overflow: hidden; border: 1px solid #ded9cd; border-radius: 16px; background: linear-gradient(132deg,#fdfbf4 0%,#f0eee4 100%); padding: clamp(26px,5vw,58px); }.home-hero h1 { max-width: 620px; margin: 12px 0; color: #292d28; font: 500 clamp(34px,5vw,54px)/1.06 "Lora",Georgia,serif; letter-spacing: -.045em; }.home-hero > p:not(.eyebrow) { max-width: 510px; color: #6d7469; font-size: 15px; line-height: 1.6; }.home-create { width: auto; min-width: 140px; margin-top: 18px; padding: 0 18px; }.home-stats { display: grid; grid-template-columns: repeat(3,1fr); gap: 12px; margin: 16px 0 38px; }.home-stats button { display: grid; grid-template-columns: 25px 1fr 18px; grid-template-rows: auto auto; align-items: center; gap: 4px 10px; min-height: 90px; border: 1px solid #e2ddd2; border-radius: 12px; background: #fffcf5; padding: 16px; color: #697164; text-align: left; }.home-stats button > svg:first-child { grid-row: span 2; color: #71836a; }.home-stats button > strong { color: #353b34; font: 500 25px "Lora",Georgia,serif; }.home-stats button > span { color: #747a70; font-size: 12px; }.home-stats button > svg:last-child { grid-column: 3; grid-row: 1 / span 2; width: 15px; }.home-section > header { display: flex; align-items: flex-end; justify-content: space-between; margin-bottom: 14px; }.home-section h2 { margin: 6px 0 0; color: #333932; font: 500 26px "Lora",Georgia,serif; }.home-section > header > button { display: flex; align-items: center; gap: 6px; border: 0; background: transparent; color: #65735e; font-size: 12px; }.home-section > header > button svg { width: 14px; }.home-note-grid { display: grid; grid-template-columns: repeat(2,minmax(0,1fr)); gap: 12px; }.home-note-grid > button { min-height: 150px; border: 1px solid #e2ddd2; border-radius: 12px; background: #fffcf5; padding: 16px; color: #434940; text-align: left; }.home-note-grid > button > span { display: flex; align-items: center; gap: 6px; color: #7b8177; font-size: 10px; text-transform: uppercase; letter-spacing: .07em; }.home-note-grid svg { width: 14px; }.home-note-grid strong { display: block; overflow: hidden; margin-top: 13px; color: #353b34; font: 500 19px "Lora",Georgia,serif; text-overflow: ellipsis; white-space: nowrap; }.home-note-grid p { display: -webkit-box; overflow: hidden; margin: 8px 0 0; color: #757b71; font-size: 13px; line-height: 1.5; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }.home-empty { display: flex; align-items: center; justify-content: space-between; border: 1px dashed #d8d3c8; border-radius: 12px; padding: 20px; color: #747a70; }.home-empty .new-note-button { width: auto; padding: 0 12px; }
@media (max-width: 760px) { .home-view { padding-top: 4px; }.home-stats { grid-template-columns: 1fr; gap: 8px; margin-bottom: 28px; }.home-stats button { min-height: 70px; }.home-note-grid { grid-template-columns: 1fr; }.home-section > header { align-items: flex-start; gap: 8px; }.home-section > header > button { max-width: 130px; text-align: right; }.home-empty { align-items: flex-start; flex-direction: column; gap: 10px; } }
.editor-tool-button { display: inline-flex; align-items: center; justify-content: center; gap: 5px; min-height: 34px; border: 1px solid #ded9cd; border-radius: 8px; background: #fffcf5; padding: 0 9px; color: #65715e; font-size: 12px; }.editor-tool-button svg { width: 15px; }.editor-tool-button:disabled { opacity: .55; }.note-preview-pane { min-height: 48vh; max-height: 67vh; overflow: auto; margin-top: 24px; border-top: 1px solid #ece7dc; padding: 20px 0; }.markdown-preview { color: #444a41; font: 15px/1.7 "DM Sans",sans-serif; overflow-wrap: anywhere; }.markdown-preview > :first-child { margin-top: 0; }.markdown-preview h1,.markdown-preview h2,.markdown-preview h3 { color: #30362f; font-family: "Lora",Georgia,serif; font-weight: 500; line-height: 1.2; }.markdown-preview h1 { font-size: 30px; }.markdown-preview h2 { font-size: 24px; }.markdown-preview h3 { font-size: 19px; }.markdown-preview li { margin: 5px 0; }.markdown-preview li input { margin-right: 7px; accent-color: #71836a; }.markdown-preview a { color: #587150; text-decoration-thickness: 1px; text-underline-offset: 3px; }.markdown-preview code { border-radius: 4px; background: #f0ede4; padding: 2px 5px; font: 13px ui-monospace,monospace; }.markdown-preview pre { overflow: auto; border: 1px solid #e3ded3; border-radius: 9px; background: #f5f2ea; padding: 14px; font: 13px/1.55 ui-monospace,monospace; }.markdown-preview pre code { background: transparent; padding: 0; }.markdown-preview blockquote { margin-left: 0; border-left: 3px solid #9aa790; padding-left: 13px; color: #72796e; }.markdown-image { margin: 14px 0; }.markdown-image img { display: block; max-width: min(100%,680px); max-height: 55vh; border: 1px solid #e2ddd2; border-radius: 10px; object-fit: contain; }.markdown-image figcaption { margin-top: 5px; color: #858a80; font-size: 11px; }.markdown-invalid-media { color: #a34734; font-size: 12px; }.markdown-note-reference { border-radius: 4px; background: rgba(113,131,106,.12); padding: 1px 4px; color: #587150; }
.graph-link-summary { display: inline-flex; align-items: baseline; gap: 7px; margin: 8px 0 0; border-radius: 999px; background: #e9ede4; padding: 6px 11px; color: #65715e; font-size: 12px; }.graph-link-summary strong { color: #475641; font: 600 15px "DM Sans",sans-serif; }.graph-node-title { border: 0; background: transparent; padding: 0; color: #3d443b; font: 500 18px "Lora",Georgia,serif; text-align: left; }.graph-node-title:hover { color: #587150; text-decoration: underline; text-underline-offset: 3px; }.graph-connections { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; margin-top: 12px; }.graph-connections > span { flex: 0 0 100%; color: #858a80; font-size: 10px; text-transform: uppercase; letter-spacing: .06em; }.graph-connections button { border: 1px solid #dfe4da; border-radius: 999px; background: #f3f5ef; padding: 5px 9px; color: #5b6e53; font-size: 11px; }
.coach-routing-note { margin: 11px 16px 0; color: #797f75; font-size: 11px; }
.folder-tree-node { min-width: 0; }.folder-disclosure { display: grid; opacity: .8 !important; }.folder-disclosure svg { width: 14px; height: 14px; transition: transform 120ms ease; }.folder-disclosure svg.is-expanded { transform: rotate(90deg); }.folder-disclosure-spacer { flex: 0 0 25px; }.folder-move-form { display: flex; gap: 5px; padding: 3px 5px 7px; }.folder-move-form select { min-width: 0; width: 145px; height: 29px; border: 1px solid #ded9cd; border-radius: 6px; background: #fffcf5; padding: 0 5px; color: #596056; font-size: 11px; }.folder-move-form button { border: 1px solid #d9d5cb; border-radius: 6px; background: #fffefa; color: #596056; font-size: 11px; }
.settings-stack { display: flex; flex-direction: column; align-items: flex-start; gap: 12px; }.settings-stack p { margin: 0; color: #62695f; font-size: 13px; line-height: 1.5; }.settings-stack button,.settings-inline-form button { border: 1px solid #d9d5cb; border-radius: 7px; background: #fffefa; padding: 8px 11px; color: #454b43; cursor: pointer; }.settings-row { display: flex; width: 100%; justify-content: space-between; align-items: center; gap: 12px; padding: 8px 0; border-bottom: 1px solid #eee9df; font-size: 13px; }.settings-inline-form { display: flex; width: 100%; gap: 8px; }.settings-inline-form input { flex: 1; min-width: 0; height: 36px; border: 1px solid #ded9cd; border-radius: 8px; padding: 0 10px; }.settings-danger { color: #9b493b !important; }.settings-file { display: grid; gap: 7px; color: #62695f; font-size: 12px; font-weight: 600; }.settings-file input { max-width: 100%; font-size: 12px; }.settings-stack small { color: #777d73; }.diagnostics-grid { display: grid; grid-template-columns: 130px minmax(0,1fr); gap: 8px 16px; margin: 0; font-size: 13px; }.diagnostics-grid dt { color: #737a70; }.diagnostics-grid dd { margin: 0; color: #454b43; }.settings-notice { color: #52694b; font-size: 13px; }
.settings-actions { display: flex; flex-wrap: wrap; gap: 9px; }
.editor-surface.is-wide { max-width: 1120px; }
html[data-density="compact"] .nav-item, html[data-density="compact"] .folder-row, html[data-density="compact"] .note-row { min-height: 29px; }
html[data-text-size="small"] .note-body-input, html[data-text-size="small"] .markdown-preview { font-size: 14px; }
html[data-text-size="large"] .note-body-input, html[data-text-size="large"] .markdown-preview { font-size: 18px; }
html[data-accent="blue"] .new-note-button { background: #58779b; } html[data-accent="blue"] .nav-item.is-active, html[data-accent="blue"] .note-row.is-selected { color: #41627f; background: rgba(88,119,155,.14); }
html[data-accent="lightOrange"] .new-note-button { background: #b7774b; } html[data-accent="lightOrange"] .nav-item.is-active, html[data-accent="lightOrange"] .note-row.is-selected { color: #9a603e; background: rgba(183,119,75,.14); }
html[data-accent="maroon"] .new-note-button { background: #80545b; } html[data-accent="maroon"] .nav-item.is-active, html[data-accent="maroon"] .note-row.is-selected { color: #74444d; background: rgba(128,84,91,.14); }
html[data-theme="dark"] body { background: #191c19; color: #ece9e1; }
html[data-theme="dark"] .app-shell { background: #191c19; color: #ece9e1; }
html[data-theme="dark"] .workspace-nav, html[data-theme="dark"] .coach-panel, html[data-theme="dark"] .workspace-topbar { background: #202520; border-color: #394139; }
html[data-theme="dark"] .editor-surface, html[data-theme="dark"] .welcome-surface, html[data-theme="dark"] .placeholder-surface, html[data-theme="dark"] .error-surface, html[data-theme="dark"] .settings-card, html[data-theme="dark"] .home-note-grid > button, html[data-theme="dark"] .artifact-card, html[data-theme="dark"] .artifact-detail, html[data-theme="dark"] .canvas-board, html[data-theme="dark"] .graph-node { background: #232923; border-color: #394139; color: #e9e6de; }
html[data-theme="dark"] .workspace-content, html[data-theme="dark"] .learning-view, html[data-theme="dark"] .home-view, html[data-theme="dark"] .artifact-library { color: #e9e6de; }
html[data-theme="dark"] h1, html[data-theme="dark"] h2, html[data-theme="dark"] h3, html[data-theme="dark"] .note-title-input, html[data-theme="dark"] .note-body-input, html[data-theme="dark"] .crumbs strong { color: #f0ede5; }
html[data-theme="dark"] input, html[data-theme="dark"] textarea, html[data-theme="dark"] select, html[data-theme="dark"] .folder-create-form select, html[data-theme="dark"] .folder-create-form input { background: #1c211c; color: #ece9e1; border-color: #465047; }
html[data-theme="dark"] .markdown-preview, html[data-theme="dark"] .home-hero > p:not(.eyebrow), html[data-theme="dark"] .settings-stack p { color: #c3c7be; }
@media (prefers-reduced-motion: reduce) { html[data-reduce-motion="true"] *, html[data-reduce-motion="true"] *::before, html[data-reduce-motion="true"] *::after { scroll-behavior: auto !important; animation-duration: .01ms !important; transition-duration: .01ms !important; } }
html[data-canvas-pattern="grid"] .canvas-board { background-color: var(--canvas-background); background-image: linear-gradient(to right, var(--canvas-pattern) 1px, transparent 1px), linear-gradient(to bottom, var(--canvas-pattern) 1px, transparent 1px); background-size: 22px 22px; }
html[data-canvas-pattern="none"] .canvas-board { background-color: var(--canvas-background); background-image: none; }
html[data-canvas-pattern="dots"] .canvas-board { background-color: var(--canvas-background); background-image: radial-gradient(var(--canvas-pattern) 1px, transparent 1px); background-size: 22px 22px; }
.artifact-grid.is-list { grid-template-columns: 1fr; }
.artifact-grid.is-list .artifact-card { min-height: 112px; }
.hardware-gpus { display: grid; width: 100%; gap: 9px; }.hardware-gpus h3 { margin: 3px 0; font: 500 17px "Lora",Georgia,serif; }.hardware-gpus article { border: 1px solid #e6e1d7; border-radius: 9px; background: rgba(255,255,255,.34); padding: 11px; }.hardware-gpus p,.hardware-gpus small { display: block; margin: 5px 0 0; color: #737a70; font-size: 12px; }
.canvas-editor { display: grid; gap: 12px; }.canvas-details { display: grid; grid-template-columns: minmax(180px, 1fr) minmax(220px, 1.5fr) auto; align-items: end; gap: 10px; border: 1px solid #e2ddd2; border-radius: 11px; background: #fffcf5; padding: 13px; }.canvas-details label { display: grid; gap: 5px; color: #737a70; font-size: 11px; font-weight: 650; }.canvas-details input,.canvas-details textarea { width: 100%; min-width: 0; border: 1px solid #ded9cd; border-radius: 7px; background: #fffefa; padding: 8px 9px; color: #353a34; font: 13px "DM Sans",sans-serif; }.canvas-details textarea { resize: vertical; }.canvas-details button { min-height: 36px; border: 0; border-radius: 8px; background: #71836a; padding: 0 12px; color: #fffcf5; font-weight: 650; }.canvas-linked-notes { margin: 0; }.canvas-linked-notes p { margin: 0; color: #747a70; font-size: 12px; }
html[data-theme="dark"] .canvas-details { background: #232923; border-color: #394139; } html[data-theme="dark"] .canvas-details input,html[data-theme="dark"] .canvas-details textarea { background: #1c211c; border-color: #465047; color: #ece9e1; }
@media (max-width: 780px) { .canvas-details { grid-template-columns: 1fr; align-items: stretch; }.canvas-details button { justify-self: start; min-height: 38px; }.canvas-note-picker { gap: 9px 12px; }.canvas-note { width: min(200px, 68vw); } }
.markdown-note-reference { display: inline; border: 0; border-radius: 4px; background: rgba(113,131,106,.12); padding: 1px 4px; color: #587150; font: inherit; text-decoration: underline; text-decoration-style: dotted; text-underline-offset: 3px; cursor: pointer; }.markdown-note-reference.is-unresolved { color: #777d73; cursor: help; }
.markdown-table-scroll { max-width: 100%; overflow-x: auto; margin: 16px 0; border: 1px solid #e2ddd2; border-radius: 8px; background: #fffcf5; }.markdown-preview table { width: 100%; border-collapse: collapse; font-size: .92em; }.markdown-preview th,.markdown-preview td { min-width: 88px; border-bottom: 1px solid #e8e3d8; padding: 8px 11px; }.markdown-preview th { background: #f0eee5; color: #3f493c; font-weight: 650; }.markdown-preview tr:last-child td { border-bottom: 0; }
html[data-theme="dark"] .markdown-table-scroll { background: #1c211c; border-color: #394139; } html[data-theme="dark"] .markdown-preview th,html[data-theme="dark"] .markdown-preview td { border-color: #394139; } html[data-theme="dark"] .markdown-preview th { background: #303830; color: #e9e6de; }
.markdown-math-inline { white-space: nowrap; }.markdown-math-block { display: block; max-width: 100%; overflow-x: auto; margin: 1.25rem 0; padding: .35rem 0; }.markdown-preview .katex { color: currentColor; font-size: 1em; }
.coach-message > .markdown-preview { margin-top: 5px; color: #3f453d; font-size: 13px; line-height: 1.55; }.coach-message > .markdown-preview p { margin: 5px 0; color: inherit; font-size: inherit; line-height: inherit; white-space: normal; }.coach-message > .markdown-preview h1,.coach-message > .markdown-preview h2,.coach-message > .markdown-preview h3 { margin: 9px 0 5px; font-size: 16px; }.coach-message > .markdown-preview ul,.coach-message > .markdown-preview ol { margin: 5px 0; padding-left: 20px; }.coach-message > .markdown-preview li { margin: 2px 0; } html[data-theme="dark"] .coach-message > .markdown-preview { color: #c3c7be; }

/* A roomier, quieter scale across the workspace */
.app-shell { grid-template-columns: var(--sidebar-width, 264px) minmax(0, 1fr) 84px; }
.workspace-nav { padding-inline: 18px; }
.brand { min-height: 58px; font-size: 16px; }
.brand-mark { width: 34px; height: 34px; font-size: 18px; }
.new-note-button, .search-button { min-height: 44px; border-radius: 11px; font-size: 14px; }
.nav-item { min-height: 42px; gap: 12px; font-size: 14px; }
.nav-item > svg, .note-row > svg, .folder-row > svg { width: 17px; height: 17px; }
.folder-row, .note-row { min-height: 36px; gap: 10px; font-size: 13px; }
.workspace-topbar { min-height: 64px; padding-inline: clamp(22px, 3.2vw, 48px); }
.workspace-content { padding: clamp(28px, 4vw, 52px); }
.settings-view { max-width: 1040px; }
.settings-view > header { margin-bottom: 30px; }
.settings-view h1, .learning-view h1 { font-size: clamp(36px, 4.4vw, 48px); }
.settings-view > header > p:last-child, .learning-view > header > p:last-child { font-size: 17px; line-height: 1.55; }
.settings-card { gap: 19px 26px; margin-bottom: 18px; border-radius: 15px; padding: 23px 25px; }
.settings-card h2 { font-size: 22px; }
.settings-card label:not(.settings-check) { gap: 8px; font-size: 14px; }
.settings-card input:not([type=checkbox]), .settings-card select { height: 46px; border-radius: 10px; padding-inline: 13px; font-size: 15px; }
.settings-check { gap: 10px; font-size: 14px; }
.settings-footer { gap: 18px; padding-block: 11px; font-size: 14px; }
.settings-footer button { min-height: 44px; border-radius: 10px; padding-inline: 18px; }
.learning-view { width: min(1120px, 100%); }
.canvas-library-view > header { margin-bottom: 30px; }
.canvas-create { display: grid; gap: 12px; margin: 0 0 42px; border: 1px solid #e2ddd2; border-radius: 16px; background: #fffcf5; padding: clamp(20px, 3vw, 30px); }
.canvas-create > label { color: #62695f; font-size: 14px; font-weight: 650; }
.canvas-create input { height: 48px; border-radius: 10px; padding-inline: 14px; font-size: 15px; }
.canvas-create .canvas-note-picker { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 7px 14px; margin: 8px 0 0; border-radius: 12px; padding: 14px 16px 17px; }
.canvas-create .canvas-note-picker legend { font-size: 12px; }
.canvas-create .canvas-note-picker legend span { color: #7b8177; text-transform: none; letter-spacing: 0; }
.canvas-create .canvas-note-picker label { min-height: 38px; gap: 10px; border-radius: 8px; padding: 4px 8px; font-size: 14px; }
.canvas-create .canvas-note-picker input { width: 17px; height: 17px; accent-color: #71836a; }
.canvas-create .canvas-note-picker .canvas-note-search { grid-column: 1 / -1; display: grid; gap: 7px; min-height: 0; margin-bottom: 5px; border-bottom: 1px solid #e8e3d8; border-radius: 0; padding: 4px 0 14px; color: #62695f; font-size: 13px; font-weight: 650; }
.canvas-create .canvas-note-picker .canvas-note-search input { width: 100%; height: 44px; border: 1px solid #ded9cd; border-radius: 9px; background: #fffefa; padding: 0 12px; color: #292d28; font: 14px "DM Sans", sans-serif; accent-color: auto; }
.canvas-create .canvas-note-picker .canvas-note-option { min-height: 38px; }
.canvas-create .canvas-note-picker .canvas-note-empty { grid-column: 1 / -1; margin: 4px 0; color: #747a70; font-size: 13px; }
.coach-trigger { display: grid; width: 68px; min-height: 64px; align-content: center; justify-items: center; gap: 4px; border-color: #dfe8d7; border-radius: 14px; background: #f2f7eb; color: #2c9a1a; box-shadow: 0 3px 10px rgba(66,58,43,.07); }
.coach-trigger > svg { width: 22px; height: 22px; color: #2c9a1a; }
.coach-trigger > span { color: #1f5f19; font-size: 9px; font-weight: 700; line-height: 1; white-space: nowrap; }
.coach-trigger:hover { background: #e6f0dc; color: #1f7d12; }
.coach-trigger:hover > svg { color: #1f7d12; }
.coach-heading-mark { background: #edf5e5; color: #2c9a1a; }
.coach-heading-mark svg { color: #2c9a1a; }
.canvas-create-actions { display: flex; align-items: center; justify-content: space-between; gap: 16px; }
.canvas-create-actions p { margin: 0; color: #777d73; font-size: 13px; }
.canvas-create button, .canvas-file-view .empty-state button { min-height: 46px; border: 0; border-radius: 11px; background: #71836a; padding: 0 20px; color: #fffcf5; font-size: 14px; font-weight: 650; transition: background-color .18s ease, transform .18s ease; }
.canvas-create button:hover:not(:disabled), .canvas-file-view .empty-state button:hover { background: #61745a; transform: translateY(-1px); }
.canvas-create button:disabled { cursor: not-allowed; opacity: .45; }
.canvas-library { margin-top: 36px; }
.canvas-library .section-heading { margin-bottom: 17px; }
.canvas-library .section-heading h2 { margin: 4px 0 0; color: #353b34; font: 500 26px "Lora", Georgia, serif; }
.canvas-library .section-heading > span { display: grid; min-width: 34px; height: 34px; place-items: center; border-radius: 999px; background: #e9eee5; color: #586751; font-size: 13px; }
.canvas-library-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(270px, 1fr)); gap: 14px; }
.canvas-file-card { display: flex; align-items: flex-start; gap: 14px; min-height: 104px; border: 1px solid #e2ddd2; border-radius: 14px; background: #fffcf5; padding: 18px; color: #343a33; text-align: left; transition: border-color .18s ease, box-shadow .18s ease, transform .18s ease; }
.canvas-file-card:hover { transform: translateY(-2px); border-color: #c3cdbb; box-shadow: 0 8px 22px rgba(52,46,35,.06); }
.canvas-file-icon { display: grid; width: 40px; height: 40px; flex: 0 0 auto; place-items: center; border-radius: 12px; background: #edf0e8; color: #62745b; font-size: 20px; }
.canvas-file-copy { display: grid; min-width: 0; gap: 6px; padding-top: 2px; }
.canvas-file-copy strong { overflow: hidden; font: 500 18px "Lora", Georgia, serif; text-overflow: ellipsis; white-space: nowrap; }
.canvas-file-copy > span { overflow: hidden; color: #737a70; font-size: 13px; text-overflow: ellipsis; white-space: nowrap; }
.canvas-file-arrow { margin-left: auto; color: #83897f; }
.canvas-file-heading { margin: 12px 0 24px; }
.canvas-file-heading > p:last-child { color: #747a70; font-size: 15px; }
.canvas-back { border: 0; background: transparent; padding: 8px 0; color: #64735e; font-size: 14px; }
.canvas-back:hover { color: #3f5539; }
.canvas-file-view .canvas-details { grid-template-columns: minmax(180px, 1fr) minmax(240px, 1.5fr) auto; gap: 13px; border-radius: 13px; padding: 17px; }
.canvas-file-view .canvas-details label { gap: 7px; font-size: 13px; }
.canvas-file-view .canvas-details input, .canvas-file-view .canvas-details textarea { border-radius: 9px; padding: 10px 12px; font-size: 14px; }
.canvas-file-view .canvas-details button { min-height: 42px; border-radius: 9px; padding-inline: 15px; }
.canvas-file-view .canvas-board { min-height: 520px; border-radius: 15px; }
.canvas-file-view .canvas-note { width: min(240px, 45vw); min-height: 130px; border-radius: 12px; padding: 17px; }
.canvas-file-view .canvas-note strong { font-size: 18px; }
.settings-layout { display: grid; grid-template-columns: 220px minmax(0, 1fr); align-items: start; gap: 28px; }
.settings-sidebar { position: sticky; top: 20px; display: grid; gap: 5px; border-right: 1px solid #e2ddd2; padding: 0 16px 0 0; }
.settings-sidebar button { min-height: 42px; border: 1px solid transparent; border-radius: 9px; background: transparent; padding: 0 12px; color: #62695f; font: 600 14px "DM Sans", sans-serif; text-align: left; transition: background-color .16s ease, color .16s ease; }
.settings-sidebar button:hover { background: rgba(41,45,40,.045); color: #353b34; }
.settings-sidebar button.is-active { border-color: #d8dfd2; background: #eaf0e5; color: #40533b; }
.settings-panel { min-width: 0; }
html[data-theme="dark"] .settings-sidebar { border-color: #394139; }
html[data-theme="dark"] .settings-sidebar button { color: #c3c7be; }
html[data-theme="dark"] .settings-sidebar button:hover { background: #2a302a; color: #f0ede5; }
html[data-theme="dark"] .settings-sidebar button.is-active { border-color: #465047; background: #303c30; color: #c7d2be; }
.home-view { width: min(1040px, 100%); padding-block: 40px; }
.home-hero { border-radius: 18px; background: #fffcf5; padding: clamp(30px, 5vw, 64px); }
.home-hero > p:not(.eyebrow) { font-size: 17px; }
.home-stats { gap: 15px; margin-block: 20px 44px; }
.home-stats button { min-height: 104px; border-radius: 14px; padding: 18px; }
.home-stats button > span { font-size: 13px; }
.home-section h2 { font-size: 28px; }
.home-note-grid { gap: 15px; }
.home-note-grid > button { min-height: 166px; border-radius: 14px; padding: 19px; }
.home-note-grid > button > span { font-size: 11px; }
.home-note-grid strong { font-size: 20px; }
.home-note-grid p { font-size: 14px; }
html[data-theme="dark"] .canvas-create, html[data-theme="dark"] .canvas-file-card { background: #232923; border-color: #394139; color: #e9e6de; }
html[data-theme="dark"] .canvas-library .section-heading > span, html[data-theme="dark"] .canvas-file-icon { background: #303830; color: #c7d2be; }
html[data-theme="dark"] .canvas-library .section-heading h2, html[data-theme="dark"] .canvas-file-copy strong { color: #f0ede5; }
html[data-theme="dark"] .canvas-create-actions p, html[data-theme="dark"] .canvas-file-copy > span { color: #c3c7be; }
html[data-theme="dark"] .canvas-create .canvas-note-picker .canvas-note-search { color: #c3c7be; border-color: #394139; }
html[data-theme="dark"] .canvas-create .canvas-note-picker .canvas-note-search input { background: #1c211c; border-color: #465047; color: #ece9e1; }
html[data-theme="dark"] .canvas-create .canvas-note-picker .canvas-note-empty { color: #c3c7be; }
html[data-theme="dark"] .canvas-create { border-color: #465047; background: #232923; box-shadow: 0 14px 36px rgba(0,0,0,.2); }
html[data-theme="dark"] .canvas-create > label { color: #d4d8cf; }
html[data-theme="dark"] .canvas-create > input { border-color: #596557; background: #1c211c; color: #f0ede5; }
html[data-theme="dark"] .canvas-create > input::placeholder,
html[data-theme="dark"] .canvas-create .canvas-note-search input::placeholder { color: #aab2a7; }
html[data-theme="dark"] .canvas-create .canvas-note-picker { border-color: #4a554a; background: #2b322b; color: #e1e5dc; box-shadow: inset 0 1px rgba(255,255,255,.025); }
html[data-theme="dark"] .canvas-create .canvas-note-picker legend { color: #e1e5dc; }
html[data-theme="dark"] .canvas-create .canvas-note-picker legend span { color: #b9c3b3; }
html[data-theme="dark"] .canvas-create .canvas-note-picker .canvas-note-search { color: #e1e5dc; border-color: #4a554a; }
html[data-theme="dark"] .canvas-create .canvas-note-picker .canvas-note-search input { border-color: #586556; background: #1d241e; color: #f0ede5; }
html[data-theme="dark"] .canvas-create .canvas-note-picker .canvas-note-option { border: 1px solid transparent; color: #e1e5dc; }
html[data-theme="dark"] .canvas-create .canvas-note-picker .canvas-note-option:hover { border-color: #53634e; background: #343d34; }
html[data-theme="dark"] .canvas-create .canvas-note-picker input[type="checkbox"] { accent-color: #9bb48f; }
html[data-theme="dark"] .canvas-create-actions p { color: #c3cabe; }
html[data-theme="dark"] .canvas-create-actions button { background: #76906d; color: #101510; }
html[data-theme="dark"] .canvas-create-actions button:hover:not(:disabled) { background: #8da783; }
html[data-theme="dark"] .canvas-create-actions button:disabled { background: #465246; color: #c0c8bc; opacity: 1; }
html[data-theme="dark"] .canvas-library-view > header .eyebrow { color: #aeb8a8; }
html[data-theme="dark"] .canvas-library-view > header p:last-child { color: #c3cabe; }
html[data-theme="dark"] .canvas-library .empty-state { border-color: #465047; background: #232923; color: #d4d8cf; }

/* Canvas files are an open board; the title stays in the app's single top bar. */
.workspace-main.is-canvas-file-main { height: 100svh; min-height: 0; grid-template-rows: 64px minmax(0, 1fr); overflow: hidden; }
.workspace-main.is-canvas-file-main .workspace-topbar { justify-content: flex-start; }
.canvas-file-crumb { min-width: 0; color: #343a33; font-size: 15px; }
.canvas-file-crumb strong { font-family: "Lora", Georgia, serif; font-size: 19px; font-weight: 500; letter-spacing: -.025em; }
.workspace-content.is-canvas-file-content { min-width: 0; min-height: 0; overflow: hidden; padding: 0; }
.canvas-file-view { width: 100%; height: 100%; min-height: 0; }
.canvas-loading { display: grid; height: 100%; place-content: center; gap: 14px; color: #747a70; }
.canvas-loading button { min-height: 38px; border: 1px solid #d9d3c6; border-radius: 9px; background: #fffcf5; color: #53634e; padding: 0 13px; }
.canvas-board-shell { width: 100%; height: 100%; min-height: 0; }
.canvas-file-view .canvas-board { position: relative; width: 100%; height: 100%; min-height: 0; overflow: hidden; border: 0; border-radius: 0; background-color: var(--canvas-background, #f4f1e8); background-image: radial-gradient(var(--canvas-pattern, #c4c7bc) 1px, transparent 1px); background-position: 10px 10px; background-size: 24px 24px; padding: 0; touch-action: none; cursor: default; }
.canvas-file-view .canvas-board.is-pan-mode { cursor: grab; }.canvas-file-view .canvas-board.is-panning { cursor: grabbing; }
.canvas-world { position: absolute; inset: auto; top: 0; left: 0; transform-origin: 0 0; }
.canvas-edges { position: absolute; inset: 0; overflow: visible; pointer-events: none; }
.canvas-edge-path { fill: none; stroke: color-mix(in srgb, #737c70 78%, transparent); stroke-width: 2.2px; }
.canvas-arrow-head { fill: #737c70; stroke: none; }
.canvas-file-view .canvas-note { position: absolute; display: flex; width: 320px; min-height: 156px; flex-direction: column; align-items: flex-start; border: 1px solid color-mix(in srgb, #787e73 35%, transparent); border-radius: 13px; background: color-mix(in srgb, var(--canvas-background, #f4f1e8) 82%, #fffdf7); padding: 19px 22px 18px; box-shadow: 0 10px 26px rgba(38, 41, 36, .12); cursor: grab; user-select: none; touch-action: none; transition: box-shadow .16s ease, border-color .16s ease; }
.canvas-file-view .canvas-note:hover { border-color: color-mix(in srgb, #71836a 56%, transparent); box-shadow: 0 14px 32px rgba(38, 41, 36, .16); }
.canvas-file-view .canvas-note:active { cursor: grabbing; }
.canvas-note-label { margin-bottom: 7px; color: #71836a; font-size: 10px; font-weight: 750; letter-spacing: .1em; text-transform: uppercase; }
.canvas-file-view .canvas-note .canvas-note-title { max-width: 100%; border: 0; background: transparent; padding: 0; color: #343a33; font: 500 20px/1.25 "Lora", Georgia, serif; text-align: left; cursor: pointer; }
.canvas-file-view .canvas-note .canvas-note-title:hover { color: #536b4d; }
.canvas-file-view .canvas-note p { display: -webkit-box; overflow: hidden; margin: 8px 0 0; color: #72786f; font-size: 13px; line-height: 1.5; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }
.canvas-note-remove { position: absolute; top: 9px; right: 9px; display: grid; width: 27px; height: 27px; place-items: center; border: 0; border-radius: 7px; background: transparent; color: #81877e; opacity: 0; cursor: pointer; }
.canvas-note:hover .canvas-note-remove, .canvas-note-remove:focus-visible { opacity: 1; }
.canvas-note-remove:hover { background: rgba(50, 56, 48, .08); color: #454b43; }
.canvas-note-remove svg { width: 15px; height: 15px; }
.canvas-node-port { position: absolute; top: 64px; display: grid; width: 17px; height: 17px; border: 2px solid #f6f3eb; border-radius: 50%; background: #899383; box-shadow: 0 0 0 1px #899383; opacity: 0; cursor: crosshair; transition: opacity .14s ease, transform .14s ease, background .14s ease; }
.canvas-node-port.is-source { right: -9px; }
.canvas-node-port.is-target { left: -9px; }
.canvas-note:hover .canvas-node-port, .canvas-node-port:focus-visible, .canvas-note.is-connect-source .canvas-node-port { opacity: 1; }
.canvas-node-port:hover, .canvas-node-port.is-active { transform: scale(1.2); background: #536b4d; box-shadow: 0 0 0 2px #e5eadf, 0 0 0 4px #71836a; }
.canvas-note.is-selected:not(.is-connect-source) { border-color: color-mix(in srgb, #71836a 60%, transparent); box-shadow: 0 0 0 2px rgba(113, 131, 106, .12), 0 12px 28px rgba(38, 41, 36, .13); }.canvas-note.is-connect-source { border-color: #71836a; box-shadow: 0 0 0 3px rgba(113, 131, 106, .16), 0 14px 32px rgba(38, 41, 36, .14); }
.canvas-empty-state { position: absolute; inset: 0; display: grid; align-content: center; justify-items: center; gap: 9px; color: #767d72; pointer-events: none; }
.canvas-empty-orb { display: grid; width: 48px; height: 48px; margin-bottom: 6px; place-items: center; border: 1px solid color-mix(in srgb, #71836a 30%, transparent); border-radius: 16px; background: color-mix(in srgb, var(--canvas-background, #f4f1e8) 70%, #fffdf7); color: #71836a; }
.canvas-empty-orb svg { width: 21px; }
.canvas-empty-state strong { color: #444b42; font: 500 21px "Lora", Georgia, serif; }
.canvas-empty-state > span:last-child { font-size: 13px; }
.canvas-tool-palette { position: absolute; z-index: 5; top: 18px; right: 18px; display: grid; gap: 5px; justify-items: center; min-width: 54px; border: 1px solid rgba(255,255,255,.13); border-radius: 13px; background: rgba(38, 42, 39, .94); padding: 7px; box-shadow: 0 10px 28px rgba(18, 20, 18, .2); color: #f1f0eb; backdrop-filter: blur(14px); }
.canvas-tool-palette > button { display: grid; width: 38px; height: 38px; place-items: center; border: 1px solid transparent; border-radius: 8px; background: transparent; color: #d3d5cf; cursor: pointer; }
.canvas-tool-palette > button:hover, .canvas-tool-palette > button.is-active { border-color: rgba(198, 211, 190, .24); background: rgba(191, 208, 182, .16); color: #e0ead7; }
.canvas-tool-palette > button svg { width: 19px; height: 19px; }
.canvas-palette-grip { display: grid; width: 38px; height: 19px; grid-template-columns: repeat(3, 3px); grid-template-rows: repeat(2, 3px); align-content: center; justify-content: center; gap: 3px; border-radius: 5px; cursor: move; touch-action: none; }
.canvas-palette-grip:hover { background: rgba(255,255,255,.1); }
.canvas-palette-grip span { width: 3px; height: 3px; border-radius: 50%; background: #858b83; }
.canvas-palette-divider { width: 27px; height: 1px; margin: 2px 0; background: rgba(255,255,255,.14); }
.canvas-zoom-readout { min-width: 40px; color: #bfc3bb; font-size: 10px; font-variant-numeric: tabular-nums; text-align: center; }
.canvas-tool-palette .canvas-pan-hint { color: #aeb5aa; }
.canvas-add-popover { position: absolute; z-index: 4; top: 18px; right: 84px; width: min(340px, calc(100vw - 110px)); overflow: hidden; border: 1px solid rgba(77, 82, 74, .17); border-radius: 13px; background: color-mix(in srgb, var(--canvas-background, #f4f1e8) 74%, #fffdf7); box-shadow: 0 16px 40px rgba(35, 39, 34, .17); }
.canvas-add-popover > header { display: flex; align-items: flex-start; justify-content: space-between; gap: 15px; padding: 16px 16px 12px; }
.canvas-add-popover > header div { display: grid; gap: 4px; }
.canvas-add-popover > header strong { color: #383f36; font: 500 18px "Lora", Georgia, serif; }
.canvas-add-popover > header span { color: #777e73; font-size: 12px; }
.canvas-add-popover > header button { display: grid; width: 28px; height: 28px; place-items: center; border: 0; border-radius: 7px; background: transparent; color: #6f776d; cursor: pointer; }
.canvas-add-popover > header button:hover { background: rgba(45, 50, 43, .07); }
.canvas-add-popover > header button svg { width: 17px; }
.canvas-create-note { display: block; width: calc(100% - 26px); min-height: 38px; margin: 0 13px 10px; border: 0; border-radius: 8px; background: #71836a; color: #fffcf5; font-size: 13px; font-weight: 650; cursor: pointer; }.canvas-create-note:hover { background: #5f7258; }.canvas-add-search { display: flex; align-items: center; gap: 8px; margin: 0 13px 9px; border: 1px solid #ddd9ce; border-radius: 8px; background: rgba(255,255,255,.48); padding: 0 10px; color: #71836a; }
.canvas-add-search svg { width: 16px; flex: 0 0 auto; }
.canvas-add-search input { width: 100%; height: 39px; border: 0; outline: 0; background: transparent; color: #353b34; font: 13px "DM Sans", sans-serif; }
.canvas-add-results { max-height: min(360px, 52vh); overflow: auto; padding: 0 7px 7px; }
.canvas-add-results > button { display: flex; width: 100%; align-items: center; justify-content: space-between; gap: 12px; border: 0; border-radius: 8px; background: transparent; padding: 9px; color: #42483f; text-align: left; cursor: pointer; }
.canvas-add-results > button:hover { background: rgba(113, 131, 106, .12); }
.canvas-add-results > button > span { display: grid; min-width: 0; gap: 4px; }
.canvas-add-results strong { overflow: hidden; font-size: 13px; font-weight: 650; text-overflow: ellipsis; white-space: nowrap; }
.canvas-add-results small { overflow: hidden; color: #777e73; font-size: 11px; text-overflow: ellipsis; white-space: nowrap; }
.canvas-add-results > button svg { width: 16px; flex: 0 0 auto; color: #71836a; }
.canvas-add-results > p { margin: 6px 9px 12px; color: #777e73; font-size: 12px; }
.canvas-board-hint { position: absolute; z-index: 2; right: 20px; bottom: 17px; left: 20px; display: flex; justify-content: space-between; gap: 12px; color: #777d73; font-size: 11px; pointer-events: none; }
.canvas-board-hint [role="alert"] { max-width: min(48%, 560px); color: #a45743; text-align: right; overflow-wrap: anywhere; }
html[data-theme="dark"] .canvas-file-view .canvas-note { background: color-mix(in srgb, var(--canvas-background, #191c19) 83%, #333a32); color: #e9e6de; }
html[data-theme="dark"] .canvas-file-view .canvas-note .canvas-note-title, html[data-theme="dark"] .canvas-empty-state strong, html[data-theme="dark"] .canvas-add-popover > header strong { color: #e9e6de; }
html[data-theme="dark"] .canvas-file-view .canvas-note p, html[data-theme="dark"] .canvas-empty-state > span:last-child, html[data-theme="dark"] .canvas-add-popover > header span, html[data-theme="dark"] .canvas-add-results small { color: #b9beb4; }
@media (max-width: 760px) {
  .workspace-main.is-canvas-file-main { grid-template-rows: 58px minmax(0, 1fr); }
  .canvas-file-view .canvas-board { background-size: 22px 22px; }
  .canvas-file-view .canvas-note { width: 270px; min-height: 145px; padding: 16px 18px; }
  .canvas-file-view .canvas-note .canvas-note-title { font-size: 18px; }
  .canvas-tool-palette { top: 12px; right: 12px; }
  .canvas-add-popover { top: 12px; right: 76px; width: min(310px, calc(100vw - 92px)); }
  .canvas-board-hint { right: 12px; bottom: 12px; left: 12px; font-size: 10px; }
}
@media (max-width: 900px) {
  .app-shell { grid-template-columns: var(--sidebar-width, 248px) minmax(0, 1fr) 76px; }
  .workspace-main { max-width: none; }
  .workspace-content { padding: 28px; }
  .settings-view { max-width: 100%; }
  .workspace-nav .brand > span:last-child, .workspace-nav .new-note-button > :last-child, .workspace-nav .search-button span, .workspace-nav kbd, .workspace-nav .nav-item span, .workspace-nav .folder-row span, .workspace-nav .note-row span, .workspace-nav .nav-section, .workspace-nav .local-label { display: revert; }
  .nav-header { padding-inline: 16px; }
  .brand { justify-content: flex-start; margin: 0 8px 26px; }
  .new-note-button, .search-button, .nav-item { justify-content: flex-start; padding-inline: 12px; }
  .settings-layout { grid-template-columns: 190px minmax(0, 1fr); gap: 20px; }
}
@media (max-width: 760px) {
  .app-shell { grid-template-columns: minmax(0, 1fr); }
  .workspace-main { width: 100%; max-width: none; }
  .workspace-content { padding: 20px 16px 32px; }
  .workspace-topbar { min-height: 58px; padding-inline: 64px 16px; }
  .settings-card { padding: 19px; }
  .canvas-create-actions { align-items: stretch; flex-direction: column; }
  .canvas-create-actions button { align-self: flex-start; }
  .canvas-library-grid { grid-template-columns: 1fr; }
  .canvas-file-view .canvas-details { grid-template-columns: 1fr; }
  .canvas-file-view .canvas-details button { justify-self: start; }
  .home-stats { grid-template-columns: 1fr; }
  .home-note-grid { grid-template-columns: 1fr; }
  .settings-layout { grid-template-columns: 1fr; gap: 20px; }
  .settings-sidebar { position: static; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 6px; border-right: 0; border-bottom: 1px solid #e2ddd2; padding: 0 0 16px; }
  .settings-sidebar button { min-height: 40px; padding-inline: 9px; font-size: 13px; }
}
.artifact-modal-backdrop { position: fixed; z-index: 30; inset: 0; display: grid; place-items: center; overflow-y: auto; padding: 28px; background: rgba(35, 39, 34, .28); backdrop-filter: blur(8px) saturate(.82); -webkit-backdrop-filter: blur(8px) saturate(.82); animation: artifact-modal-in 180ms ease-out; }
.artifact-detail.is-floating { position: relative; top: auto; width: min(760px, calc(100vw - 56px)); max-height: min(88svh, 940px); min-height: 320px; overflow-y: auto; border: 1px solid rgba(255,255,255,.72); border-radius: 20px; background: #fffcf5; padding: clamp(24px, 4vw, 38px); box-shadow: 0 32px 90px rgba(22, 25, 22, .3), 0 8px 26px rgba(22, 25, 22, .12); animation: artifact-modal-card-in 220ms cubic-bezier(.2,.8,.2,1); }
.artifact-detail.is-floating > .small-icon-button { position: sticky; z-index: 1; top: 0; float: right; margin: -10px -10px 0 12px; border: 1px solid #e5e0d6; border-radius: 50%; background: rgba(255,252,245,.94); }
html[data-theme="dark"] .artifact-detail.is-floating { border-color: #4c574d; background: #232923; box-shadow: 0 32px 90px rgba(0,0,0,.55), 0 8px 26px rgba(0,0,0,.24); }
html[data-theme="dark"] .artifact-modal-backdrop { background: rgba(5, 8, 6, .48); }
@keyframes artifact-modal-in { from { opacity: 0; } to { opacity: 1; } }
@keyframes artifact-modal-card-in { from { opacity: 0; transform: translateY(12px) scale(.985); } to { opacity: 1; transform: translateY(0) scale(1); } }
@media (max-width: 760px) { .artifact-modal-backdrop { padding: 12px; }.artifact-detail.is-floating { width: 100%; max-height: 92svh; min-height: 0; border-radius: 16px; padding: 22px 18px; } }
@media (prefers-reduced-motion: reduce) { .artifact-modal-backdrop,.artifact-detail.is-floating { animation: none; } }
.editor-surface { position: relative; }
.note-saved-toast { position: absolute; z-index: 2; top: 17px; right: 18px; display: inline-flex; align-items: center; gap: 8px; min-height: 34px; border: 1px solid #cedec8; border-radius: 999px; background: #edf4e9; padding: 0 12px; color: #4e7049; box-shadow: 0 7px 18px rgba(57, 82, 51, .12); font-size: 12px; font-weight: 700; letter-spacing: .01em; animation: note-saved-toast-in 180ms ease-out; }
.note-saved-toast > span { width: 8px; height: 8px; border-radius: 50%; background: #69a65c; box-shadow: 0 0 0 3px rgba(105,166,92,.15); }
html[data-theme="dark"] .note-saved-toast { border-color: #476345; background: #263b27; color: #b8d9ad; }
html[data-theme="dark"] .note-saved-toast > span { background: #8bc77c; box-shadow: 0 0 0 3px rgba(139,199,124,.17); }
@keyframes note-saved-toast-in { from { opacity: 0; transform: translateY(-7px); } to { opacity: 1; transform: translateY(0); } }
@media (prefers-reduced-motion: reduce) { .note-saved-toast { animation: none; } }
.settings-storage .storage-summary { color: #4e6248; font-size: 14px; font-weight: 700; }
.settings-storage .storage-export-button { display: inline-flex; align-items: center; justify-content: center; gap: 9px; min-height: 44px; border: 1px solid #637a5a; border-radius: 9px; background: #71836a; padding: 0 15px; color: #fffdf7; font-size: 14px; font-weight: 700; box-shadow: 0 3px 9px rgba(56,75,49,.14); transition: background-color 140ms ease, box-shadow 140ms ease, transform 140ms ease; }
.settings-storage .storage-export-button:hover { background: #5f7358; box-shadow: 0 6px 14px rgba(56,75,49,.18); transform: translateY(-1px); }
.settings-storage .storage-export-button:focus-visible,.settings-storage .settings-file-button:focus-visible { outline: 3px solid rgba(113,131,106,.35); outline-offset: 2px; }
.settings-storage .storage-export-button svg,.settings-storage .settings-file-button svg { width: 16px; height: 16px; }
.settings-storage .settings-file { position: relative; width: 100%; max-width: 560px; gap: 9px; color: #62695f; font-size: 13px; font-weight: 700; }
.settings-storage input.settings-file-input { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0,0,0,0); clip-path: inset(50%); white-space: nowrap; }
.settings-storage .settings-file-control { display: flex; min-width: 0; align-items: center; gap: 12px; }
.settings-storage .settings-file-button { display: inline-flex; min-height: 40px; flex: 0 0 auto; align-items: center; justify-content: center; gap: 8px; border: 1px solid #cfd8c9; border-radius: 9px; background: #edf1e9; padding: 0 13px; color: #50654a; font-size: 13px; font-weight: 700; transition: background-color 140ms ease, border-color 140ms ease; }
.settings-storage .settings-file:hover .settings-file-button { border-color: #aab9a3; background: #e4ebdf; }
.settings-storage .settings-file-name { min-width: 0; overflow: hidden; color: #737a70; font-size: 13px; font-weight: 450; text-overflow: ellipsis; white-space: nowrap; }
.settings-storage .settings-file-input:focus-visible ~ .settings-file-control .settings-file-button { outline: 3px solid rgba(113,131,106,.35); outline-offset: 2px; }
html[data-theme="dark"] .settings-storage .storage-summary { color: #c2d2bb; }
html[data-theme="dark"] .settings-storage .settings-file-button { border-color: #4b5b49; background: #303b2e; color: #d4e2ce; }
html[data-theme="dark"] .settings-storage .settings-file:hover .settings-file-button { border-color: #6a7f65; background: #394936; }
html[data-theme="dark"] .settings-storage .settings-file-name { color: #aeb6aa; }
html[data-theme="dark"] .coach-trigger { border-color: #465047; background: #2a312a; color: #c8d4c1; box-shadow: 0 3px 10px rgba(0,0,0,.28); }
html[data-theme="dark"] .coach-trigger:hover { border-color: #71836a; background: #465642; color: #f0f2ec; }

/* Dark mode contrast for navigation, secondary copy, and interactive states. */
html[data-theme="dark"] .workspace-nav { color: #e9eee5; }
html[data-theme="dark"] .brand { color: #f0ede5; }
html[data-theme="dark"] .new-note-button { background: #8da783; color: #111710; }
html[data-theme="dark"] .new-note-button:hover { background: #a1b99a; }
html[data-theme="dark"] .search-button { background: #2a302a; color: #d5dbd1; }
html[data-theme="dark"] .search-button:hover { background: #353d35; color: #f0ede5; }
html[data-theme="dark"] .nav-item,
html[data-theme="dark"] .folder-row,
html[data-theme="dark"] .note-row { color: #c7cec3; }
html[data-theme="dark"] .nav-item:hover,
html[data-theme="dark"] .folder-row:hover,
html[data-theme="dark"] .note-row:hover,
html[data-theme="dark"] .folder-row-wrap:hover { background: #303830; color: #f0ede5; }
html[data-theme="dark"] .nav-item.is-active,
html[data-theme="dark"] .note-row.is-selected,
html[data-theme="dark"] .folder-row-wrap.is-selected { background: #354334; color: #dce9d5; }
html[data-theme="dark"] .folder-row-wrap.is-selected .folder-row { color: #dce9d5; }
html[data-theme="dark"] .workspace-nav :is(button, a):focus-visible { outline: 2px solid #a9c79d; outline-offset: 2px; }
html[data-theme="dark"] .nav-section h2,
html[data-theme="dark"] .local-label,
html[data-theme="dark"] .nav-empty { color: #b7c0b4; }
html[data-theme="dark"] .nav-footer { border-color: #394139; }
html[data-theme="dark"] .learning-view > header > p:last-child,
html[data-theme="dark"] .settings-view > header > p:last-child,
html[data-theme="dark"] .canvas-file-heading > p:last-child,
html[data-theme="dark"] .settings-card label:not(.settings-check),
html[data-theme="dark"] .settings-check,
html[data-theme="dark"] .eyebrow,
html[data-theme="dark"] .editor-kicker { color: #bec7bb; }
html[data-theme="dark"] .settings-card h2,
html[data-theme="dark"] .canvas-file-heading h1 { color: #f0ede5; }
html[data-theme="dark"] .settings-card input:not([type="checkbox"]),
html[data-theme="dark"] .settings-card select { border-color: #566353; background: #1d241e; color: #f0ede5; }
html[data-theme="dark"] .settings-sidebar button { color: #c7cec3; }
html[data-theme="dark"] .settings-sidebar button:hover { border-color: #465047; background: #303830; color: #f0ede5; }
html[data-theme="dark"] .settings-sidebar button.is-active { border-color: #596d52; background: #354334; color: #e0ecd9; }
html[data-theme="dark"] .canvas-create .canvas-note-picker .canvas-note-option { color: #e1e5dc; }
html[data-theme="dark"] .artifact-summary,
html[data-theme="dark"] .canvas-file-copy > span,
html[data-theme="dark"] .artifact-source,
html[data-theme="dark"] .artifact-card small { color: #c0c8bc; }
html[data-theme="dark"] .home-hero,
html[data-theme="dark"] .home-stats button { border-color: #465047; background: #232923; color: #e9eee5; box-shadow: 0 12px 30px rgba(0,0,0,.18); }
html[data-theme="dark"] .home-hero h1,
html[data-theme="dark"] .home-section h2,
html[data-theme="dark"] .home-note-grid strong,
html[data-theme="dark"] .home-stats button > strong { color: #f0ede5; }
html[data-theme="dark"] .home-hero > p:not(.eyebrow),
html[data-theme="dark"] .home-stats button > span,
html[data-theme="dark"] .home-note-grid > button > span,
html[data-theme="dark"] .home-note-grid p { color: #c3cabe; }
html[data-theme="dark"] .home-stats button > svg:first-child { color: #a9c79d; }
html[data-theme="dark"] .home-stats button > svg:last-child,
html[data-theme="dark"] .home-section > header > button { color: #c1d1b8; }
html[data-theme="dark"] .home-empty { border-color: #596557; background: #232923; color: #c3cabe; }
html[data-theme="dark"] .library-header p:not(.eyebrow) { color: #c3cabe; }
html[data-theme="dark"] .library-refresh { border-color: #53634e; background: #2b332b; color: #dce9d5; }
html[data-theme="dark"] .library-refresh:hover:not(:disabled) { border-color: #829779; background: #354334; color: #f0ede5; }
html[data-theme="dark"] .artifact-search { border-color: #53604f; background: #232923; color: #a9c79d; box-shadow: 0 6px 20px rgba(0,0,0,.16); }
html[data-theme="dark"] .artifact-search input { background: transparent; color: #f0ede5; }
html[data-theme="dark"] .artifact-search input::placeholder { color: #b0b9ad; }
html[data-theme="dark"] .artifact-filters button { border-color: #4b5649; background: #2b322b; color: #d0d7ca; }
html[data-theme="dark"] .artifact-filters button:hover { border-color: #829779; background: #354334; color: #f0ede5; }
html[data-theme="dark"] .artifact-filters button.is-active { border-color: #8da783; background: #71836a; color: #111710; }
html[data-theme="dark"] .artifact-filters span { background: rgba(220,233,213,.14); color: #e5ecdf; }
html[data-theme="dark"] .artifact-filters button.is-active span { background: rgba(17,23,16,.18); color: #111710; }
html[data-theme="dark"] .artifact-card strong { color: #f0ede5; }
html[data-theme="dark"] .artifact-card:hover,
html[data-theme="dark"] .artifact-card:focus-visible,
html[data-theme="dark"] .artifact-card.is-selected { border-color: #8da783; background: #2a322a; box-shadow: 0 12px 28px rgba(0,0,0,.3); }
html[data-theme="dark"] .artifact-kind { background: #354334; color: #dce9d5; }
html[data-theme="dark"] .artifact-detail h2 { color: #f0ede5; }
html[data-theme="dark"] .artifact-content { color: #d5dbd1; }
html[data-theme="dark"] .artifact-empty { border-color: #53604f; background: #232923; color: #c3cabe; }
html[data-theme="dark"] .artifact-empty h2 { color: #f0ede5; }
html[data-theme="dark"] .settings-footer { color: #c0c8bc; }
html[data-theme="dark"] .settings-footer button { background: #8da783; color: #111710; }
html[data-theme="dark"] .settings-footer button:hover:not(:disabled) { background: #a1b99a; }
html[data-theme="dark"] .settings-footer button:disabled { border: 1px solid #53604f; background: #303830; color: #c3cabe; opacity: 1; }
html[data-theme="dark"] .crumbs,
html[data-theme="dark"] .save-indicator { color: #c0c8bc; }
html[data-theme="dark"] .coach-trigger > svg { color: #a9c79d; }
html[data-theme="dark"] .coach-trigger > span { color: #dce9d5; }
html[data-theme="dark"] .coach-trigger:hover > svg,
html[data-theme="dark"] .coach-trigger:hover > span { color: #f0ede5; }
html[data-theme="dark"] .settings-card input::placeholder { color: #aeb7ab; opacity: 1; }
html[data-theme="dark"] .coach-compose > button:disabled { border: 1px solid #53604f; background: #354034; color: #c3cabe; opacity: 1; }

/* Live panel width controls stay next to the panels they resize. */
.panel-width-control { display: grid; grid-template-columns: minmax(0, 1fr) auto; align-items: center; gap: 4px 10px; color: #62695f; font-size: 11px; font-weight: 650; }
.panel-width-control output { color: #587150; font-size: 11px; font-variant-numeric: tabular-nums; }
.panel-width-control input[type="range"] { grid-column: 1 / -1; width: 100%; height: 20px; margin: 0; appearance: none; -webkit-appearance: none; border: 0; background: transparent; padding: 0; accent-color: #71836a; cursor: ew-resize; }
.panel-width-control input[type="range"]::-webkit-slider-runnable-track { height: 5px; border-radius: 999px; background: #d7d3c8; }
.panel-width-control input[type="range"]::-webkit-slider-thumb { width: 15px; height: 15px; margin-top: -5px; appearance: none; -webkit-appearance: none; border: 2px solid #fffcf5; border-radius: 50%; background: #71836a; }
.panel-width-control input[type="range"]::-moz-range-track { height: 5px; border-radius: 999px; background: #d7d3c8; }
.panel-width-control input[type="range"]::-moz-range-thumb { width: 11px; height: 11px; border: 2px solid #fffcf5; border-radius: 50%; background: #71836a; }
.panel-width-control input[type="range"]:focus-visible { outline: 2px solid #71836a; outline-offset: 2px; }
.nav-footer .panel-width-control { margin-bottom: 6px; }
.coach-width-control { border-bottom: 1px solid #e2ddd2; padding: 11px 16px 8px; }
html[data-theme="dark"] .panel-width-control { color: #c7cec3; }
html[data-theme="dark"] .panel-width-control output { color: #c6dabd; }
html[data-theme="dark"] .panel-width-control input[type="range"]::-webkit-slider-runnable-track,
html[data-theme="dark"] .panel-width-control input[type="range"]::-moz-range-track { background: #53604f; }
html[data-theme="dark"] .panel-width-control input[type="range"]::-webkit-slider-thumb,
html[data-theme="dark"] .panel-width-control input[type="range"]::-moz-range-thumb { border-color: #202520; background: #a9c79d; }
html[data-theme="dark"] .panel-width-control input[type="range"]:focus-visible { outline-color: #a9c79d; }
html[data-theme="dark"] .coach-width-control { border-color: #394139; }
html[data-theme="dark"] .coach-card { border-color: #394139; background: #232923; color: #e9e6de; }
html[data-theme="dark"] .coach-card h2 { color: #f0ede5; }
html[data-theme="dark"] .coach-card p:not(.eyebrow) { color: #c3c7be; }
html[data-theme="dark"] .coach-overlay { background: rgba(5, 8, 6, .58); }
html[data-theme="dark"] .coach-drawer { border-color: #394139; background: #202520; color: #e9e6de; box-shadow: -18px 0 50px rgba(0,0,0,.38); }
html[data-theme="dark"] .coach-header { border-color: #394139; }
html[data-theme="dark"] .coach-header .small-icon-button { color: #bfc7bc; }
html[data-theme="dark"] .coach-header .small-icon-button:hover { background: #303830; color: #f0ede5; }
html[data-theme="dark"] .coach-agent-heading strong { color: #ece9e1; }
html[data-theme="dark"] .coach-routing-note { color: #aeb6aa; }

html[data-theme="dark"] .coach-welcome { border-color: #394139; background: #262d26; }
html[data-theme="dark"] .coach-welcome h2 { color: #ece9e1; }
html[data-theme="dark"] .coach-welcome > p:not(.eyebrow) { color: #b8c0b5; }
html[data-theme="dark"] .coach-prompt-list button { border-color: #414b41; background: #2c332c; color: #d0d7ca; }
html[data-theme="dark"] .coach-prompt-list button:hover { border-color: #65785f; background: #343f32; color: #f0ede5; }
html[data-theme="dark"] .coach-message { border-color: #3b443b; background: #272e27; }
html[data-theme="dark"] .coach-message.is-user { border-color: #4a5b47; background: #303c30; }
html[data-theme="dark"] .coach-message > span { color: #a8b1a4; }
html[data-theme="dark"] .coach-message p { color: #d5d9d1; }
html[data-theme="dark"] .coach-message > .markdown-preview { color: #d5d9d1; }
html[data-theme="dark"] .coach-compose { border-color: #414b41; background: #252c25; }
html[data-theme="dark"] .coach-compose textarea { color: #ece9e1; }
html[data-theme="dark"] .coach-compose textarea::placeholder { color: #8f998c; }
html[data-theme="dark"] .coach-error { background: #492f2a; color: #f0b7a8; }
html[data-theme="dark"] .coach-loading { color: #aeb6aa; }

```
