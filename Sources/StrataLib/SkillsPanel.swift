import SwiftUI

// MARK: - Tab Enum

enum SkillsTab: String, CaseIterable {
    case installed = "Installed"
    case catalog = "Catalog"
}

// MARK: - Skills Panel

struct SkillsPanel: View {
    let skills: [Skill]
    let onInvoke: (Skill, String) -> Void
    let onInstall: (CatalogSkill) -> Void
    let onUninstall: (CatalogSkill) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedSkill: Skill? = nil
    @State private var selectedCatalogSkill: CatalogSkill? = nil
    @State private var argumentText: String = ""
    @State private var selectedTab: SkillsTab = .installed
    @State private var showUninstallConfirm: Bool = false
    @State private var isLoadingDetail: Bool = false
    @State private var searchTask: Task<Void, Never>? = nil

    private let catalog = SkillCatalog.shared

    // MARK: - Installed tab filtering

    private var filteredSkills: [Skill] {
        let invocable = skills.filter(\.userInvocable)
        guard !searchText.isEmpty else { return invocable }
        let query = searchText.lowercased()
        return invocable.filter { skill in
            skill.name.lowercased().contains(query) ||
            skill.description.lowercased().contains(query)
        }
    }

    private var projectSkills: [Skill] {
        filteredSkills.filter { $0.source == .project }
    }

    private var personalSkills: [Skill] {
        filteredSkills.filter { $0.source == .personal }
    }

    // MARK: - Catalog: browse vs search mode

    private var isCatalogSearching: Bool {
        selectedTab == .catalog && !searchText.isEmpty
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // ── Sidebar ──
            VStack(alignment: .leading, spacing: 0) {
                Text("Skills")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)

                // Tab picker
                Picker("", selection: $selectedTab) {
                    ForEach(SkillsTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 8)

                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(
                        selectedTab == .catalog
                            ? "Search skills.sh\u{2026}"
                            : "Search skills\u{2026}",
                        text: $searchText
                    )
                    .textFieldStyle(.plain)

                    if catalog.isSearching {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 12)

                // List
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        if selectedTab == .installed {
                            installedList
                        } else {
                            catalogList
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

                if selectedTab == .installed {
                    installedDetail
                } else {
                    catalogDetail
                }
            }
        }
        .frame(width: 680, height: 480)
        .task {
            await catalog.fetchFeatured()
            catalog.markInstalled(localSkills: skills)
        }
        .onAppear {
            if selectedTab == .installed, selectedSkill == nil {
                selectedSkill = projectSkills.first ?? personalSkills.first
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            searchText = ""
            searchTask?.cancel()
            if newTab == .installed {
                selectedCatalogSkill = nil
                selectedSkill = projectSkills.first ?? personalSkills.first
            } else {
                selectedSkill = nil
                selectedCatalogSkill = catalog.sources.first?.skills.first
            }
        }
        .onChange(of: searchText) { _, newText in
            if selectedTab == .installed {
                let visible = filteredSkills
                if let sel = selectedSkill, !visible.contains(sel) {
                    selectedSkill = visible.first
                }
            } else {
                // Debounced catalog search
                searchTask?.cancel()
                if newText.isEmpty {
                    selectedCatalogSkill = catalog.sources.first?.skills.first
                } else {
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        guard !Task.isCancelled else { return }
                        await catalog.search(query: newText)
                        catalog.markInstalled(localSkills: skills)
                        await MainActor.run {
                            selectedCatalogSkill = catalog.searchResults.first
                        }
                    }
                }
            }
        }
        .onChange(of: selectedCatalogSkill) { _, skill in
            guard let skill, skill.instructions == nil else { return }
            isLoadingDetail = true
            Task {
                let detail = await catalog.fetchDetail(for: skill)
                await MainActor.run {
                    if var current = selectedCatalogSkill, current.id == skill.id {
                        current.description = detail?.description
                        current.instructions = detail?.instructions
                        selectedCatalogSkill = current
                    }
                    isLoadingDetail = false
                }
            }
        }
        .alert(
            "Uninstall Skill",
            isPresented: $showUninstallConfirm,
            presenting: selectedCatalogSkill
        ) { skill in
            Button("Cancel", role: .cancel) {}
            Button("Uninstall", role: .destructive) {
                onUninstall(skill)
            }
        } message: { skill in
            Text("Remove \(skill.name)? This deletes ~/.claude/skills/\(skill.name)/")
        }
    }

    // MARK: - Installed Tab

    @ViewBuilder
    private var installedList: some View {
        if !projectSkills.isEmpty {
            sectionLabel("Project Skills")
            ForEach(projectSkills) { skill in
                skillRow(skill)
            }
        }

        if !personalSkills.isEmpty {
            sectionLabel("Personal Skills")
            ForEach(personalSkills) { skill in
                skillRow(skill)
            }
        }

        if filteredSkills.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.title)
                    .foregroundStyle(.tertiary)
                Text("No Skills Found")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(searchText.isEmpty
                     ? "Install skills from the Catalog tab or add them to ~/.claude/skills/"
                     : "No skills match \"\(searchText)\"")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        }
    }

    @ViewBuilder
    private var installedDetail: some View {
        if let skill = selectedSkill {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(spacing: 12) {
                        Image(systemName: "wand.and.stars")
                            .font(.title2)
                            .foregroundStyle(.orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(skill.name)
                                .font(.title2)
                                .fontWeight(.bold)

                            Label(
                                skill.source == .personal ? "Personal" : "Project",
                                systemImage: skill.source == .personal
                                    ? "person.fill" : "folder.fill"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: Capsule())
                        }
                    }

                    // Description
                    if !skill.description.isEmpty {
                        Text(skill.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    // Invoke
                    VStack(alignment: .leading, spacing: 8) {
                        if let hint = skill.argumentHint {
                            TextField(hint, text: $argumentText)
                                .textFieldStyle(.roundedBorder)
                                .font(.callout)
                        }

                        Button {
                            onInvoke(skill, argumentText)
                            argumentText = ""
                            dismiss()
                        } label: {
                            Label("Run /\(skill.name)", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }

                    Divider()

                    // Instructions preview
                    if !skill.instructions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Instructions")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text(skill.instructions)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        } else {
            emptyState
        }
    }

    // MARK: - Catalog Tab

    @ViewBuilder
    private var catalogList: some View {
        if catalog.isLoading && catalog.sources.isEmpty {
            VStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading catalog\u{2026}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else if let error = catalog.error, catalog.sources.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.title)
                    .foregroundStyle(.tertiary)
                Text("Failed to Load")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else if isCatalogSearching {
            // Search results from skills.sh
            if catalog.searchResults.isEmpty && !catalog.isSearching {
                VStack(spacing: 8) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text("No Results")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("No skills match \"\(searchText)\"")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                sectionLabel("Search Results")
                ForEach(catalog.searchResults) { skill in
                    catalogSkillRow(skill)
                }
            }
        } else {
            // Browse mode — grouped by source
            ForEach(catalog.sources) { source in
                sectionLabel(source.displayName)
                ForEach(source.skills) { skill in
                    catalogSkillRow(skill)
                }
            }
        }
    }

    @ViewBuilder
    private var catalogDetail: some View {
        if let skill = selectedCatalogSkill {
            if isLoadingDetail && skill.instructions == nil {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading skill details\u{2026}")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        HStack(spacing: 12) {
                            Image(systemName: "wand.and.stars")
                                .font(.title2)
                                .foregroundStyle(.orange)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(skill.name)
                                    .font(.title2)
                                    .fontWeight(.bold)

                                HStack(spacing: 6) {
                                    let sourceName = SkillCatalog.sourceDisplayNames[skill.source]
                                        ?? skill.source
                                    Label(sourceName, systemImage: "globe")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.quaternary, in: Capsule())

                                    if skill.isInstalled {
                                        Label("Installed", systemImage: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(
                                                Color.green.opacity(0.1),
                                                in: Capsule()
                                            )
                                    }

                                    if let count = skill.installs {
                                        Label(
                                            formatInstalls(count),
                                            systemImage: "arrow.down.circle"
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.quaternary, in: Capsule())
                                    }
                                }
                            }
                        }

                        // Description
                        if let desc = skill.description, !desc.isEmpty {
                            Text(desc)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        // Install / Uninstall
                        VStack(alignment: .leading, spacing: 8) {
                            if skill.isInstalled {
                                HStack(spacing: 12) {
                                    Button {
                                        if let local = skills.first(where: { $0.name == skill.name }) {
                                            onInvoke(local, "")
                                            dismiss()
                                        }
                                    } label: {
                                        Label("Run /\(skill.name)", systemImage: "play.fill")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.large)

                                    Button {
                                        showUninstallConfirm = true
                                    } label: {
                                        Label("Uninstall", systemImage: "trash")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.large)
                                    .foregroundStyle(.red)
                                }
                            } else {
                                Button {
                                    onInstall(skill)
                                    selectedTab = .installed
                                } label: {
                                    Label("Install Skill", systemImage: "arrow.down.circle.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                            }
                        }

                        Divider()

                        // Instructions preview
                        if let instr = skill.instructions, !instr.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Instructions")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text(instr)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(20)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
        } else {
            emptyState
        }
    }

    // MARK: - Shared Subviews

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(selectedTab == .installed ? "Select a skill" : "Browse the catalog")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(selectedTab == .installed
                 ? "Choose a skill from the sidebar to view details and run it."
                 : "Select a skill from the catalog to preview and install it.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    @ViewBuilder
    private func skillRow(_ skill: Skill) -> some View {
        Button {
            selectedSkill = skill
            argumentText = ""
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.caption)
                    .foregroundStyle(selectedSkill == skill ? .white : .orange)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.name)
                        .font(.callout)
                        .foregroundStyle(selectedSkill == skill ? .white : .primary)

                    if !skill.description.isEmpty {
                        Text(skill.description)
                            .font(.caption2)
                            .foregroundStyle(
                                selectedSkill == skill
                                    ? .white.opacity(0.7) : .secondary
                            )
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                selectedSkill == skill ? Color.orange : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func catalogSkillRow(_ skill: CatalogSkill) -> some View {
        Button {
            selectedCatalogSkill = skill
        } label: {
            HStack(spacing: 8) {
                Image(systemName: skill.isInstalled ? "checkmark.circle.fill" : "wand.and.stars")
                    .font(.caption)
                    .foregroundStyle(
                        selectedCatalogSkill == skill
                            ? .white
                            : (skill.isInstalled ? .green : .orange)
                    )
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(skill.name)
                            .font(.callout)
                            .foregroundStyle(selectedCatalogSkill == skill ? .white : .primary)

                        if let count = skill.installs {
                            Text(formatInstalls(count))
                                .font(.caption2)
                                .foregroundStyle(
                                    selectedCatalogSkill == skill
                                        ? Color.white.opacity(0.5) : Color.secondary.opacity(0.6)
                                )
                        }
                    }

                    if let desc = skill.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption2)
                            .foregroundStyle(
                                selectedCatalogSkill == skill
                                    ? .white.opacity(0.7) : .secondary
                            )
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                selectedCatalogSkill == skill ? Color.orange : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func formatInstalls(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }
}
