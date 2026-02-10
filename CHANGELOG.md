# Changelog

All notable changes to Strata are documented here.

## [1.6.0] - 2026-02-10

### Added
- **Split View** (Cmd+Shift+\) for viewing two sessions side by side
- **Session Picker** in split view right pane to choose which session to display
- **Sidebar Context Menu** — "Open in Split Pane" to send any session to the right pane
- **Draggable Divider** to resize split panes (20%–80% range, persisted)
- **Text Labels** on all toolbar buttons for better discoverability
- **Scroll Top Anchor** in chat view to ensure full scroll range

### Changed
- Split view state (active, session, ratio) persists across app restarts
- Focus mode and split view are mutually exclusive
- Toolbar buttons suppressed in split view right pane to prevent duplicates

## [1.5.3] - 2026-02-07

### Fixed
- **App bundle node ENOENT error** — macOS app bundles inherit a minimal PATH missing `/usr/local/bin` and Homebrew paths, causing Claude Agent SDK to fail when spawning node subprocesses. Bridge process PATH now includes common Node.js locations.

### Added
- **App icon** (AppIcon.icns) for the bundled application
- **Folder access usage descriptions** in Info.plist for Desktop, Documents, and Downloads

## [1.5.2] - 2026-02-07

### Added
- **MCP Server Support** (Cmd+Shift+E) for connecting to Model Context Protocol servers
- **MCP Panel** to configure, connect, and manage MCP servers
- **MCP Server Catalog** — 23 built-in presets across 7 categories (Database, Filesystem, Development, Search, Communication, Productivity, Third Party)
- **Third-Party MCP Servers** — Official integrations from Atlassian, AWS, Notion, Linear, Stripe, Apify, Cloudflare, Raygun
- **MCP Tool Discovery** — automatically lists tools from connected servers
- **Context-Aware Suggestions** — unified suggestion chips for skills, agents, and MCP servers based on conversation
- **Agent Suggestions** — suggests relevant agents based on what you're discussing
- **MCP Suggestions** — suggests MCP servers to connect based on conversation context
- **Session-Based Permissions** — "Allow for Session" button to reduce permission fatigue
- **Permission Scopes** — choose to allow this file, parent directory, or all tool operations
- **Auto-Approval** — approved permissions auto-apply to future matching requests

### Changed
- Agent icon updated to brain.head.profile for better identification
- Agent indicator bar now uses purple color scheme
- Workspace panel now expands only the relevant section when opened (Changes or Todos)
- Toolbar button opens workspace panel with the section that has content
- Thinking time now shows minutes/hours for long operations (e.g., "2m 30s", "1h 5m")
- Permission dialog now has three buttons: Deny, Allow for Session, Allow
- Permission scope picker shows options based on tool type (file path vs command)

## [1.5.1] - 2026-02-07

### Added
- **Custom Agents** (Cmd+Shift+A) for creating reusable AI assistants with specific roles
- **21 Built-in Agents** including 12 developer tools and 9 small business agents
- **Agent Editor** for creating agents with custom system prompts, permission modes, and tool restrictions
- **Import/Export Agents** as JSON files for sharing agent configurations
- **Agent Mode Indicator** shows active agent with easy exit button
- **Developer Agents**: Code Explainer, Test Writer, Bug Hunter, Security Reviewer, Refactoring Assistant, Documentation Writer, Code Reviewer, Performance Optimizer, Dependency Updater, Git Helper, API Designer, Database Optimizer
- **Business Agents**: Marketing Writer, Social Media Manager, Business Email Writer, Financial Analyst, HR Assistant, Sales Assistant, Customer Support Writer, Contract Reviewer, Meeting Notes

### Changed
- Tools menu now includes Agents panel shortcut
- Session view supports agent mode with custom system prompts and permission settings

## [1.5.0] - 2026-02-06

### Added
- **Visual Task Panel** in Workspace inspector showing all tasks with status icons
- **Thinking Time Indicator** displays elapsed time while Claude is responding ("Thinking... for 7s")
- **Improved Context Bar** shows active vs cached tokens separately for accurate usage display

### Changed
- Workspace inspector now has two collapsible sections: Changes and Todos
- Context bar color now based on active (uncached) tokens only
- Compact button only appears when active context is high, not total
- Tasks sorted by status: in-progress first, then pending, then completed

### Fixed
- Context usage no longer shows misleading 100%+ when heavily cached

## [1.4.0] - 2026-02-05

### Added
- **Scheduled Prompts** (Cmd+H) for automating recurring Claude tasks
- Schedule prompts to run daily, weekdays, weekly, or at custom intervals
- Scheduled runs create real sessions in a "Scheduled Runs" sidebar group
- Configurable permission mode per schedule (auto-accept edits or full autonomy)
- Session reuse option to continue conversation or create fresh sessions
- Warning when high-frequency schedules create many sessions
- macOS notifications when scheduled tasks complete (when running as app bundle)

### Changed
- Improved schedule editor UI with segmented frequency picker
- Better time picker layout

## [1.3.0] - 2026-02-05

### Added
- **Memory Viewer panel** (Cmd+Shift+M) for browsing and editing CLAUDE.md files
- **Session folders/groups** for organizing sessions in the sidebar
- **Context visualization** with expandable breakdown by category (conversation, tools, system prompt)
- **Memory Timeline** inspector showing chronological history of file operations and commands
- **Claude Opus 4.6** model support (latest flagship)
- **Permission request queue** to handle rapid tool calls without losing requests

### Fixed
- Bridge crash handling with global error handlers for WebSearch and other tools
- Permission requests no longer get lost when multiple tools request access quickly

### Changed
- Model selection now uses 2x2 grid layout for better visibility
- Improved bridge termination error messages with exit codes

## [1.2.0] - 2025-02-05

### Added
- **Skills panel** (Cmd+Shift+S) for browsing and managing Claude Code skills
- **Multi-source skill catalog** from Anthropic, Vercel, Supabase, Expo, and Remotion
- **skills.sh search** with 40K+ skills, filtered to trusted sources
- **One-click skill install/uninstall** to `~/.claude/skills/`
- **Skill invocation** via `/skill-name` with argument support
- **Context-aware skill suggestions** based on conversation
- **Task progress bar** above input showing live completion status
- **Inline task cards** with status badges (pending, in progress, completed)
- **Active task indicator** with spinner while Claude works
- **Task persistence** across app restarts

## [1.1.0] - 2025-02-04

### Added
- **Command palette** (Cmd+K) with fuzzy search for all actions
- **Context usage bar** showing live token count with color-coded progress
- **Conversation compaction** to reclaim context space
- **Claude Code commands** — /init, /review, /doctor, /memory, /clear
- **Smart input suggestions** with Tab to accept, Shift+Tab to cycle

## [1.0.0] - 2025-02-03

### Added
- Initial release
- Multi-session management (Claude + terminal sessions)
- Streaming chat with markdown rendering
- Inline tool cards (Bash, Edit, Read, Write, Glob, Grep)
- Diff inspector panel with color-coded changes
- Permission flow with Guided/Auto/Plan Only modes
- Built-in terminal via SwiftTerm
- Focus mode (Cmd+Shift+F)
- Session persistence
- Per-session settings (model, theme, system prompt)
- Dark/Light/Auto appearance
