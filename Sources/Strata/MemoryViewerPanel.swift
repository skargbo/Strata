import SwiftUI

// MARK: - Memory Viewer Panel

struct MemoryViewerPanel: View {
    let workingDirectory: String
    @Environment(\.dismiss) private var dismiss
    @State private var memoryFiles: [MemoryFile] = []
    @State private var selectedFile: MemoryFile? = nil
    @State private var editedContent: String = ""
    @State private var showCreateRuleAlert: Bool = false
    @State private var newRuleName: String = ""
    @State private var showDeleteConfirm: Bool = false
    @State private var saveError: String? = nil

    // MARK: - Computed Properties

    private var userFiles: [MemoryFile] {
        memoryFiles.filter { $0.level == .user }
    }

    private var projectFiles: [MemoryFile] {
        memoryFiles.filter { $0.level == .project }
    }

    private var rulesFiles: [MemoryFile] {
        memoryFiles.filter { $0.level == .rules }
    }

    private var localFiles: [MemoryFile] {
        memoryFiles.filter { $0.level == .local }
    }

    private var isModified: Bool {
        guard let file = selectedFile else { return false }
        return editedContent != file.content
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // ── Sidebar ──
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("Memory")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Button {
                        refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh")
                }
                .padding(.bottom, 12)

                // File list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        // User section
                        sectionHeader("User")
                        ForEach(userFiles) { file in
                            fileRow(file)
                        }

                        // Project section
                        sectionHeader("Project")
                        ForEach(projectFiles) { file in
                            fileRow(file)
                        }

                        // Rules section
                        sectionHeader("Rules")
                        ForEach(rulesFiles) { file in
                            fileRow(file)
                        }
                        addRuleButton

                        // Local section
                        sectionHeader("Local")
                        ForEach(localFiles) { file in
                            fileRow(file)
                        }
                    }
                }

                Spacer()
            }
            .frame(width: 220)
            .padding(20)
            .background(Color(nsColor: .controlBackgroundColor))

            // ── Detail pane ──
            VStack(alignment: .leading, spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.top, 12)
                .padding(.trailing, 16)

                if let file = selectedFile {
                    detailView(for: file)
                } else {
                    emptyState
                }
            }
        }
        .frame(width: 680, height: 480)
        .onAppear {
            refresh()
        }
        .alert("Create Rule", isPresented: $showCreateRuleAlert) {
            TextField("Rule name", text: $newRuleName)
            Button("Cancel", role: .cancel) {
                newRuleName = ""
            }
            Button("Create") {
                createRule()
            }
            .disabled(newRuleName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text("Enter a name for the new rule file.")
        }
        .alert("Delete Rule", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSelectedRule()
            }
        } message: {
            if let file = selectedFile {
                Text("Delete \"\(file.name).md\"? This cannot be undone.")
            }
        }
    }

    // MARK: - Sidebar Components

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    @ViewBuilder
    private func fileRow(_ file: MemoryFile) -> some View {
        let isSelected = selectedFile?.id == file.id

        Button {
            selectFile(file)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: file.level.icon)
                    .foregroundStyle(file.exists ? .primary : .tertiary)

                Text(file.name)
                    .lineLimit(1)
                    .foregroundStyle(file.exists ? .primary : .secondary)

                Spacer()

                if !file.exists {
                    Text("New")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.2), in: Capsule())
                        .foregroundStyle(.orange)
                }

                if isSelected && isModified {
                    Circle()
                        .fill(.yellow)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var addRuleButton: some View {
        Button {
            showCreateRuleAlert = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.secondary)
                Text("Add Rule")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail View

    @ViewBuilder
    private func detailView(for file: MemoryFile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center) {
                Image(systemName: file.level.icon)
                    .font(.title2)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(file.name)
                            .font(.headline)

                        if !file.exists {
                            Text("New")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.2), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }

                    Text(file.relativePath(from: workingDirectory))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if file.level == .rules && file.exists {
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete rule")
                }

                Button {
                    save()
                } label: {
                    HStack(spacing: 4) {
                        if isModified {
                            Circle()
                                .fill(.yellow)
                                .frame(width: 6, height: 6)
                        }
                        Text("Save")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isModified ? Color.accentColor : Color.secondary.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(isModified ? .white : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!isModified)
                .keyboardShortcut("s", modifiers: .command)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)

            Divider()

            // Level description
            Text(file.level.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Editor
            TextEditor(text: $editedContent)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            // Error message
            if let error = saveError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            // Footer
            HStack {
                Text("Tip: Use @path/to/file to import other files")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "brain")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Select a memory file")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Claude's memory files store project context and instructions.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Actions

    private func refresh() {
        memoryFiles = MemoryScanner.scan(workingDirectory: workingDirectory)
        // Re-select the same file if it still exists
        if let current = selectedFile {
            selectedFile = memoryFiles.first { $0.id == current.id }
            editedContent = selectedFile?.content ?? ""
        } else {
            // Auto-select project memory if nothing selected
            selectedFile = projectFiles.first
            editedContent = selectedFile?.content ?? ""
        }
    }

    private func selectFile(_ file: MemoryFile) {
        // Warn about unsaved changes? For now, just switch
        selectedFile = file
        editedContent = file.content
        saveError = nil
    }

    private func save() {
        guard var file = selectedFile else { return }
        file.content = editedContent
        file.isModified = false

        do {
            try MemoryScanner.save(file)
            file.exists = true
            // Update in list
            if let index = memoryFiles.firstIndex(where: { $0.id == file.id }) {
                memoryFiles[index] = file
            }
            selectedFile = file
            saveError = nil
        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func createRule() {
        let name = newRuleName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let newFile = MemoryScanner.createRuleFile(workingDirectory: workingDirectory, name: name)
        memoryFiles.append(newFile)
        selectFile(newFile)
        newRuleName = ""
    }

    private func deleteSelectedRule() {
        guard let file = selectedFile, file.level == .rules else { return }

        do {
            try MemoryScanner.delete(file)
            memoryFiles.removeAll { $0.id == file.id }
            selectedFile = projectFiles.first ?? userFiles.first
            editedContent = selectedFile?.content ?? ""
        } catch {
            saveError = "Failed to delete: \(error.localizedDescription)"
        }
    }
}

// MARK: - FocusedValue Key

struct MemoryViewerToggleKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var memoryViewerToggle: Binding<Bool>? {
        get { self[MemoryViewerToggleKey.self] }
        set { self[MemoryViewerToggleKey.self] = newValue }
    }
}
