import SwiftUI

// MARK: - FocusedValue for menu bar toggle

struct AgentPanelToggleKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var agentPanelToggle: Binding<Bool>? {
        get { self[AgentPanelToggleKey.self] }
        set { self[AgentPanelToggleKey.self] = newValue }
    }
}

/// Panel for browsing, creating, and editing custom agents.
struct AgentPanel: View {
    @State private var agentManager = AgentManager.shared
    @State private var selectedAgent: CustomAgent?
    @State private var isEditing = false
    @State private var isCreatingNew = false
    @State private var searchText = ""

    var onRunAgent: ((CustomAgent, String) -> Void)?  // (agent, initialPrompt)

    private var filteredAgents: [CustomAgent] {
        if searchText.isEmpty {
            return agentManager.agents
        }
        return agentManager.agents.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            // Agent list
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search agents...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                // Agent list
                List(filteredAgents, selection: $selectedAgent) { agent in
                    AgentListRow(agent: agent, isSelected: selectedAgent?.id == agent.id)
                        .tag(agent)
                }
                .listStyle(.sidebar)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isCreatingNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Create new agent")
                }
            }
        } detail: {
            if let agent = selectedAgent {
                AgentDetailView(
                    agent: agent,
                    isBuiltIn: agentManager.isBuiltIn(agent),
                    onEdit: {
                        isEditing = true
                    },
                    onRun: { prompt in
                        onRunAgent?(agent, prompt)
                    },
                    onDuplicate: {
                        let copy = agentManager.duplicate(agent)
                        selectedAgent = copy
                    },
                    onDelete: {
                        agentManager.delete(agent)
                        selectedAgent = nil
                    },
                    onReset: {
                        agentManager.resetToDefault(agent)
                        // Refresh selection
                        if let updated = agentManager.agents.first(where: { $0.name == agent.name }) {
                            selectedAgent = updated
                        }
                    }
                )
            } else {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "Select an Agent",
                        systemImage: "person.crop.rectangle.stack",
                        description: Text("Choose an agent from the list or create your own.")
                    )

                    Button {
                        isCreatingNew = true
                    } label: {
                        Label("Create New Agent", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            if let agent = selectedAgent {
                AgentEditorSheet(
                    agent: agent,
                    isNew: false,
                    onSave: { updated in
                        agentManager.save(updated)
                        selectedAgent = updated
                        isEditing = false
                    },
                    onCancel: {
                        isEditing = false
                    }
                )
            }
        }
        .sheet(isPresented: $isCreatingNew) {
            AgentEditorSheet(
                agent: CustomAgent(
                    name: "New Agent",
                    description: "",
                    icon: "person.circle",
                    permissionMode: "default",
                    systemPrompt: "",
                    allowedTools: [.read, .glob, .grep]
                ),
                isNew: true,
                onSave: { newAgent in
                    agentManager.save(newAgent)
                    selectedAgent = newAgent
                    isCreatingNew = false
                },
                onCancel: {
                    isCreatingNew = false
                }
            )
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}

// MARK: - Agent List Row

private struct AgentListRow: View {
    let agent: CustomAgent
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: agent.icon)
                .font(.title3)
                .foregroundStyle(isSelected ? .white : .orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(agent.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Agent Detail View

private struct AgentDetailView: View {
    let agent: CustomAgent
    let isBuiltIn: Bool
    let onEdit: () -> Void
    let onRun: (String) -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onReset: () -> Void

    @State private var promptText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 16) {
                    Image(systemName: agent.icon)
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(agent.name)
                            .font(.title)
                            .fontWeight(.bold)

                        Text(agent.description)
                            .font(.body)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Label(permissionLabel, systemImage: permissionIcon)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let model = agent.model {
                                Label(model, systemImage: "cpu")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 4)
                    }

                    Spacer()
                }
                .padding(.bottom, 8)

                Divider()

                // Run Agent section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Run Agent")
                        .font(.headline)

                    Text("Enter your task or question for this agent:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField(placeholderForAgent, text: $promptText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .lineLimit(3...6)

                    Button {
                        onRun(promptText)
                    } label: {
                        Label("Run \(agent.name)", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Divider()

                // System Prompt section
                VStack(alignment: .leading, spacing: 8) {
                    Text("System Prompt")
                        .font(.headline)

                    Text(agent.systemPrompt)
                        .font(.system(.body, design: .monospaced))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Allowed Tools section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Allowed Tools")
                        .font(.headline)

                    FlowLayout(spacing: 8) {
                        ForEach(Array(agent.allowedTools).sorted { $0.rawValue < $1.rawValue }) { tool in
                            HStack(spacing: 4) {
                                Image(systemName: tool.icon)
                                Text(tool.displayName)
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }

                Divider()

                // Actions
                HStack {
                    Button("Edit") {
                        onEdit()
                    }

                    Button("Duplicate") {
                        onDuplicate()
                    }

                    if isBuiltIn {
                        Button("Reset to Default") {
                            onReset()
                        }
                    } else {
                        Button("Delete", role: .destructive) {
                            onDelete()
                        }
                    }

                    Spacer()
                }
            }
            .padding(24)
        }
    }

    private var permissionLabel: String {
        switch agent.permissionMode {
        case "plan": return "Read-only"
        case "acceptEdits": return "Auto-accept edits"
        case "bypassPermissions": return "Full autonomy"
        default: return "Ask permission"
        }
    }

    private var permissionIcon: String {
        switch agent.permissionMode {
        case "plan": return "eye"
        case "acceptEdits": return "bolt"
        case "bypassPermissions": return "bolt.shield"
        default: return "hand.raised"
        }
    }

    private var placeholderForAgent: String {
        switch agent.name {
        case "Code Reviewer": return "e.g., Review src/Session.swift for bugs"
        case "Test Writer": return "e.g., Write tests for the UserService class"
        case "Doc Generator": return "e.g., Document the API endpoints in this project"
        case "Bug Hunter": return "e.g., Find security issues in the auth module"
        case "Refactorer": return "e.g., Refactor the database queries for clarity"
        case "Explainer": return "e.g., Explain how the caching system works"
        default: return "e.g., Describe what you want this agent to do..."
        }
    }
}

// MARK: - Agent Editor Sheet

private struct AgentEditorSheet: View {
    @State var agent: CustomAgent
    let isNew: Bool
    let onSave: (CustomAgent) -> Void
    let onCancel: () -> Void

    @State private var showIconPicker = false

    private let commonIcons = [
        "person.circle", "person.circle.fill",
        "eye.circle", "eye.circle.fill",
        "checkmark.shield", "checkmark.shield.fill",
        "doc.text", "doc.text.fill",
        "ladybug", "ladybug.fill",
        "arrow.triangle.2.circlepath",
        "lightbulb", "lightbulb.fill",
        "hammer", "hammer.fill",
        "wrench", "wrench.fill",
        "gearshape", "gearshape.fill",
        "cpu", "cpu.fill",
        "terminal", "terminal.fill",
        "bolt", "bolt.fill",
        "magnifyingglass.circle", "magnifyingglass.circle.fill",
        "brain", "brain.head.profile",
        "sparkles", "wand.and.stars"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isNew ? "Create Agent" : "Edit Agent")
                    .font(.headline)
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.escape, modifiers: [])
                Button("Save") { onSave(agent) }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(agent.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Basic Info") {
                    HStack {
                        // Icon picker
                        Button {
                            showIconPicker.toggle()
                        } label: {
                            Image(systemName: agent.icon)
                                .font(.title)
                                .foregroundStyle(.orange)
                                .frame(width: 44, height: 44)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showIconPicker) {
                            IconPickerView(selectedIcon: $agent.icon, icons: commonIcons)
                        }

                        TextField("Name", text: $agent.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    TextField("Description", text: $agent.description)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Behavior") {
                    Picker("Permission Mode", selection: $agent.permissionMode) {
                        Text("Ask Permission").tag("default")
                        Text("Auto-accept Edits").tag("acceptEdits")
                        Text("Read-only (Plan Mode)").tag("plan")
                        Text("Full Autonomy").tag("bypassPermissions")
                    }

                    Picker("Model Override", selection: Binding(
                        get: { agent.model ?? "" },
                        set: { agent.model = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("Use Session Default").tag("")
                        ForEach(ClaudeModel.allCases) { model in
                            Text(model.displayName).tag(model.rawValue)
                        }
                    }
                }

                Section("System Prompt") {
                    TextEditor(text: $agent.systemPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 150)
                }

                Section("Allowed Tools") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(CustomAgent.AgentTool.allCases) { tool in
                            ToolToggleButton(
                                tool: tool,
                                isEnabled: agent.allowedTools.contains(tool),
                                onToggle: {
                                    if agent.allowedTools.contains(tool) {
                                        agent.allowedTools.remove(tool)
                                    } else {
                                        agent.allowedTools.insert(tool)
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 550, height: 650)
    }
}

// MARK: - Tool Toggle Button

private struct ToolToggleButton: View {
    let tool: CustomAgent.AgentTool
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack {
                Image(systemName: tool.icon)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.displayName)
                        .font(.callout.weight(.medium))
                    Text(tool.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isEnabled ? .green : .secondary)
            }
            .padding(10)
            .background(isEnabled ? Color.green.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isEnabled ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Icon Picker View

private struct IconPickerView: View {
    @Binding var selectedIcon: String
    let icons: [String]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(44)), count: 6), spacing: 8) {
            ForEach(icons, id: \.self) { icon in
                Button {
                    selectedIcon = icon
                } label: {
                    Image(systemName: icon)
                        .font(.title2)
                        .frame(width: 40, height: 40)
                        .background(selectedIcon == icon ? Color.orange.opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, spacing: spacing, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, spacing: spacing, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in width: CGFloat, spacing: CGFloat, subviews: Subviews) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: width, height: y + rowHeight)
        }
    }
}
