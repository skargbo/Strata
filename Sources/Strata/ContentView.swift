import SwiftUI

struct ContentView: View {
    @Bindable var manager: SessionManager
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var isFocusedMode: Bool = false
    @State private var preFocusVisibility: NavigationSplitViewVisibility = .automatic
    @State private var showCommandPalette: Bool = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(manager: manager)
        } detail: {
            if let anySession = manager.selectedSession {
                Group {
                    switch anySession {
                    case .claude(let session):
                        SessionView(session: session, appearanceMode: $manager.appearanceMode)
                            .navigationTitle(session.name)
                            .navigationSubtitle(session.workingDirectory.abbreviatingHome)
                    case .terminal(let session):
                        TerminalSessionView(session: session)
                    }
                }
                .id(anySession.id)
                .frame(maxWidth: isFocusedMode ? 1000 : .infinity)
            } else {
                EmptySessionView {
                    manager.newSession()
                }
                .navigationTitle("Strata")
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showCommandPalette = true
                } label: {
                    Image(systemName: "wrench.and.screwdriver")
                }
                .help("Command Palette (⌘K)")
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .focusedSceneValue(\.focusedModeToggle, $isFocusedMode)
        .focusedSceneValue(\.commandPaletteToggle, $showCommandPalette)
        .onChange(of: isFocusedMode) { _, focused in
            withAnimation(.easeInOut(duration: 0.25)) {
                if focused {
                    preFocusVisibility = columnVisibility
                    columnVisibility = .detailOnly
                } else {
                    columnVisibility = preFocusVisibility
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if isFocusedMode {
                Button {
                    isFocusedMode = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sidebar.leading")
                        Text("Exit Focus")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .padding(.leading, 12)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .overlay {
            if showCommandPalette {
                CommandPaletteOverlay(
                    isPresented: $showCommandPalette,
                    manager: manager,
                    onAction: { action in
                        executeCommandPaletteAction(action)
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: showCommandPalette)
    }

    private func executeCommandPaletteAction(_ action: CommandPaletteAction) {
        showCommandPalette = false
        switch action {
        case .newSession:
            manager.newSession()
        case .newTerminal:
            manager.newTerminalSession()
        case .toggleFocusMode:
            isFocusedMode.toggle()
        case .toggleChangesPanel:
            NotificationCenter.default.post(name: .toggleDiffPanel, object: nil)
        case .openSettings:
            NotificationCenter.default.post(name: .toggleSettings, object: nil)
        case .compactConversation:
            if case .claude(let session) = manager.selectedSession {
                session.compact()
            }
        case .clearConversation:
            if case .claude(let session) = manager.selectedSession {
                session.clear()
            }
        case .initProject:
            if case .claude(let session) = manager.selectedSession {
                session.send("/init")
            }
        case .reviewCode:
            if case .claude(let session) = manager.selectedSession {
                session.send("/review")
            }
        case .runDoctor:
            if case .claude(let session) = manager.selectedSession {
                session.send("/doctor")
            }
        case .editMemory:
            NotificationCenter.default.post(name: .toggleMemoryViewer, object: nil)
        case .openSkillsPanel:
            NotificationCenter.default.post(name: .toggleSkillsPanel, object: nil)
        case .selectSession(let id):
            manager.select(id)
        }
    }
}

// MARK: - FocusedValue for Focus Mode

struct FocusedModeToggleKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var focusedModeToggle: Binding<Bool>? {
        get { self[FocusedModeToggleKey.self] }
        set { self[FocusedModeToggleKey.self] = newValue }
    }
}
