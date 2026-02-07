import AppKit
import SwiftUI

/// Panel for managing MCP server configurations
struct MCPPanel: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mcpManager = MCPManager.shared
    @State private var selectedServer: MCPServerConfig?
    @State private var selectedPreset: MCPServerPreset?
    @State private var searchText: String = ""
    @State private var selectedTab: Tab = .myServers
    @State private var selectedCategory: MCPServerPreset.Category?
    @State private var isEditing: Bool = false
    @State private var isCreatingNew: Bool = false
    @State private var editingConfig: MCPServerConfig?

    enum Tab: String, CaseIterable {
        case myServers = "My Servers"
        case catalog = "Catalog"
    }

    var onConnect: ((MCPServerConfig) -> Void)?
    var onDisconnect: ((MCPServerConfig) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header with tabs
            HStack {
                Text("MCP Servers")
                    .font(.headline)

                Spacer()

                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content based on tab
            switch selectedTab {
            case .myServers:
                myServersView
            case .catalog:
                catalogView
            }
        }
        .frame(width: 750, height: 550)
        .sheet(isPresented: $isEditing) {
            if let config = editingConfig {
                ServerEditorSheet(
                    config: config,
                    isNew: isCreatingNew,
                    onSave: { updatedConfig in
                        if isCreatingNew {
                            mcpManager.add(updatedConfig)
                            selectedServer = updatedConfig
                        } else {
                            mcpManager.update(updatedConfig)
                            selectedServer = updatedConfig
                        }
                        isEditing = false
                        selectedTab = .myServers
                    },
                    onCancel: {
                        isEditing = false
                    }
                )
            }
        }
    }

    // MARK: - My Servers Tab

    private var myServersView: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Search
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                // New Server button
                Button {
                    editingConfig = MCPServerConfig(name: "", command: "")
                    isCreatingNew = true
                    isEditing = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                        Text("Add MCP Server")
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.top, 4)

                // Server list
                List(selection: $selectedServer) {
                    ForEach(filteredServers) { server in
                        ServerRow(
                            server: server,
                            status: mcpManager.status(for: server.id),
                            isSelected: selectedServer?.id == server.id
                        )
                        .tag(server)
                        .contextMenu {
                            serverContextMenu(for: server)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 220)
        } detail: {
            // Detail view
            if let server = selectedServer {
                ServerDetailView(
                    server: server,
                    status: mcpManager.status(for: server.id),
                    tools: mcpManager.tools(for: server.id),
                    error: mcpManager.error(for: server.id),
                    onEdit: {
                        editingConfig = server
                        isCreatingNew = false
                        isEditing = true
                    },
                    onConnect: { onConnect?(server) },
                    onDisconnect: { onDisconnect?(server) },
                    onToggleEnabled: {
                        var updated = server
                        updated.enabled.toggle()
                        mcpManager.update(updated)
                        selectedServer = updated
                    }
                )
            } else {
                ContentUnavailableView {
                    Label("No Server Selected", systemImage: "server.rack")
                } description: {
                    Text("Select an MCP server from the sidebar or add a new one.")
                }
            }
        }
    }

    // MARK: - Catalog Tab

    private var catalogView: some View {
        HSplitView {
            // Categories sidebar
            VStack(spacing: 0) {
                // Browse link
                Button {
                    NSWorkspace.shared.open(MCPCatalog.registryURL)
                } label: {
                    HStack {
                        Image(systemName: "safari")
                            .foregroundStyle(.blue)
                        Text("Browse All Servers")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                Divider()

                // Category list
                List(selection: $selectedCategory) {
                    ForEach(MCPServerPreset.Category.allCases, id: \.self) { category in
                        HStack {
                            Image(systemName: category.icon)
                                .frame(width: 20)
                                .foregroundStyle(.secondary)
                            Text(category.rawValue)
                            Spacer()
                            Text("\(MCPCatalog.servers(in: category).count)")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .tag(category as MCPServerPreset.Category?)
                    }
                }
                .listStyle(.sidebar)
            }
            .frame(width: 180)

            // Preset list
            VStack(spacing: 0) {
                // Search
                TextField("Search catalog...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                // Preset grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(filteredPresets) { preset in
                            PresetCard(
                                preset: preset,
                                isSelected: selectedPreset?.id == preset.id,
                                onSelect: { selectedPreset = preset },
                                onAdd: {
                                    var config = preset.toConfig()
                                    editingConfig = config
                                    isCreatingNew = true
                                    isEditing = true
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Helpers

    private var filteredServers: [MCPServerConfig] {
        if searchText.isEmpty {
            return mcpManager.servers
        }
        return mcpManager.servers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.command.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredPresets: [MCPServerPreset] {
        var presets: [MCPServerPreset]
        if let category = selectedCategory {
            presets = MCPCatalog.servers(in: category)
        } else {
            presets = MCPCatalog.servers
        }

        if searchText.isEmpty {
            return presets
        }
        return MCPCatalog.search(searchText).filter { preset in
            selectedCategory == nil || preset.category == selectedCategory
        }
    }

    @ViewBuilder
    private func serverContextMenu(for server: MCPServerConfig) -> some View {
        let status = mcpManager.status(for: server.id)

        if status == .running {
            Button("Disconnect") {
                onDisconnect?(server)
            }
        } else {
            Button("Connect") {
                onConnect?(server)
            }
            .disabled(!server.enabled)
        }

        Divider()

        Button("Edit...") {
            editingConfig = server
            isCreatingNew = false
            isEditing = true
        }

        Toggle("Enabled", isOn: Binding(
            get: { server.enabled },
            set: { newValue in
                var updated = server
                updated.enabled = newValue
                mcpManager.update(updated)
                if selectedServer?.id == server.id {
                    selectedServer = updated
                }
            }
        ))

        Divider()

        Button("Delete", role: .destructive) {
            if selectedServer?.id == server.id {
                selectedServer = nil
            }
            mcpManager.remove(server)
        }
    }

    private func importServers() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Import MCP server configurations"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                try mcpManager.importConfigs(from: data)
            } catch {
                print("Failed to import: \(error)")
            }
        }
    }

    private func exportServers() {
        guard let data = mcpManager.exportConfigs() else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "mcp-servers.json"
        panel.message = "Export MCP server configurations"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url)
            } catch {
                print("Failed to export: \(error)")
            }
        }
    }
}

// MARK: - Server Row

struct ServerRow: View {
    let server: MCPServerConfig
    let status: MCPServerStatus
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.name.isEmpty ? "Untitled Server" : server.name)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(server.enabled ? .primary : .secondary)

                Text(server.command)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if !server.enabled {
                Text("Disabled")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch status {
        case .stopped: return .gray
        case .starting: return .orange
        case .running: return .green
        case .error: return .red
        }
    }
}

// MARK: - Server Detail View

struct ServerDetailView: View {
    let server: MCPServerConfig
    let status: MCPServerStatus
    let tools: [MCPTool]
    let error: String?
    let onEdit: () -> Void
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onToggleEnabled: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(server.name.isEmpty ? "Untitled Server" : server.name)
                            .font(.title2)
                            .fontWeight(.semibold)

                        HStack(spacing: 6) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)
                            Text(status.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Action buttons
                    HStack(spacing: 8) {
                        Toggle("", isOn: Binding(
                            get: { server.enabled },
                            set: { _ in onToggleEnabled() }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()

                        if status == .running {
                            Button("Disconnect") {
                                onDisconnect()
                            }
                            .controlSize(.small)
                        } else {
                            Button("Connect") {
                                onConnect()
                            }
                            .controlSize(.small)
                            .buttonStyle(.borderedProminent)
                            .disabled(!server.enabled)
                        }

                        Button {
                            onEdit()
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .controlSize(.small)
                    }
                }

                Divider()

                // Error message
                if let error = error {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.callout)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }

                // Configuration section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Configuration")
                        .font(.headline)

                    configRow("Command", value: server.command)

                    if !server.args.isEmpty {
                        configRow("Arguments", value: server.args.joined(separator: " "))
                    }

                    if !server.env.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Environment")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(Array(server.env.keys.sorted()), id: \.self) { key in
                                HStack {
                                    Text(key)
                                        .font(.system(.caption, design: .monospaced))
                                    Text("=")
                                        .foregroundStyle(.secondary)
                                    Text(server.env[key] ?? "")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }

                    Toggle("Auto-start with sessions", isOn: .constant(server.autoStart))
                        .disabled(true)
                }

                // Tools section
                if !tools.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Available Tools (\(tools.count))")
                            .font(.headline)

                        ForEach(tools) { tool in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "wrench.fill")
                                    .foregroundStyle(.purple)
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tool.name)
                                        .font(.callout)
                                        .fontWeight(.medium)

                                    if let desc = tool.description {
                                        Text(desc)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
    }

    private func configRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var statusColor: Color {
        switch status {
        case .stopped: return .gray
        case .starting: return .orange
        case .running: return .green
        case .error: return .red
        }
    }
}

// MARK: - Server Editor Sheet

struct ServerEditorSheet: View {
    @State var config: MCPServerConfig
    let isNew: Bool
    let onSave: (MCPServerConfig) -> Void
    let onCancel: () -> Void

    @State private var argsText: String = ""
    @State private var envPairs: [(key: String, value: String)] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isNew ? "Add MCP Server" : "Edit MCP Server")
                    .font(.headline)
                Spacer()
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g., Postgres Database", text: $config.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Command
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Command")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g., npx", text: $config.command)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    // Arguments
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Arguments (space-separated)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g., -y @modelcontextprotocol/server-postgres", text: $argsText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    // Environment variables
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Environment Variables")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                envPairs.append(("", ""))
                            } label: {
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.green)
                            }
                            .buttonStyle(.plain)
                        }

                        ForEach(envPairs.indices, id: \.self) { index in
                            HStack(spacing: 8) {
                                TextField("KEY", text: Binding(
                                    get: { envPairs[index].key },
                                    set: { envPairs[index].key = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.caption, design: .monospaced))
                                .frame(width: 120)

                                Text("=")
                                    .foregroundStyle(.secondary)

                                TextField("value", text: Binding(
                                    get: { envPairs[index].value },
                                    set: { envPairs[index].value = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.caption, design: .monospaced))

                                Button {
                                    envPairs.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Divider()

                    // Options
                    Toggle("Enabled", isOn: $config.enabled)
                    Toggle("Auto-start with sessions", isOn: $config.autoStart)
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Button(isNew ? "Add Server" : "Save") {
                    // Convert args text to array
                    config.args = argsText.split(separator: " ").map(String.init)

                    // Convert env pairs to dictionary
                    var env: [String: String] = [:]
                    for pair in envPairs where !pair.key.isEmpty {
                        env[pair.key] = pair.value
                    }
                    config.env = env

                    onSave(config)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(config.name.isEmpty || config.command.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 480)
        .onAppear {
            argsText = config.args.joined(separator: " ")
            envPairs = config.env.map { ($0.key, $0.value) }
        }
    }
}

// MARK: - Preset Card

struct PresetCard: View {
    let preset: MCPServerPreset
    let isSelected: Bool
    let onSelect: () -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: preset.category.icon)
                    .foregroundStyle(.secondary)
                Text(preset.name)
                    .font(.headline)
                Spacer()
            }

            Text(preset.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer()

            HStack {
                if !preset.envKeys.isEmpty {
                    Label("\(preset.envKeys.count) env", systemImage: "key")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Add") {
                    onAdd()
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}
