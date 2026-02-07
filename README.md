# Strata

**A native macOS interface for Claude Code.**

Strata wraps [Claude Code](https://docs.anthropic.com/en/docs/claude-code) in a polished SwiftUI desktop app, replacing the terminal with a visual experience — conversation bubbles, inline tool cards, diff inspection, terminal sessions, and more.

<p align="center">
<img width="900" alt="Strata — chat view with inline tool cards and changes panel" src="https://github.com/user-attachments/assets/d53e7b61-e5a4-42b1-b9c8-7c52abf77d82" />
</p>

> **Note:** This project requires [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (authenticated via `claude login`) and a working Node.js installation.

---

## Features

### Core
- **Multi-session management** — Run multiple Claude conversations and terminal sessions side by side
- **Session folders** — Organize sessions into collapsible groups in the sidebar
- **Streaming chat** — Live token streaming with markdown rendering, code blocks, and syntax hints
- **Thinking time indicator** — See elapsed time while Claude is responding ("Thinking... for 7s")
- **Inline tool cards** — See Bash commands, file edits, reads, searches rendered as expandable cards in the conversation
- **Workspace inspector** — Side panel with collapsible Changes and Todos sections
- **Permission flow** — Approve or deny tool use (file writes, command execution) per invocation
- **Permission modes** — Guided (ask first), Auto (accept edits), Plan Only (read-only)
- **Permission queue** — Handles rapid tool calls without losing requests
- **Built-in terminal** — Full terminal emulation via SwiftTerm, alongside your Claude sessions
- **Session persistence** — Conversations survive app restarts, stored locally

### Skills
- **Skills panel** — Browse and manage Claude Code skills via Cmd+Shift+S
- **Multi-source catalog** — Curated skills from Anthropic, Vercel, Supabase, Expo, and Remotion
- **skills.sh search** — Search 40,000+ skills with install counts, filtered to trusted sources
- **One-click install** — Install skills to `~/.claude/skills/` directly from the catalog
- **Skill invocation** — Run installed skills via `/skill-name` with argument support
- **Smart suggestions** — Context-aware skill chips appear based on your conversation

### Task Tracking
- **Visual task panel** — Task list in Workspace inspector with status icons (✓ completed, ⚙ in-progress, ○ pending)
- **Task progress bar** — Live progress bar above the input showing task completion
- **Inline task cards** — Expandable teal cards showing task status in the conversation
- **Active task indicator** — Spinner with current task description while Claude works
- **Smart sorting** — Tasks sorted by status: in-progress first, then pending, then completed
- **Automatic tracking** — Tasks created by Claude are tracked and persisted with your session

### Memory
- **Memory Viewer panel** — Browse and edit CLAUDE.md files via Cmd+Shift+M
- **Memory Timeline** — Chronological history of file operations, commands, and edits during the session
- **File access history** — See what files Claude has read, edited, or created with timestamps

### Scheduled Prompts
- **Schedule panel** — Automate recurring Claude tasks via Cmd+H
- **Flexible scheduling** — Run daily, weekdays, weekly, or at custom intervals
- **Session management** — Scheduled runs create sessions in a dedicated "Scheduled Runs" group
- **Permission modes** — Configure auto-accept edits or full autonomy per schedule
- **Session reuse** — Choose to continue existing conversation or create fresh sessions
- **Notifications** — macOS notifications when scheduled tasks complete

### Custom Agents
- **Agents panel** — Create and manage reusable AI assistants via Cmd+Shift+A
- **21 built-in agents** — 12 developer tools + 9 small business agents ready to use
- **Developer agents** — Code Explainer, Test Writer, Bug Hunter, Security Reviewer, Refactoring Assistant, Documentation Writer, Code Reviewer, Performance Optimizer, Dependency Updater, Git Helper, API Designer, Database Optimizer
- **Business agents** — Marketing Writer, Social Media Manager, Business Email Writer, Financial Analyst, HR Assistant, Sales Assistant, Customer Support Writer, Contract Reviewer, Meeting Notes
- **Agent editor** — Create custom agents with system prompts, permission modes, and tool restrictions
- **Import/Export** — Share agent configurations as JSON files
- **Agent mode indicator** — Visual indicator when running an agent with easy exit button

### MCP Servers
- **MCP panel** — Configure and manage Model Context Protocol servers via Cmd+Shift+E
- **Server configuration** — Set command, arguments, and environment variables for each server
- **Tool discovery** — Automatically lists tools available from connected servers
- **Connection status** — Visual indicators showing server status (running, stopped, error)
- **Import/Export** — Share MCP server configurations as JSON files

### Productivity
- **Command palette** — Quick access to all actions via Cmd+K with fuzzy search
- **Context usage bar** — Live token count with color-coded progress toward the context limit
- **Context breakdown** — Expandable view showing tokens by category (conversation, tools, system prompt)
- **Active vs cached tokens** — Context bar distinguishes active tokens from cached for accurate usage display
- **Conversation compaction** — Summarize long conversations to reclaim context space
- **Claude Code commands** — Native access to /init, /review, /doctor, /memory, and /clear
- **Focus mode** — Hide the sidebar for distraction-free conversation (Cmd+Shift+F)
- **Smart input suggestions** — Ghost-text suggestions in the input field based on conversation context, accepted with Tab
- **Customizable** — Model selection, accent colors, font sizes, density, notification sounds, custom system prompts
- **Dark / Light / Auto** appearance

---

## Screenshots

<p align="center">
<img width="700" alt="Strata — welcome screen with permission modes" src="https://github.com/user-attachments/assets/095d716d-cb7f-41e7-b32c-3107fb3b4334" />
</p>
<p align="center"><em>Welcome screen — choose a working directory and permission mode</em></p>

<p align="center">
<img width="700" alt="Strata — expanded tool card showing file contents" src="https://github.com/user-attachments/assets/edff782d-cf10-499c-bef1-5ed5b95b3273" />
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

**Development (quick iteration):**
```bash
swift build
swift run Strata
```

**App Bundle (double-clickable .app):**
```bash
./scripts/build-app.sh --release
open build/Strata.app
```

**Install to Applications:**
```bash
cp -R build/Strata.app /Applications/
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
├── scripts/
│   └── build-app.sh                 # Build .app bundle script
├── Resources/
│   └── Info.plist                   # App bundle metadata
├── bridge/
│   ├── claude-bridge.mjs            # Node.js ↔ Claude SDK bridge
│   └── package.json                 # Bridge dependencies
└── Sources/Strata/
    ├── StrataApp.swift               # App entry point, icon, delegate
    ├── ContentView.swift             # NavigationSplitView layout, focus mode
    ├── CommandsMenu.swift            # Menu bar commands & shortcuts
    ├── CommandPalette.swift          # Cmd+K command palette overlay
    │
    ├── SessionManager.swift          # Multi-session orchestration
    ├── Session.swift                 # Claude conversation state & logic
    ├── TerminalSession.swift         # PTY-backed terminal sessions
    ├── AnySession.swift              # Session type union
    ├── SessionSettings.swift         # Per-session config (model, theme)
    │
    ├── ClaudeRunner.swift            # Spawns & communicates with bridge process
    ├── ChatMessage.swift             # Message model, tool activity, task structs
    ├── FileChangeParser.swift        # Parses file changes, computes diffs
    │
    ├── SessionView.swift             # Main chat UI, input bar, task progress
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
    ├── Skill.swift                   # Skill model, parser, scanner
    ├── SkillCatalog.swift            # Remote catalog (GitHub + skills.sh)
    ├── SkillsPanel.swift             # Skills browser UI (Installed/Catalog)
    ├── SkillSuggestionChips.swift    # Context-aware skill suggestions
    │
    ├── CustomAgent.swift             # Agent model, built-in agents, persistence
    ├── AgentPanel.swift              # Agents browser, editor, import/export
    │
    ├── MemoryFile.swift              # CLAUDE.md file model
    ├── MemoryScanner.swift           # Scans for memory files in directories
    ├── MemoryViewerPanel.swift       # Memory viewer UI (Cmd+Shift+M)
    ├── MemoryTimelinePanel.swift     # Chronological activity history
    ├── ContextBreakdownView.swift    # Token usage breakdown by category
    │
    ├── ScheduledPrompt.swift         # Scheduled prompt model
    ├── ScheduleManager.swift         # Schedule execution engine
    ├── SchedulesPanel.swift          # Scheduled prompts UI (Cmd+H)
    │
    ├── MCPServer.swift               # MCP server config model and manager
    ├── MCPPanel.swift                # MCP servers UI (Cmd+Shift+E)
    │
    ├── SessionGroup.swift            # Session folder/group model
    │
    ├── PersistenceManager.swift      # File I/O, debounced saves
    ├── Persistence+Codable.swift     # Codable models for persistence
    └── Persistence+Conversions.swift # Runtime ↔ persistent model conversion
```

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| Cmd+K | Command palette |
| Cmd+N | New Claude session |
| Cmd+T | New terminal session |
| Cmd+W | Close current session |
| Cmd+Shift+F | Toggle focus mode |
| Cmd+Shift+D | Toggle diff inspector |
| Cmd+Shift+S | Open skills panel |
| Cmd+Shift+A | Open agents panel |
| Cmd+Shift+M | Open memory viewer |
| Cmd+Shift+E | Open MCP servers panel |
| Cmd+H | Open scheduled prompts |
| Cmd+, | Session settings |
| Ctrl+C | Cancel Claude response |
| Tab | Accept input suggestion |
| Shift+Tab | Cycle input suggestion |

---

## Models

Strata supports switching between Claude models per session:

| Model | Description |
|---|---|
| Claude Opus 4.6 | Latest flagship, highest capability |
| Claude Sonnet 4.5 | Balanced speed and capability (default) |
| Claude Opus 4 | High capability |
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
