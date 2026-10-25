# Change Log

## 2026-10-25

- Replaced Coach's reload icon with a visible New Chat button and moved saved-chat deletion to a Recent chat context menu with keyboard and touch-accessible options.
- Applied the approved chat design: sans-serif headings and messages, speaker labels outside message bubbles, and visible width slider rails for Chromium and Firefox.
- Added a first-run student welcome form with persisted Name, Class, and School name, editable in General settings. Added validated fields to the sibling backend's existing application settings store.
- Include the saved student profile in every Coach request and greet returning students by name. Keep original student prompts separate from profile/context metadata.
- Open newly agent-created notes and Canvases in the main workspace after each completed turn, prioritizing a new Canvas when the turn also creates its supporting notes.
- Renamed the folder-creation workspace-root option to Default path and select it automatically when no valid parent exists.

- Verification: 51 React tests, 4 backend settings tests, production build, and isolated desktop/mobile Chrome flow passed. Browser screenshots use synthetic student data and model responses; live-provider wording was not evaluated.

## 2026-10-24

- Removed the automatic Focus session-start notice; expiry still opens the completion dialog.
- Restored Coach conversations now display only the Student's prompt, using explicit prompt metadata for new messages and a compatibility reader for older context-wrapped messages. Tool exchanges and marked reasoning stay out of the transcript.
- Refresh workspace notes, Canvases, artifacts, and related queries after a completed Coach turn so newly created note cards resolve immediately.
- Added a validated standalone note tool in the sibling Dart backend and guarded Canvas creation against the original Student request, preserved through specialist delegation. Note-only requests no longer authorize a new Canvas.

- Added the `/focus` workspace tab with a Create Timer dialog, presets, study intentions, Forest study/Quiet night/Warm sand themes, and Fullscreen API integration.
- Added a floating rectangular timer with pointer and keyboard movement, position reset, and pause/resume. Early stopping is available in the Focus tab.
- Persisted timer deadlines and themes in browser storage, with reload recovery, background catch-up, and synchronization across tabs.
- Added leaving-link guards, browser close/reload confirmation hooks, and return reminders. Browser and OS escape controls remain available; this is not native app blocking.
- Connected Coach's current completed response to a validated, request-bound browser timer action. Existing sessions cannot be silently replaced; historical messages never execute actions.
- Focus themes temporarily cover the whole app while running or paused, with a contrasting edge shadow. Normal appearance returns on expiry or switch-off. Manual starts request fullscreen; Coach and restored sessions expose a fullscreen button.
- Added an expiry popup with **End Focus Session**, which clears the timer and exits fullscreen.
- Added automated lifecycle, action-validation, and shell integration coverage. Live model-provider execution is separate from mocked integration coverage.

## 2026-10-20

- Reviewed Lumi's persistence and security boundaries across the React client and Dart/Genkit backend. Confirmed the React app uses the backend's local file storage; provider credentials remain backend-owned and quiz answer keys stay out of public artifact responses.
- Routed new Coach turns through `/api/assistant` so the backend delegates requests to the appropriate specialist without a specialist picker in the UI. Preserved streaming and conversation restoration.
- Reworked Canvas into a draggable, pannable study board with note connections and Coach context from linked notes. Added persisted connection validation and corrected drag saves to submit the latest note positions.
- Updated `.gitignore` with targeted exclusions for environment secrets, local workspace data, caches, generated test output, and local design-tool state, while keeping example environment files and design documentation versionable.

### Verification and follow-up

- React typechecking, focused Coach tests, lint, and production build passed during the session.
- Canvas browser interaction and live backend save/readback were not verified because the backend was unavailable during that session.
- The full React test suite still had two unrelated failures involving saved start-page navigation visibility and a Canvas test's expected board.
