import SwiftUI

struct SidebarView: View {
    @Bindable var manager: SessionManager

    var body: some View {
        List(selection: $manager.selectedSessionID) {
            Section("Sessions") {
                ForEach(manager.sessions) { session in
                    SessionRow(session: session)
                        .tag(session.id)
                        .contextMenu {
                            Button("Close Session") {
                                manager.closeSession(session)
                            }
                        }
                }
                .onDelete { indexSet in
                    let sessionsToDelete = indexSet.map { manager.sessions[$0] }
                    for session in sessionsToDelete {
                        manager.closeSession(session)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                SidebarNewSessionButton(label: "New Claude Session", icon: "plus.circle.fill", style: .primary) {
                    manager.newSession()
                }

                SidebarNewSessionButton(label: "New Terminal", icon: "terminal.fill", style: .secondary) {
                    manager.newTerminalSession()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }
}

struct SessionRow: View {
    let session: AnySession
    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        HStack(spacing: 8) {
            // Session type icon
            Group {
                switch session {
                case .claude:
                    Image(systemName: "square.stack.3d.down.dottedline")
                        .foregroundStyle(session.isActive ? Color.orange : Color.gray)
                case .terminal:
                    Image(systemName: "terminal.fill")
                        .foregroundStyle(session.isActive ? Color.green : Color.gray)
                }
            }
            .font(.system(size: 12))
            .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.system(.body, design: .default))
                    .lineLimit(1)

                Text(session.workingDirectory.abbreviatingHome)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            Spacer(minLength: 0)

            // Active indicator
            if session.isActive {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .opacity(pulseOpacity)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true)
                        ) {
                            pulseOpacity = 0.3
                        }
                    }
                    .onDisappear {
                        pulseOpacity = 1.0
                    }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Sidebar New Session Button (with hover)

private struct SidebarNewSessionButton: View {
    enum Style { case primary, secondary }

    let label: String
    let icon: String
    let style: Style
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(style == .primary ? .callout.weight(.medium) : .callout)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(style == .primary ? .white : (isHovered ? .primary : .secondary))
        .padding(.vertical, style == .primary ? 8 : 6)
        .background(
            style == .primary
                ? AnyShapeStyle(Color.orange.opacity(isHovered ? 0.85 : 1.0))
                : AnyShapeStyle(Color.clear),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}
