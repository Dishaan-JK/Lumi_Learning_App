# Backend wiring

The React app is served with a same-origin `/api` contract. During development,
Vite proxies those requests to the bundled Lumi Dart/Genkit service at
`http://127.0.0.1:8080` by default.

Run the complete local stack from this project:

```bash
npm run dev:full
```

The launcher first checks whether the backend is already listening, so it does
not start a duplicate process. If needed, it prepares and starts the Dart service
from this repository's `backend/` package. Set `LUMI_DART_EXECUTABLE` when the
Dart SDK is not on `PATH`, and use `LUMI_BACKEND_URL` when the backend listens
on another local address.
Set `LUMI_FRONTEND_PORT` when an existing development server already uses 5173.
Vite now binds strictly to that configured port instead of silently moving to a
different port that the backend may reject. The full-stack launcher checks the
backend's exact origin allowlist before starting the UI and prints the required
`LUMI_ALLOWED_ORIGINS` value when it does not match.
When the launcher starts the backend, it also sets a strict exact
`LUMI_ALLOWED_ORIGINS` list for that Vite port. Do not use a wildcard Origin
allowlist: the local API handles exports, imports, and deletions. If connecting
to a separately started backend, configure its exact UI origin yourself.

The Dart/Genkit service is the source of truth for provider settings,
agent tools, workspace persistence, and all credentials. React only calls its
public HTTP endpoints through `/api`; no provider keys are exposed to Vite.

## Student profile and chat controls

The React client collects Name, Class, and School name before opening a workspace
whose student profile has not been completed. The existing
`GET/PUT /api/application-settings` contract persists `displayName`,
`studentClass`, `schoolName`, and `studentProfileCompleted` in the local
`application-settings.json`. Each text field allows up to 80 printable
characters; a completed profile requires all three nonblank values. Existing
settings default to an incomplete profile, so existing installations receive
this welcome form once. Settings → General edits the same fields.

The bundled service implements these settings and ships with this client. The
client keeps the form and entered values on a failed save. Every new Coach request includes the saved
student profile as context, while conversation metadata preserves the student's
original prompt separately. A configured remote AI provider receives that
context. A local greeting uses the saved name; a live model's wording depends on
the provider and is separate from request-contract tests.

New Chat starts a fresh session and retains earlier conversations in Recent.
Right-click, Shift+F10, or the row's options button opens Open chat / Delete chat.
Deletion asks for confirmation and calls the existing
`DELETE /api/agent-sessions/:id`; the saved row is removed only after success.

## Student and chat UI checks

Run `npx vitest run` for component and request-contract coverage. For an isolated
browser check with synthetic student data and mocked model responses, run:

```bash
npm run build
npm run test:e2e:student-chat
```

This starts a disposable headless Chrome profile and a local fixture server;
it never connects to the real backend or model provider. Desktop/mobile
screenshots are saved in `/tmp/lumi-student-chat-proof` by default. Override
`LUMI_CHROME_BINARY` or `LUMI_UI_PROOF_DIR` if needed. This proves the React flow,
not a live model's choice of words.

## Chrome end-to-end checks

Run `npm run test:e2e:chrome` against a dedicated Chrome session started with
remote debugging enabled, for example:

```bash
google-chrome --user-data-dir=/tmp/lumi-react-e2e-chrome \
  --remote-debugging-port=9223 --no-first-run \
  http://127.0.0.1:5173/
```

Set `LUMI_CHROME_DEBUG_URL` or `LUMI_FRONTEND_URL` when using different local
ports. The suite covers uploads, math rendering, settings, privacy clears,
import/export confirmations, and responsive layouts. Set
`LUMI_E2E_LIVE_COACH=1` to also send one short request through each of the five
Genkit agents; allow extra time when the local model is cold or CPU-bound.
