import SwiftUI

struct ContentView: View {
    @Bindable var manager: SessionManager
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var isFocusedMode: Bool = false
    @State private var preFocusVisibility: NavigationSplitViewVisibility = .automatic

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
                            .navigationSubtitle(session.workingDirectory)
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
        .frame(minWidth: 800, minHeight: 500)
        .focusedSceneValue(\.focusedModeToggle, $isFocusedMode)
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
