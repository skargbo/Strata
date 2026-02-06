import AppKit
import SwiftUI

struct SessionView: View {
    @Bindable var session: Session
    @Binding var appearanceMode: AppearanceMode
    @State private var inputText: String = ""
    @State private var showDiffPanel: Bool = false
    @State private var showSettings: Bool = false
    @State private var showSkills: Bool = false
    @State private var showMemoryViewer: Bool = false
    @State private var showMemoryTimeline: Bool = false
    @FocusState private var inputFocused: Bool
    @State private var triggerInputFocus: Bool = false
    @State private var suggestionIndex: Int = 0

    private var contextualSuggestions: [String] {
        if session.messages.isEmpty {
            return [
                "Review this code and suggest improvements",
                "Explain what this project does",
                "Look for potential bugs in this codebase",
                "Suggest tests I should add",
                "Identify performance improvements"
            ]
        }

        guard let lastAssistant = session.messages.last(where: { $0.role == .assistant }),
              !lastAssistant.text.isEmpty else {
            return []
        }

        let text = lastAssistant.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()

        // --- Pattern: explicit yes/no questions ---

        // "Want to build/do/proceed/implement/continue/try...?"
        if lower.contains(#/want\s+(me\s+)?to\s+\w+.*\?/#) {
            let verb = extractVerb(after: #/want\s+(?:me\s+)?to\s+/#, in: lower)
            return [
                "Yes, let's \(verb)",
                "Not right now",
                "Tell me more first",
                "Let's take a different approach"
            ]
        }

        // "Should I ...?"
        if lower.contains(#/should\s+i\s+\w+.*\?/#) {
            let verb = extractVerb(after: #/should\s+i\s+/#, in: lower)
            return [
                "Yes, \(verb)",
                "No, hold off on that",
                "Let me think about it",
                "Can you explain the tradeoffs?"
            ]
        }

        // "Shall I ...?" / "Can I ...?" / "Would you like me to ...?"
        if lower.contains(#/(shall|can)\s+i\s+\w+.*\?/#)
            || lower.contains(#/would\s+you\s+like\s+(me\s+)?to\s+/#) {
            return [
                "Yes, go ahead",
                "No, that's fine",
                "What would that involve?",
                "Let's do something else instead"
            ]
        }

        // --- Pattern: choice questions ---

        // "Which option/approach...?" or "What approach/method...?"
        if lower.contains(#/(which|what)\s+(option|approach|method|strategy|way|pattern|style)/#) {
            return [
                "Go with the first option",
                "The second approach",
                "Which do you recommend?",
                "Can you compare them?"
            ]
        }

        // --- Pattern: confirmation after completing work ---

        // "Does this/that look good?" / "How does this look?"
        if lower.contains(#/(does|how)\s+(this|that)\s+look/#)
            || lower.contains(#/look(s)?\s+(good|right|correct|ok)/#) {
            return [
                "Looks good",
                "Can you change...",
                "Let me test it first",
                "Not quite, can you..."
            ]
        }

        // "Is there anything else..." / "What else..."
        if lower.contains(#/is\s+there\s+anything\s+else/#)
            || lower.contains(#/what\s+else\s+(should|can|would)/#) {
            return [
                "That's all for now",
                "Yes, can you also...",
                "Let's move on to testing",
                "Can you review what we've done?"
            ]
        }

        // "Ready to ...?" / "Are you ready?"
        if lower.contains(#/ready\s+to\s+/#) || lower.contains("are you ready") {
            return [
                "Yes, let's go",
                "Give me a moment",
                "First, can you...",
                "Let's review the plan"
            ]
        }

        // --- Pattern: generic question fallback ---
        if text.hasSuffix("?") {
            return [
                "Yes, let's do it",
                "No, let's try something else",
                "Tell me more about this",
                "Can you show me an example?"
            ]
        }

        // --- Pattern: finished statement (no question) ---
        return [
            "Continue",
            "Can you explain that further?",
            "What else can we improve?",
            "Let's move on to the next task"
        ]
    }

    /// Extract the verb phrase after a regex match for natural suggestions.
    private func extractVerb(after pattern: some RegexComponent, in text: String) -> String {
        guard let match = text.firstMatch(of: pattern) else { return "do it" }
        let remainder = text[match.range.upperBound...]
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "?", with: "")
        let words = remainder.split(separator: " ").prefix(5).joined(separator: " ")
        return words.isEmpty ? "do it" : words
    }

    private var currentSuggestion: String? {
        let suggestions = contextualSuggestions
        guard !suggestions.isEmpty else { return nil }
        return suggestions[suggestionIndex % suggestions.count]
    }

    private var currentFileChanges: [FileChange] {
        // Extract file changes from tool activities (structured data from the SDK)
        var changes: [FileChange] = []

        for message in session.messages {
            guard message.role == .tool, let activity = message.toolActivity else { continue }

            let action: FileChangeAction
            switch activity.toolName {
            case "Edit":   action = .update
            case "Write":  action = .write
            case "Read":   action = .read
            case "Create": action = .create
            default: continue
            }

            guard let filePath = activity.input.filePath else { continue }

            let diffLines = activity.result.diffLines ?? []
            let summary = activity.summaryText

            changes.append(FileChange(
                action: action,
                filePath: filePath,
                summaryLine: summary,
                diffLines: diffLines
            ))
        }

        // Also check assistant message text for the legacy parsed format
        for message in session.messages where message.role == .assistant {
            changes.append(contentsOf: FileChangeParser.parse(message.text))
        }

        return changes
    }

    var body: some View {
        VStack(spacing: 0) {
            if session.messages.isEmpty {
                // Welcome state
                ZStack {
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.orange.opacity(0.08),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 50,
                        endRadius: 400
                    )
                    .ignoresSafeArea()

                    VStack(spacing: 24) {
                        Image(systemName: "square.stack.3d.down.dottedline")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)

                        Text("Strata")
                            .font(.title)
                            .fontWeight(.semibold)

                        Text("A Better UI for Claude Code")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        VStack(spacing: 8) {
                            Text("Working Directory")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)

                            Button {
                                pickDirectory()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder.fill")
                                    Text(session.workingDirectory.abbreviatingHome)
                                        .lineLimit(1)
                                        .truncationMode(.head)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                }
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            .help("Change working directory")
                        }

                        // Permission mode cards
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Permission Mode")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 12) {
                                PermissionModeCard(
                                    title: "Guided",
                                    subtitle: "Ask before making changes",
                                    mode: "default",
                                    recommended: true,
                                    icon: "hand.raised.fill",
                                    isSelected: session.permissionMode == "default"
                                ) { session.permissionMode = "default" }

                                PermissionModeCard(
                                    title: "Auto",
                                    subtitle: "Accept file edits automatically",
                                    mode: "acceptEdits",
                                    recommended: false,
                                    icon: "bolt.fill",
                                    isSelected: session.permissionMode == "acceptEdits"
                                ) { session.permissionMode = "acceptEdits" }

                                PermissionModeCard(
                                    title: "Plan Only",
                                    subtitle: "Read-only, no file changes",
                                    mode: "plan",
                                    recommended: false,
                                    icon: "eye.fill",
                                    isSelected: session.permissionMode == "plan"
                                ) { session.permissionMode = "plan" }
                            }
                        }
                        .frame(maxWidth: 520)

                        // Start Conversation CTA
                        HoverButton(label: "Start Conversation") {
                            triggerInputFocus = true
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                // Chat messages
                ChatView(
                    messages: session.messages,
                    isResponding: session.isResponding,
                    toolCardsDefaultExpanded: session.settings.toolCardsDefaultExpanded,
                    messageSpacing: session.settings.theme.density.messageSpacing,
                    bodyFontSize: session.settings.theme.fontSize.bodySize,
                    onFileChangeTapped: { _ in
                        showDiffPanel = true
                    }
                )
            }

            // Usage stats bar
            if let usage = session.lastUsage {
                Divider()
                VStack(spacing: 4) {
                    // Context usage bar
                    if session.contextTokens > 0 {
                        ContextUsageBar(
                            contextTokens: session.contextTokens,
                            maxTokens: session.settings.model.maxContextTokens,
                            usagePercent: session.contextUsagePercent,
                            isCompacting: session.isCompacting,
                            canCompact: session.sessionId != nil && !session.isResponding,
                            contextBreakdown: session.contextBreakdown,
                            cacheReadTokens: usage.cacheReadTokens,
                            onCompact: { focus in
                                session.compact(focusInstructions: focus)
                            }
                        )
                    }

                    HStack(spacing: 16) {
                        Label(
                            "\(usage.totalInputTokens.formatted()) in / \(usage.outputTokens.formatted()) out",
                            systemImage: "arrow.left.arrow.right"
                        )

                        if usage.cacheReadTokens > 0 {
                            Label(
                                "\(usage.cacheReadTokens.formatted()) cached",
                                systemImage: "memorychip"
                            )
                        }

                        Label(
                            String(format: "$%.4f", session.totalCost),
                            systemImage: "dollarsign.circle"
                        )

                        Label(
                            String(format: "%.1fs", Double(usage.durationMs) / 1000),
                            systemImage: "clock"
                        )

                        Label(session.settings.model.shortName, systemImage: "cpu")

                        Spacer()
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }

            // Skill suggestion chips
            if !session.isResponding, !session.messages.isEmpty {
                let suggested = session.suggestedSkills()
                if !suggested.isEmpty {
                    SkillSuggestionChips(suggestions: suggested) { skill in
                        session.sendSkill(skill, arguments: "")
                    }
                }
            }

            // Task progress bar
            if !session.tasks.isEmpty {
                TaskProgressBar(tasks: Array(session.tasks.values))
            }

            Divider()

            // Input bar
            HStack(spacing: 10) {
                InputField(
                    text: $inputText,
                    placeholder: "Message Claude...",
                    suggestion: inputText.isEmpty && !session.isResponding ? currentSuggestion : nil,
                    requestFocus: $triggerInputFocus,
                    onSubmit: { sendMessage() },
                    onCycleSuggestion: {
                        let count = contextualSuggestions.count
                        if count > 0 {
                            suggestionIndex = (suggestionIndex + 1) % count
                        }
                    }
                )
                .frame(height: 36)
                .padding(.leading, 14)

                if session.isResponding {
                    Button {
                        session.cancel()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.red, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Cancel response")
                } else {
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(
                                inputText.isEmpty
                                    ? AnyShapeStyle(Color.secondary.opacity(0.4))
                                    : AnyShapeStyle(
                                        LinearGradient(
                                            colors: [Color.orange, Color.orange.opacity(0.8)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    ),
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.isEmpty)
                }
            }
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Suggestion hint bar
            if inputText.isEmpty && !session.isResponding, currentSuggestion != nil {
                HStack(spacing: 4) {
                    Text("\u{21E5}")
                        .fontWeight(.bold)
                    Text("tab to accept")
                    Text("\u{00B7}")
                    Text("shift+tab to cycle")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 6)
            }
        }
        .inspector(isPresented: $showDiffPanel) {
            DiffInspectorView(
                changes: currentFileChanges,
                isPresented: $showDiffPanel
            )
            .inspectorColumnWidth(min: 280, ideal: 380, max: 550)
        }
        .inspector(isPresented: $showMemoryTimeline) {
            MemoryTimelinePanel(
                memoryEvents: session.memoryEvents,
                isPresented: $showMemoryTimeline
            )
            .inspectorColumnWidth(min: 280, ideal: 340, max: 450)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 4) {
                    Button {
                        showMemoryTimeline.toggle()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .help("Memory Timeline")

                    Button {
                        showMemoryViewer.toggle()
                    } label: {
                        Image(systemName: "brain")
                    }
                    .help("Memory Viewer (Cmd+Shift+M)")

                    Button {
                        session.scanSkills(force: true)
                        showSkills.toggle()
                    } label: {
                        Image(systemName: "wand.and.stars")
                    }
                    .help("Skills Panel")

                    Button {
                        showSettings.toggle()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .help("Session Settings")

                    Button {
                        showDiffPanel.toggle()
                    } label: {
                        Image(systemName: "sidebar.right")
                    }
                    .help("Toggle Changes Panel")
                    .disabled(currentFileChanges.isEmpty)
                }
            }
        }
        .onChange(of: session.messages.count) {
            suggestionIndex = 0
            let changes = currentFileChanges
            if !changes.isEmpty {
                showDiffPanel = true
            }
        }
        .sheet(isPresented: $showSettings) {
            SessionSettingsPanel(
                settings: session.settings,
                appearanceMode: $appearanceMode,
                onPickDirectory: { pickDirectory() }
            )
        }
        .sheet(item: $session.pendingPermission) { request in
            PermissionRequestView(
                request: request,
                onAllow: {
                    session.respondToPermission(allow: true)
                },
                onDeny: {
                    session.respondToPermission(allow: false)
                }
            )
        }
        .sheet(isPresented: $showSkills) {
            SkillsPanel(
                skills: session.cachedSkills,
                onInvoke: { skill, args in
                    session.sendSkill(skill, arguments: args)
                },
                onInstall: { catalogSkill in
                    try? session.installCatalogSkill(catalogSkill)
                },
                onUninstall: { catalogSkill in
                    try? session.uninstallCatalogSkill(catalogSkill)
                }
            )
        }
        .sheet(isPresented: $showMemoryViewer) {
            MemoryViewerPanel(workingDirectory: session.workingDirectory)
        }
        .focusedSceneValue(\.diffPanelToggle, $showDiffPanel)
        .focusedSceneValue(\.settingsToggle, $showSettings)
        .focusedSceneValue(\.skillsPanelToggle, $showSkills)
        .focusedSceneValue(\.memoryViewerToggle, $showMemoryViewer)
        .tint(session.settings.theme.accentColor.color)
        .onReceive(NotificationCenter.default.publisher(for: .toggleDiffPanel)) { _ in
            showDiffPanel.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSettings)) { _ in
            showSettings.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSkillsPanel)) { _ in
            session.scanSkills(force: true)
            showSkills.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleMemoryViewer)) { _ in
            showMemoryViewer.toggle()
        }
        .onAppear {
            inputFocused = true
            session.scanSkills()
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        session.send(text)
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Select"
        panel.message = "Choose a working directory for this session"
        panel.directoryURL = URL(fileURLWithPath: session.workingDirectory)

        if panel.runModal() == .OK, let url = panel.url {
            session.workingDirectory = url.path
            let dirName = (url.path as NSString).lastPathComponent
            session.name = "Session \u{2014} \(dirName)"
        }
    }

}

// MARK: - Permission Mode Card (with hover)

private struct PermissionModeCard: View {
    let title: String
    let subtitle: String
    let mode: String
    let recommended: Bool
    let icon: String
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(isSelected ? .orange : .secondary)
                    Spacer()
                    if recommended {
                        Text("RECOMMENDED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange, in: RoundedRectangle(cornerRadius: 4))
                    }
                }

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(isHovered ? 0.10 : 0.04), radius: isHovered ? 12 : 8, y: isHovered ? 4 : 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color.orange : Color.primary.opacity(isHovered ? 0.2 : 0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Hover Button (CTA)

private struct HoverButton: View {
    let label: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    Color.orange.opacity(isHovered ? 0.85 : 1.0),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .shadow(color: .orange.opacity(isHovered ? 0.3 : 0), radius: 8, y: 2)
                .scaleEffect(isHovered ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Context Usage Bar

private struct ContextUsageBar: View {
    let contextTokens: Int
    let maxTokens: Int
    let usagePercent: Double
    let isCompacting: Bool
    let canCompact: Bool
    let contextBreakdown: ContextBreakdown
    let cacheReadTokens: Int
    let onCompact: (String?) -> Void

    @State private var showCompactPopover = false
    @State private var showBreakdownPopover = false
    @State private var compactFocus = ""

    private var barColor: Color {
        if usagePercent > 0.8 { return .red }
        if usagePercent > 0.5 { return .orange }
        return .green
    }

    var body: some View {
        HStack(spacing: 8) {
            // Clickable bar to show breakdown
            Button {
                showBreakdownPopover.toggle()
            } label: {
                HStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.primary.opacity(0.08))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(barColor)
                                .frame(width: geo.size.width * min(usagePercent, 1.0))
                        }
                    }
                    .frame(height: 6)
                    .frame(maxWidth: 120)

                    HStack(spacing: 4) {
                        Text("\(contextTokens.formatted()) / \(maxTokens.formatted()) tokens (\(Int(usagePercent * 100))%)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showBreakdownPopover) {
                ContextBreakdownView(
                    breakdown: contextBreakdown,
                    totalTokens: contextTokens,
                    maxTokens: maxTokens,
                    cacheReadTokens: cacheReadTokens
                )
            }

            Spacer()

            if usagePercent > 0.5 && canCompact && !isCompacting {
                Button {
                    showCompactPopover.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                            .font(.caption2)
                        Text("Compact")
                            .font(.caption2)
                    }
                    .foregroundStyle(usagePercent > 0.8 ? .red : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (usagePercent > 0.8 ? Color.red : Color.orange).opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 4)
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showCompactPopover) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Compact Conversation")
                            .font(.headline)

                        Text("Summarize the conversation to free context space.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("Focus on\u{2026} (optional)", text: $compactFocus)
                            .textFieldStyle(.roundedBorder)
                            .font(.callout)

                        HStack {
                            Button("Cancel") {
                                showCompactPopover = false
                            }
                            .keyboardShortcut(.escape, modifiers: [])
                            Spacer()
                            Button("Compact") {
                                let focus = compactFocus.isEmpty ? nil : compactFocus
                                onCompact(focus)
                                showCompactPopover = false
                                compactFocus = ""
                            }
                            .keyboardShortcut(.return, modifiers: [])
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(16)
                    .frame(width: 300)
                }
            }

            if isCompacting {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Compacting\u{2026}")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }
}

struct EmptySessionView: View {
    let onNewSession: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.down.dottedline")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Strata")
                .font(.title2)
                .fontWeight(.semibold)

            Text("A Better UI for Claude Code")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("Create a new session or select one from the sidebar.")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button("New Session") {
                onNewSession()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Task Progress Bar

private struct TaskProgressBar: View {
    let tasks: [SessionTask]

    private var activeTasks: [SessionTask] {
        tasks.filter { $0.status != .deleted }
    }

    private var completedCount: Int {
        activeTasks.filter { $0.status == .completed }.count
    }

    private var inProgressTask: SessionTask? {
        activeTasks.first { $0.status == .in_progress }
    }

    private var progress: Double {
        guard !activeTasks.isEmpty else { return 0 }
        return Double(completedCount) / Double(activeTasks.count)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.teal)
                        .frame(width: geo.size.width * min(progress, 1.0))
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
            .frame(maxWidth: 120)

            // Count label
            Text("\(completedCount)/\(activeTasks.count) tasks")
                .font(.caption2)
                .foregroundStyle(.secondary)

            // Active task spinner
            if let active = inProgressTask {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.mini)
                    Text(active.activeForm ?? active.subject)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Completion indicator
            if completedCount == activeTasks.count && !activeTasks.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("All tasks complete")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}
