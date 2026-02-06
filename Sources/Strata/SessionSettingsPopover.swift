import AppKit
import SwiftUI

/// Full-window settings modal with sidebar navigation and card-based
/// controls, matching the design proposal (mockup 06).
struct SessionSettingsPanel: View {
    @Bindable var settings: SessionSettings
    @Binding var appearanceMode: AppearanceMode
    var onPickDirectory: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Tab = .model
    @State private var showSavedFeedback: Bool = false
    @State private var showBypassWarning: Bool = false

    enum Tab: String, CaseIterable {
        case model = "Model"
        case appearance = "Appearance"
        case behavior = "Behavior"

        var icon: String {
            switch self {
            case .model: "cpu"
            case .appearance: "paintbrush"
            case .behavior: "slider.horizontal.3"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // ── Sidebar ──────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 16)

                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .frame(width: 16)
                            Text(tab.rawValue)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedTab == tab
                                ? Color.primary.opacity(0.08)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .frame(width: 180)
            .padding(24)
            .background(Color(nsColor: .controlBackgroundColor))

            // ── Content ──────────────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
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

                ScrollView {
                    Group {
                        switch selectedTab {
                        case .model:      modelContent
                        case .appearance: appearanceContent
                        case .behavior:   behaviorContent
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }

                Divider()

                // Footer — Save as Default
                HStack {
                    Button {
                        let defaults = DefaultSettingsData(
                            settings: settings.toData(),
                            appearanceMode: appearanceMode.rawValue
                        )
                        PersistenceManager.shared.saveDefaultSettings(defaults)
                        showSavedFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showSavedFeedback = false
                        }
                    } label: {
                        Label(
                            showSavedFeedback ? "Saved!" : "Save as Default",
                            systemImage: showSavedFeedback ? "checkmark.circle.fill" : "square.and.arrow.down"
                        )
                        .font(.callout)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(showSavedFeedback ? .green : .secondary)
                    .help("New sessions will use these settings")

                    Spacer()

                    Button("Done") {
                        dismiss()
                    }
                    .keyboardShortcut(.return, modifiers: [])
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 680, height: 480)
        .preferredColorScheme(appearanceMode.colorScheme)
        .alert("Enable Bypass Mode?", isPresented: $showBypassWarning) {
            Button("Enable", role: .destructive) {
                settings.permissionMode = "bypassPermissions"
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This allows Claude to execute shell commands, write files, and delete files without asking for your approval. Only use this if you fully trust the session context.")
        }
    }

    // MARK: - Model Tab

    @ViewBuilder
    private var modelContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(
                title: "Model Selection",
                subtitle: "Choose the Claude model for this session"
            )

            Divider()

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    modelCard(
                        model: .opus46,
                        description: "Most intelligent, best for agents",
                        recommended: true
                    )
                    modelCard(
                        model: .sonnet45,
                        description: "Best balance of speed and capability",
                        recommended: false
                    )
                }
                HStack(spacing: 12) {
                    modelCard(
                        model: .haiku45,
                        description: "Fastest responses, lower cost",
                        recommended: false
                    )
                    modelCard(
                        model: .opus45,
                        description: "Previous flagship model",
                        recommended: false
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func modelCard(
        model: ClaudeModel,
        description: String,
        recommended: Bool
    ) -> some View {
        let isSelected = settings.model == model

        Button {
            settings.model = model
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                if recommended {
                    Text("RECOMMENDED")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange, in: RoundedRectangle(cornerRadius: 4))
                }

                Text(model.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color.orange : Color.primary.opacity(0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Appearance Tab

    @ViewBuilder
    private var appearanceContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(
                title: "Appearance",
                subtitle: "Customize the look and feel"
            )

            Divider()

            settingsRow("Theme") {
                Picker("", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 200)
            }

            settingsRow("Accent Color") {
                HStack(spacing: 8) {
                    ForEach(SessionTheme.AccentColor.allCases) { color in
                        Button {
                            settings.theme.accentColor = color
                        } label: {
                            Circle()
                                .fill(color.color)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 2)
                                        .opacity(settings.theme.accentColor == color ? 1 : 0)
                                )
                                .shadow(
                                    color: settings.theme.accentColor == color
                                        ? color.color.opacity(0.4)
                                        : .clear,
                                    radius: 4
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            settingsRow("Font Size") {
                Picker("", selection: $settings.theme.fontSize) {
                    ForEach(SessionTheme.FontSize.allCases) { size in
                        Text(size.rawValue.capitalized).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 200)
            }

            settingsRow("Message Density") {
                Picker("", selection: $settings.theme.density) {
                    ForEach(SessionTheme.Density.allCases) { density in
                        Text(density.rawValue.capitalized).tag(density)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 200)
            }
        }
    }

    // MARK: - Behavior Tab

    @ViewBuilder
    private var behaviorContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(
                title: "Behavior",
                subtitle: "Configure session behavior"
            )

            Divider()

            settingsRow("Working Directory") {
                Button(action: onPickDirectory) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.secondary)
                        Text(settings.workingDirectory.abbreviatingHome)
                            .lineLimit(1)
                            .truncationMode(.head)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            settingsRow("Permission Mode") {
                Picker("", selection: Binding(
                    get: { settings.permissionMode },
                    set: { newValue in
                        if newValue == "bypassPermissions" {
                            showBypassWarning = true
                        } else {
                            settings.permissionMode = newValue
                        }
                    }
                )) {
                    Text("Ask Every Time").tag("default")
                    Text("Accept Edits").tag("acceptEdits")
                    Text("Plan Only (read-only)").tag("plan")
                    Text("Bypass All").tag("bypassPermissions")
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            settingsRow("Tool Cards") {
                Toggle("Expand by default", isOn: $settings.toolCardsDefaultExpanded)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            settingsRow("Notifications") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Sound when attention needed", isOn: $settings.soundNotifications)
                        .toggleStyle(.switch)
                        .controlSize(.small)

                    if settings.soundNotifications {
                        HStack {
                            Picker("", selection: $settings.notificationSound) {
                                ForEach(NotificationSound.allCases) { sound in
                                    Text(sound.rawValue).tag(sound)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()

                            Button {
                                settings.notificationSound.play()
                            } label: {
                                Image(systemName: "speaker.wave.2")
                                    .font(.callout)
                            }
                            .buttonStyle(.borderless)
                            .help("Preview sound")
                        }
                    }
                }
            }

            settingsRow("System Prompt") {
                VStack(alignment: .leading, spacing: 4) {
                    TextEditor(text: $settings.customSystemPrompt)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 80)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(.quaternary, lineWidth: 1)
                        )

                    Text("Appended to the default system prompt.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func settingsRow(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            content()
        }
    }

}

// MARK: - FocusedValue for menu bar shortcut

struct SettingsToggleKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var settingsToggle: Binding<Bool>? {
        get { self[SettingsToggleKey.self] }
        set { self[SettingsToggleKey.self] = newValue }
    }
}
