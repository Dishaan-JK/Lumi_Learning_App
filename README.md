# Lumi Learning Workspace

Lumi is a local learning workspace for collecting notes and turning them into
study materials. This repository contains the React web interface and the
Dart/Genkit service it uses. Native single-file releases package both together,
so learners do not need Node.js, React, TypeScript, Dart, or this source
repository installed.

## What you can do

- Create and organize notes in folders.
- Arrange and connect notes on a visual Canvas.
- Browse saved learning artifacts, including quizzes and flashcards, and review
  or take supported activities.
- Chat with the Lumi Coach when an AI provider is configured.
- Adjust appearance and workspace settings, including dark mode and panel
  widths.

The app runs its local service on loopback and stores workspace data on the
computer where it runs. Packaged data defaults to `%LOCALAPPDATA%\Lumi` on
Windows, `~/Library/Application Support/Lumi` on macOS, and
`$XDG_DATA_HOME/lumi` or `~/.local/share/lumi` on Linux. Set `LUMI_DATA_DIR` to
use a different location. AI provider credentials are managed by the local
service and are not put into the browser bundle.

## Desktop support

Release builds target Windows x64, macOS Intel x64 and Apple Silicon arm64, and
Linux x64 and arm64. Each release includes its own native service and local web
server; users only need a modern web browser. The release workflow builds each
target on its native GitHub Actions runner.

Linux builds use glibc 2.35 or newer and are intended for common glibc-based
distributions, including Debian/Ubuntu, Fedora/RHEL, Arch, SUSE, Void, and
Gentoo. Alpine and other musl-based systems are not supported by these builds.
Local model download/management currently requires Linux; remote model providers
work on all packaged desktop targets.

## Install and run Lumi

You do not need to install Node.js, Dart, npm packages, or Rust yourself. Lumi
downloads its private Node.js and Dart runtimes, checks for outdated app
packages, and updates them when needed. Keep an internet connection on the first
run so Lumi can download the app and its dependencies.

### 1. Download the project

**Windows:** Download the [Lumi project ZIP for the React_v branch](https://github.com/Dishaan-JK/Lumi_Learning_App/archive/refs/heads/React_v.zip), right-click it, and choose **Extract All**.

**Linux:** Open a terminal where you want to install Lumi and run:

```sh
curl -fL https://github.com/Dishaan-JK/Lumi_Learning_App/archive/refs/heads/React_v.tar.gz -o lumi-source.tar.gz &&
mkdir -p lumi-web &&
tar -xzf lumi-source.tar.gz --strip-components=1 -C lumi-web &&
cd lumi-web
```

Open the extracted project folder. It contains `Lumi.bat` and `Lumi.sh` at its
top level. Keep the whole folder together; the React web files alone do not
include the backend Lumi needs to save notes and settings.

The archive includes `dist/`, the `backend/` directory, and the launcher scripts.
If you previously extracted only `dist/`, run the Linux commands above in a
new empty folder to get the complete project.

### 2. Start Lumi

- **Windows:** double-click `Lumi.bat`.
- **Linux:** in the project folder, type `sh Lumi.sh` and press Enter. In many
  file managers, right-click the folder background and choose **Open in
  Terminal**.

On the first run, Lumi automatically downloads its private runtimes and React
web bundle, prepares or updates the React and backend packages, and checks
that both parts of the app start. You do not need to install Node.js, Dart,
npm packages, or other app packages yourself.
This can take a few minutes. Lumi then asks whether to open the Web App in your
default browser. Choose **Yes** to open it at
[`http://127.0.0.1:5173`](http://127.0.0.1:5173).

The first launch also sets up the `lumi` command for your account. On Linux,
open a new terminal after the first run, then type `lumi` to start Lumi and
open the app in your browser. On Windows, open a new Command Prompt and type
`lumi`. Each later `lumi` command starts the frontend and backend and opens the
browser automatically.

Keep the terminal window open while using Lumi. Press **Ctrl+C** there to stop
both parts of the app. If the browser does not open, visit
[`http://127.0.0.1:5173`](http://127.0.0.1:5173). Your notes and settings are
saved on your computer; see [Where your data lives](#where-your-data-lives).

### Where your data lives

Set `LUMI_DATA_DIR` to select another location. For example, on Linux:

```text
~/.local/share/lumi
```

```bash
LUMI_DATA_DIR="$HOME/Documents/LumiData" "$HOME/.local/bin/lumi"
```

Back up this directory before removing it. Deleting it removes the local Lumi
workspace and its settings.

## Connect Google Gemini (API key example)

Lumi can use Google Gemini, OpenAI, Anthropic, an OpenAI-compatible API, or a
local Ollama service. This walkthrough uses Google Gemini.

### 1. Create a Gemini API key

1. Sign in to [Google AI Studio](https://aistudio.google.com/) with your Google
   account and open its [API keys page](https://aistudio.google.com/apikey).
2. Create a key for a project, following Google's prompts for project access
   and any applicable API terms or billing setup.
3. Copy the key and keep it in a password manager or another private place.
   Treat it like a password: do not post it, share it, or put it in a screenshot
   or source file. Google explains key creation and restrictions in its
   [Gemini API key guide](https://ai.google.dev/gemini-api/docs/api-key).

### 2. Add and test it in Lumi

1. Open Lumi and go to **Settings → AI & models**.
2. Choose **Google Gemini** from **Provider**.
3. Paste the key into **API key**. Lumi contacts Google's model-list endpoint
   and displays the models available to that key; choose one from **Model**.
4. Select **Test connection**. When the test succeeds, select **Save
   connection**. Lumi clears the key from the input after saving. To keep the
   key already saved for Gemini, leave the field blank.

The provider screen uses Google's standard Gemini endpoint, so there is no API
base URL to enter. Available models and access depend on Google's current API,
project, region, account, and quota settings. Check your Google AI Studio usage
and billing pages for the terms that apply to your project.

### 3. How Lumi handles the key and connection

- The web page sends the key to Lumi's service on the same computer through its
  loopback address. The key is not sent to a Lumi-hosted server.
- Lumi's local service makes the Gemini model-list and model requests to
  Google's HTTPS API. The key is sent in the API request, not placed in the
  page's source code or URL.
- When saved, the key is stored by the local service in
  `provider-settings.json` under Lumi's data directory. On Linux, the data
  directory is restricted to the current user, and the settings file is
  written with owner-only permissions. The service does not return the key to
  the web page; Settings only learns whether a key is configured. Workspace
  exports exclude provider credentials.
- The local browser-to-service hop uses loopback HTTP, not TLS. Keep Lumi on
  your own computer and do not expose its local service port to a network or
  the public internet. The outgoing Gemini connection uses HTTPS.

Restrict the key to the Gemini API in Google AI Studio when that control is
available, and monitor the project's usage and quota. If the key is exposed,
revoke it in AI Studio, create a replacement, enter it in Lumi, test it, and
save the new connection. These controls follow Google's
[Gemini API key security guidance](https://ai.google.dev/gemini-api/docs/api-key).

## Run from source (developers)

For manual source development, Node.js 22 or newer, npm, and Dart 3.12 or newer
are used. The normal install steps above provide these tools automatically. The
bundled backend is in this repository, so no sibling checkout is needed. The
launcher checks and updates the app packages before starting the Web App and
backend. Keep the terminal open while using Lumi; press **Ctrl+C** there to
stop both services.

Linux/macOS:

```sh
./Lumi.sh
```

Windows PowerShell or Command Prompt:

```powershell
.\Lumi.bat
```

To run the stack manually instead:

```bash
npm ci
npm run dev:full
```

See [BACKEND.md](BACKEND.md) for backend paths, ports, and local API setup. To
build a native single-file package for the current OS and CPU, also install
Rust, then run:

```bash
npm run bundle:single
```

The build output is named `release/lumi-<os>-<arch>`. The build is native to
the current OS and architecture. GitHub Actions builds all supported release
targets on their matching runners. For front-end-only development, use
`npm run dev` with a Lumi backend already running at `http://127.0.0.1:8080`.

## Developer checks

```bash
npm run lint
npx vitest run
npm run build
npm run test:e2e:chrome
```

The Chrome end-to-end workflow is described in [BACKEND.md](BACKEND.md).

## Project notes

- [ChangeLog.md](ChangeLog.md) records project changes.
- [BACKEND.md](BACKEND.md) explains the React-to-Dart service connection.
- [PROJECT_PLAN.md](PROJECT_PLAN.md) tracks project scope and direction.

The [Lumi React Workspace canvas](https://superdesign.dev/teams/a4c9d57a-42d9-4578-8e2e-a8209329992f/projects/f6b6afec-4846-449e-b392-21418bc6047b) is a design reference; its generated HTML is not used at runtime.

## Focus mode

Open **Focus mode → Create Timer**, choose 1–240 minutes and an optional study
intention, then start. The countdown appears in the Focus tab and in a floating
widget at the top center of every workspace page. Drag its handle (or focus the
handle and use arrow keys) to move it; the reset-position button centers it
again. Pause/resume works from either surface. Return to the Focus tab and use
**Switch off timer** to end early. Pausing keeps focus protection enabled.

Forest study, Quiet night, and Warm sand temporarily theme the whole app while
the timer is running or paused. A contrasting shadow outlines the app edges
(dark on light themes, light on Quiet night). Saved appearance preferences are
not changed; the usual workspace theme returns on switch-off or expiry. The timer and Focus theme are stored
in this browser's local storage; a deadline keeps the countdown accurate after
background throttling and reload. Open tabs on the same origin synchronize timer
changes. Clearing browser storage removes this state; it is not synced through
the Dart workspace service.

Ask Coach, for example, **“Start a 25 minute focus timer for biology.”** The client
advertises a browser action to the existing assistant and validates its completed
response against a unique request ID, duration bounds, and supported themes.
Only the completed current reply can start a timer; restored conversations never
execute actions. An unfinished timer is never automatically replaced. This is a
client-side action bridge, not a new Dart/Genkit server tool. The configured model
must follow the action protocol; live-provider behavior is not guaranteed by the
mocked integration tests. Starting a timer manually requests fullscreen through the Fullscreen API.
Coach-created or restored sessions offer **Enter fullscreen** in the floating
widget because the browser requires a fresh student click.

While a session is active, links that leave the current document are intercepted
with a reminder to switch off the timer in Focus mode. Reload/close attempts use
the browser's standard confirmation where supported. Tab visibility and
fullscreen exits show a reminder when the student returns. Fullscreen
can also be requested from the Focus tab or floating widget. Browsers always retain
Esc, tab switching, browser controls, and OS app switching: **a website cannot
block other applications or force the student to stay**. Device-level enforcement
would require a separately installed, authorized native/kiosk integration.

When the timer expires, an in-app modal announces **Your time is over.** and
offers **End Focus Session**. The usual theme returns immediately at expiry;
the button dismisses the popup, clears the timer, and exits fullscreen. Esc in
the completion popup also ends the session. An expired session restored after
a reload shows the same popup until acknowledged.


Coach stores the exact Student prompt in message metadata so restored **You**
messages show the request, while attached note/Canvas context stays available to
the model. Older context-wrapped messages have a compatibility reader. Tool
exchanges and marked reasoning are excluded from the visible transcript. A
completed Coach turn refreshes workspace queries so created note cards display
the saved title and content immediately.

The bundled Dart service provides **createWorkspaceNote** for standalone notes,
rejects empty agent-created note drafts, and checks the original Student prompt
before allowing a new Canvas. Restart the local backend after updating these
server files; refreshing the React page alone does not reload Dart agent definitions.
