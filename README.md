# Strata

**A native macOS interface for Claude Code.**

Strata wraps [Claude Code](https://docs.anthropic.com/en/docs/claude-code) in a polished SwiftUI desktop app, replacing the terminal with a visual experience — conversation bubbles, inline tool cards, diff inspection, terminal sessions, and more.

<p align="center">
<img width="900" alt="Strata — chat view with inline tool cards and changes panel" src="https://github.com/user-attachments/assets/d53e7b61-e5a4-42b1-b9c8-7c52abf77d82" />
</p>

> **Note:** This project requires [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (authenticated via `claude login`) and a working Node.js installation.

---

## Features

- **Multi-session management** — Run multiple Claude conversations and terminal sessions side by side
- **Streaming chat** — Live token streaming with markdown rendering, code blocks, and syntax hints
- **Inline tool cards** — See Bash commands, file edits, reads, searches rendered as expandable cards in the conversation
- **Diff inspector panel** — Side panel showing all file changes with color-coded diffs and expand/collapse
- **Permission flow** — Approve or deny tool use (file writes, command execution) per invocation
- **Permission modes** — Guided (ask first), Auto (accept edits), Plan Only (read-only)
- **Built-in terminal** — Full terminal emulation via SwiftTerm, alongside your Claude sessions
- **Focus mode** — Hide the sidebar for distraction-free conversation (Cmd+Shift+F)
- **Smart input suggestions** — Ghost-text suggestions in the input field based on conversation context, accepted with Tab
- **Session persistence** — Conversations survive app restarts, stored locally
- **Customizable** — Model selection, accent colors, font sizes, density, notification sounds, custom system prompts
- **Dark / Light / Auto** appearance

---

## Screenshots

<p align="center">
<img width="700" alt="Strata — welcome screen with permission modes" src="https://github.com/user-attachments/assets/edff782d-cf10-499c-bef1-5ed5b95b3273" />
</p>
<p align="center"><em>Welcome screen — choose a working directory and permission mode</em></p>

<p align="center">
<img width="700" alt="Strata — expanded tool card showing file contents" src="https://github.com/user-attachments/assets/095d716d-cb7f-41e7-b32c-3107fb3b4334" />
</p>
<p align="center"><em>Expandable tool cards with inline code preview</em></p>

<p align="center">
<img width="700" alt="Strata — model selection settings" src="https://github.com/user-attachments/assets/d8e82f0e-f331-45fd-bb81-e1625fc4615d" />
</p>
<p align="center"><em>Per-session model selection</em></p>

<p align="center">
<img width="700" alt="Strata — appearance settings with theme and accent colors" src="https://github.com/user-attachments/assets/6b465ec2-2df5-48f4-866b-61177c6c1445" />
</p>
<p align="center"><em>Appearance settings — theme, accent color, font size, density</em></p>

<p align="center">
<img width="700" alt="Strata — behavior settings with working directory and permissions" src="https://github.com/user-attachments/assets/fc209119-2a81-41f6-8370-8e203dee74a0" />
</p>
<p align="center"><em>Behavior settings — working directory, permission mode, notifications, system prompt</em></p>

---

## Architecture

```
┌──────────────────────────────────────────────┐
│           macOS SwiftUI App (Swift)           │
│  SessionManager → Session → ChatView / UI    │
└──────────────┬───────────────────────────────┘
               │  stdin/stdout (newline-delimited JSON)
┌──────────────▼───────────────────────────────┐
│         Node.js Bridge (claude-bridge.mjs)    │
│  Uses @anthropic-ai/claude-agent-sdk          │
└──────────────┬───────────────────────────────┘
               │  HTTPS
┌──────────────▼───────────────────────────────┐
│           Anthropic Claude API                │
└──────────────────────────────────────────────┘
```

The Swift app spawns a long-lived Node.js process. They communicate over stdin/stdout using a simple JSON-lines protocol. The bridge translates SDK events (token streams, tool invocations, permission requests) into messages the UI can render.

---

## Prerequisites

- **macOS 14** (Sonoma) or later
- **Swift 5.9+** (included with Xcode 15+)
- **Node.js 18+** (via Homebrew, nvm, or system install)
- **Claude Code** installed and authenticated (`claude` CLI — run `claude login` if needed)

---

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/skargbo/Strata.git
cd strata
```

### 2. Install bridge dependencies

```bash
cd bridge
npm install
cd ..
```

### 3. Authenticate with Claude Code

If you haven't already, log in via the CLI:

```bash
claude login
```

Strata uses the same authentication as the Claude Code CLI (OAuth). Alternatively, you can set an `ANTHROPIC_API_KEY` environment variable.

### 4. Build and run

```bash
swift build
swift run Strata
```

Or open in Xcode:

```bash
open Package.swift
```

Then select the `Strata` scheme and run (Cmd+R).

---

## Project Structure

```
Strata/
├── Package.swift                    # Swift Package Manager manifest
├── bridge/
│   ├── claude-bridge.mjs            # Node.js ↔ Claude SDK bridge
│   └── package.json                 # Bridge dependencies
└── Sources/Strata/
    ├── StrataApp.swift               # App entry point, icon, delegate
    ├── ContentView.swift             # NavigationSplitView layout, focus mode
    ├── CommandsMenu.swift            # Menu bar commands & shortcuts
    │
    ├── SessionManager.swift          # Multi-session orchestration
    ├── Session.swift                 # Claude conversation state & logic
    ├── TerminalSession.swift         # PTY-backed terminal sessions
    ├── AnySession.swift              # Session type union
    ├── SessionSettings.swift         # Per-session config (model, theme)
    │
    ├── ClaudeRunner.swift            # Spawns & communicates with bridge process
    ├── ChatMessage.swift             # Message model, tool activity structs
    ├── FileChangeParser.swift        # Parses file changes, computes diffs
    │
    ├── SessionView.swift             # Main chat UI, input bar, suggestions
    ├── ChatView.swift                # Message list with bubbles
    ├── SidebarView.swift             # Session list, new session buttons
    ├── ToolActivityRow.swift         # Expandable tool invocation cards
    ├── DiffInspectorView.swift       # File changes inspector panel
    ├── MarkdownText.swift            # Markdown → SwiftUI renderer
    ├── InputField.swift              # NSTextField wrapper with ghost suggestions
    ├── TerminalSessionView.swift     # Terminal view (SwiftTerm)
    ├── SessionSettingsPopover.swift   # Settings panel
    ├── PermissionRequestView.swift   # Tool permission approval modal
    │
    ├── PersistenceManager.swift      # File I/O, debounced saves
    ├── Persistence+Codable.swift     # Codable models for persistence
    └── Persistence+Conversions.swift # Runtime ↔ persistent model conversion
```

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| Cmd+N | New Claude session |
| Cmd+T | New terminal session |
| Cmd+W | Close current session |
| Cmd+Shift+F | Toggle focus mode |
| Cmd+Shift+D | Toggle diff inspector |
| Cmd+, | Session settings |
| Ctrl+C | Cancel Claude response |
| Tab | Accept input suggestion |
| Shift+Tab | Cycle input suggestion |

---

## Models

Strata supports switching between Claude models per session:

| Model | Description |
|---|---|
| Claude Sonnet 4.5 | Balanced speed and capability (default) |
| Claude Opus 4 | Highest capability |
| Claude Haiku 3.5 | Fastest, lowest cost |

---

## How It Works

1. **You type a message** in the input bar and press Enter
2. **The Swift app** sends the message as JSON to the Node.js bridge process via stdin
3. **The bridge** calls the Claude Agent SDK's `query()` function with streaming enabled
4. **Claude responds** with text tokens (streamed live) and tool use requests
5. **Tool invocations** (file edits, bash commands, etc.) appear as inline cards
6. **Permission requests** surface as modal dialogs — you approve or deny
7. **File changes** populate the inspector panel with diffs
8. **Sessions persist** to `~/Library/Application Support/Strata/` as JSON

---

## Configuration

### Environment Variables

| Variable | Required | Description |
|---|---|---|
| `ANTHROPIC_API_KEY` | No | Optional — overrides Claude Code OAuth authentication |

### Per-Session Settings

Accessible via the gear icon or Cmd+,:

- **Model** — Choose which Claude model to use
- **Permission mode** — Guided / Auto / Plan Only
- **Working directory** — Where Claude operates
- **System prompt** — Custom instructions for Claude
- **Appearance** — Accent color, font size, message density
- **Notifications** — Sound alerts on completion

---

## License

This project is licensed under the **Business Source License 1.1 (BSL 1.1)**.

- You may view, use, and modify the source code for **non-commercial purposes**
- **Commercial use** requires a separate license from the author
- See [LICENSE](LICENSE) for full terms

---

## Acknowledgments

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and the [Claude Agent SDK](https://www.npmjs.com/package/@anthropic-ai/claude-agent-sdk) by Anthropic
- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) by Miguel de Icaza
- Design philosophy inspired by Jonathan Ive's principles of simplicity and intentional materiality
