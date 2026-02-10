import SwiftUI

// MARK: - Command Palette Action

enum CommandPaletteAction: Identifiable {
    case newSession
    case newTerminal
    case toggleFocusMode
    case toggleChangesPanel
    case openSettings
    case compactConversation
    case clearConversation
    case initProject
    case reviewCode
    case runDoctor
    case editMemory
    case openSkillsPanel
    case openSchedules
    case selectSession(UUID)
    case toggleSplitScreen

    var id: String {
        switch self {
        case .newSession: "newSession"
        case .newTerminal: "newTerminal"
        case .toggleFocusMode: "toggleFocusMode"
        case .toggleChangesPanel: "toggleChangesPanel"
        case .openSettings: "openSettings"
        case .compactConversation: "compactConversation"
        case .clearConversation: "clearConversation"
        case .initProject: "initProject"
        case .reviewCode: "reviewCode"
        case .runDoctor: "runDoctor"
        case .editMemory: "editMemory"
        case .openSkillsPanel: "openSkillsPanel"
        case .openSchedules: "openSchedules"
        case .selectSession(let id): "session-\(id)"
        case .toggleSplitScreen: "toggleSplitScreen"
        }
    }
}

// MARK: - Command Palette Item

struct CommandPaletteItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String
    let category: Category
    let action: CommandPaletteAction
    let shortcut: String?

    enum Category: String, CaseIterable {
        case quickActions = "Quick Actions"
        case sessions = "Sessions"
    }
}

// MARK: - Command Palette Overlay

struct CommandPaletteOverlay: View {
    @Binding var isPresented: Bool
    let manager: SessionManager
    let onAction: (CommandPaletteAction) -> Void

    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    private var allItems: [CommandPaletteItem] {
        var items: [CommandPaletteItem] = [
            CommandPaletteItem(
                id: "new-session", title: "New Claude Session", subtitle: nil,
                icon: "plus.circle.fill", category: .quickActions,
                action: .newSession, shortcut: "\u{2318}N"
            ),
            CommandPaletteItem(
                id: "new-terminal", title: "New Terminal Session", subtitle: nil,
                icon: "terminal.fill", category: .quickActions,
                action: .newTerminal, shortcut: "\u{2318}T"
            ),
            CommandPaletteItem(
                id: "toggle-split", title: "Toggle Split Screen",
                subtitle: "Show two sessions side by side",
                icon: "rectangle.split.2x1", category: .quickActions,
                action: .toggleSplitScreen, shortcut: "\u{2318}\u{21e7}\\"
            ),
            CommandPaletteItem(
                id: "toggle-focus", title: "Toggle Focus Mode", subtitle: nil,
                icon: "eye.circle", category: .quickActions,
                action: .toggleFocusMode, shortcut: "\u{2318}\u{21e7}F"
            ),
            CommandPaletteItem(
                id: "toggle-changes", title: "Toggle Changes Panel", subtitle: nil,
                icon: "sidebar.right", category: .quickActions,
                action: .toggleChangesPanel, shortcut: "\u{2318}\u{21e7}D"
            ),
            CommandPaletteItem(
                id: "settings", title: "Open Settings", subtitle: nil,
                icon: "gearshape", category: .quickActions,
                action: .openSettings, shortcut: "\u{2318},"
            ),
            CommandPaletteItem(
                id: "schedules", title: "Scheduled Prompts",
                subtitle: "Manage prompts that run on a schedule",
                icon: "clock.badge", category: .quickActions,
                action: .openSchedules, shortcut: "\u{2318}H"
            ),
        ]

        // Claude slash commands — conditionally shown
        if case .claude(let session) = manager.selectedSession {
            items.append(CommandPaletteItem(
                id: "skills-panel", title: "Browse Skills",
                subtitle: "Browse and run Claude Code skills",
                icon: "wand.and.stars",
                category: .quickActions, action: .openSkillsPanel,
                shortcut: "\u{2318}\u{21e7}S"
            ))

            // Init can be sent as a first message (no sessionId needed)
            items.append(CommandPaletteItem(
                id: "init-project", title: "Initialize Project",
                subtitle: "Create CLAUDE.md in project directory",
                icon: "doc.badge.plus",
                category: .quickActions, action: .initProject, shortcut: nil
            ))

            // These require an active session
            if session.sessionId != nil {
                items.append(CommandPaletteItem(
                    id: "compact", title: "Compact Conversation",
                    subtitle: "Summarize to free context space",
                    icon: "arrow.trianglehead.2.clockwise.rotate.90",
                    category: .quickActions, action: .compactConversation, shortcut: nil
                ))
                items.append(CommandPaletteItem(
                    id: "clear", title: "Clear Conversation",
                    subtitle: "Reset conversation and start fresh",
                    icon: "trash",
                    category: .quickActions, action: .clearConversation, shortcut: nil
                ))
                items.append(CommandPaletteItem(
                    id: "review-code", title: "Review Code",
                    subtitle: "Ask Claude to review recent changes",
                    icon: "magnifyingglass.circle",
                    category: .quickActions, action: .reviewCode, shortcut: nil
                ))
                items.append(CommandPaletteItem(
                    id: "run-doctor", title: "Diagnose Issues",
                    subtitle: "Run diagnostics on setup",
                    icon: "stethoscope",
                    category: .quickActions, action: .runDoctor, shortcut: nil
                ))
                items.append(CommandPaletteItem(
                    id: "edit-memory", title: "Memory Viewer",
                    subtitle: "View and edit CLAUDE.md memory files",
                    icon: "brain",
                    category: .quickActions, action: .editMemory, shortcut: "\u{2318}\u{21e7}M"
                ))
            }
        }

        // Sessions
        for anySession in manager.sessions {
            let isTerminal: Bool
            if case .terminal = anySession { isTerminal = true } else { isTerminal = false }

            items.append(CommandPaletteItem(
                id: "session-\(anySession.id)",
                title: anySession.name,
                subtitle: anySession.workingDirectory.abbreviatingHome,
                icon: isTerminal ? "terminal.fill" : "bubble.left.and.text.bubble.right",
                category: .sessions,
                action: .selectSession(anySession.id),
                shortcut: nil
            ))
        }

        return items
    }

    private var filteredItems: [CommandPaletteItem] {
        guard !searchText.isEmpty else { return allItems }
        let query = searchText.lowercased()
        return allItems.filter { item in
            item.title.lowercased().contains(query) ||
            (item.subtitle?.lowercased().contains(query) ?? false)
        }
    }

    private var groupedItems: [(CommandPaletteItem.Category, [CommandPaletteItem])] {
        var groups: [(CommandPaletteItem.Category, [CommandPaletteItem])] = []
        for category in CommandPaletteItem.Category.allCases {
            let categoryItems = filteredItems.filter { $0.category == category }
            if !categoryItems.isEmpty {
                groups.append((category, categoryItems))
            }
        }
        return groups
    }

    private var flatItems: [CommandPaletteItem] {
        groupedItems.flatMap { $0.1 }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                // Search field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search commands\u{2026}", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .focused($isSearchFocused)
                }
                .padding(16)

                Divider()

                // Results
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            let flat = flatItems
                            ForEach(groupedItems, id: \.0) { category, items in
                                Text(category.rawValue)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12)
                                    .padding(.bottom, 4)

                                ForEach(items) { item in
                                    let globalIndex = flat.firstIndex(where: { $0.id == item.id }) ?? 0
                                    CommandPaletteRow(
                                        item: item,
                                        isSelected: globalIndex == selectedIndex
                                    )
                                    .id(item.id)
                                    .onTapGesture {
                                        onAction(item.action)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(maxHeight: 400)
                    .onChange(of: selectedIndex) { _, newIndex in
                        let flat = flatItems
                        if newIndex >= 0, newIndex < flat.count {
                            proxy.scrollTo(flat[newIndex].id, anchor: .center)
                        }
                    }
                }
            }
            .frame(width: 500)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThickMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .padding(.top, 80)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            isSearchFocused = true
            selectedIndex = 0
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            let count = flatItems.count
            if selectedIndex < count - 1 { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.return) {
            let flat = flatItems
            if selectedIndex >= 0, selectedIndex < flat.count {
                onAction(flat[selectedIndex].action)
            }
            return .handled
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
    }
}

// MARK: - Command Palette Row

private struct CommandPaletteRow: View {
    let item: CommandPaletteItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.body)
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                    .foregroundStyle(isSelected ? .white : .primary)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                }
            }

            Spacer()

            if let shortcut = item.shortcut {
                Text(shortcut)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.06))
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            isSelected ? Color.orange : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - FocusedValue for Command Palette

struct CommandPaletteToggleKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var commandPaletteToggle: Binding<Bool>? {
        get { self[CommandPaletteToggleKey.self] }
        set { self[CommandPaletteToggleKey.self] = newValue }
    }
}

// MARK: - FocusedValue for Skills Panel

struct SkillsPanelToggleKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var skillsPanelToggle: Binding<Bool>? {
        get { self[SkillsPanelToggleKey.self] }
        set { self[SkillsPanelToggleKey.self] = newValue }
    }
}

// MARK: - Notifications for cross-view communication

extension Notification.Name {
    static let toggleDiffPanel = Notification.Name("strata.toggleDiffPanel")
    static let toggleSettings = Notification.Name("strata.toggleSettings")
    static let toggleSkillsPanel = Notification.Name("strata.toggleSkillsPanel")
    static let toggleMemoryViewer = Notification.Name("strata.toggleMemoryViewer")
}
