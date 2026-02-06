# Changelog

All notable changes to Strata are documented here.

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
