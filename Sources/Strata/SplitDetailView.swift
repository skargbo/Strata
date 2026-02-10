import SwiftUI

/// A horizontal split container that shows two session panes side by side.
struct SplitDetailView: View {
    @Bindable var manager: SessionManager
    @Binding var appearanceMode: AppearanceMode

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let dividerWidth: CGFloat = 8
            let usableWidth = totalWidth - dividerWidth
            let rawLeft = usableWidth * manager.splitRatio + dragOffset
            let leftWidth = min(max(rawLeft, 250), usableWidth - 250)
            let rightWidth = usableWidth - leftWidth

            HStack(spacing: 0) {
                // Left pane: primary session
                leftPane
                    .frame(width: leftWidth)
                    .clipped()

                // Divider
                splitDivider(totalWidth: totalWidth)
                    .frame(width: dividerWidth)

                // Right pane: split session
                rightPane
                    .frame(width: rightWidth)
                    .clipped()
            }
        }
    }

    // MARK: - Left Pane

    @ViewBuilder
    private var leftPane: some View {
        if let anySession = manager.selectedSession {
            sessionContent(for: anySession, hideToolbar: false)
                .id(anySession.id)
        } else {
            EmptySessionView { manager.newSession() }
        }
    }

    // MARK: - Right Pane

    @ViewBuilder
    private var rightPane: some View {
        if let anySession = manager.splitSession {
            sessionContent(for: anySession, hideToolbar: true)
                .id(anySession.id)
                .overlay(alignment: .topTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            manager.exitSplitScreen()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .help("Exit Split Screen")
                }
        } else {
            SplitSessionPicker(manager: manager)
        }
    }

    // MARK: - Session Content

    @ViewBuilder
    private func sessionContent(for anySession: AnySession, hideToolbar: Bool) -> some View {
        switch anySession {
        case .claude(let session):
            SessionView(session: session, appearanceMode: $appearanceMode, hideToolbar: hideToolbar)
        case .terminal(let session):
            TerminalSessionView(session: session)
        }
    }

    // MARK: - Divider

    private func splitDivider(totalWidth: CGFloat) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .overlay {
                Rectangle()
                    .fill(isDragging ? Color.orange : Color.primary.opacity(0.15))
                    .frame(width: isDragging ? 3 : 1)
            }
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        dragOffset = value.translation.width
                    }
                    .onEnded { _ in
                        isDragging = false
                        let usableWidth = totalWidth - 8
                        let rawLeft = usableWidth * manager.splitRatio + dragOffset
                        let clampedLeft = min(max(rawLeft, 250), usableWidth - 250)
                        manager.splitRatio = clampedLeft / usableWidth
                        dragOffset = 0
                        manager.saveManifest()
                    }
            )
    }
}

// MARK: - Split Session Picker

/// Shown in the right pane when no split session is selected.
struct SplitSessionPicker: View {
    @Bindable var manager: SessionManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.split.2x1")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("Choose a session for this pane")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Button {
                    let workDir = manager.selectedSession?.workingDirectory ?? NSHomeDirectory()
                    let terminal = TerminalSession(name: nil, workingDirectory: workDir)
                    manager.sessions.append(.terminal(terminal))
                    manager.splitSessionID = terminal.id
                    manager.saveManifest()
                } label: {
                    Label("New Terminal", systemImage: "terminal.fill")
                        .frame(maxWidth: 250)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Divider().padding(.vertical, 8)

                Text("Or select an existing session:")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                let available = manager.sessions.filter { $0.id != manager.selectedSessionID }
                ForEach(available) { session in
                    Button {
                        manager.selectSplitSession(session.id)
                    } label: {
                        HStack(spacing: 8) {
                            sessionIcon(for: session)
                            VStack(alignment: .leading) {
                                Text(session.name)
                                    .lineLimit(1)
                                Text(session.workingDirectory.abbreviatingHome)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: 250)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func sessionIcon(for session: AnySession) -> some View {
        switch session {
        case .claude:
            Image(systemName: "square.stack.3d.down.dottedline")
                .foregroundStyle(.orange)
        case .terminal:
            Image(systemName: "terminal.fill")
                .foregroundStyle(.green)
        }
    }
}
