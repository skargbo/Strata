import SwiftUI

struct SidebarView: View {
    @Bindable var manager: SessionManager
    @State private var showNewGroupAlert = false
    @State private var newGroupName = ""

    private var sortedGroups: [SessionGroup] {
        manager.groups.sorted(by: { $0.order < $1.order })
    }

    private var ungroupedSessions: [AnySession] {
        manager.sessions.filter { manager.sessionGroupMap[$0.id] == nil }
    }

    var body: some View {
        List(selection: $manager.selectedSessionID) {
            // Groups with their sessions
            ForEach(sortedGroups) { group in
                DisclosureGroup(isExpanded: Binding(
                    get: { group.isExpanded },
                    set: { group.isExpanded = $0; manager.saveManifest() }
                )) {
                    let groupSessions = manager.sessions.filter { manager.sessionGroupMap[$0.id] == group.id }
                    ForEach(groupSessions) { session in
                        sessionRow(session)
                    }
                } label: {
                    GroupHeader(group: group, manager: manager)
                }
                .dropDestination(for: String.self) { items, _ in
                    for item in items {
                        if let sessionId = UUID(uuidString: item),
                           let session = manager.sessions.first(where: { $0.id == sessionId }) {
                            manager.moveSession(session, to: group)
                        }
                    }
                    return true
                }
            }

            // Ungrouped sessions
            if !ungroupedSessions.isEmpty {
                Section("Sessions") {
                    ForEach(ungroupedSessions) { session in
                        sessionRow(session)
                    }
                }
                .dropDestination(for: String.self) { items, _ in
                    for item in items {
                        if let sessionId = UUID(uuidString: item),
                           let session = manager.sessions.first(where: { $0.id == sessionId }) {
                            manager.moveSession(session, to: nil)
                        }
                    }
                    return true
                }
            }
        }
        .id(manager.sessionGroupMap.count)  // Force list refresh when groupings change
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                SidebarNewSessionButton(label: "New Claude Session", icon: "plus.circle.fill", style: .primary) {
                    manager.newSession()
                }

                HStack(spacing: 6) {
                    SidebarNewSessionButton(label: "Terminal", icon: "terminal.fill", style: .secondary) {
                        manager.newTerminalSession()
                    }

                    SidebarNewSessionButton(label: "Group", icon: "folder.badge.plus", style: .secondary) {
                        newGroupName = ""
                        showNewGroupAlert = true
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .alert("New Group", isPresented: $showNewGroupAlert) {
            TextField("Group name", text: $newGroupName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                if !newGroupName.trimmingCharacters(in: .whitespaces).isEmpty {
                    manager.createGroup(name: newGroupName)
                }
            }
        }
    }

    @ViewBuilder
    private func sessionRow(_ session: AnySession) -> some View {
        SessionRow(session: session)
            .tag(session.id)
            .draggable(session.id.uuidString)
            .contextMenu {
                if !manager.groups.isEmpty {
                    Menu("Move to Group") {
                        Button("Ungrouped") {
                            manager.moveSession(session, to: nil)
                        }
                        Divider()
                        ForEach(manager.groups) { group in
                            Button(group.name) {
                                manager.moveSession(session, to: group)
                            }
                        }
                    }
                    Divider()
                }
                Button("Close Session", role: .destructive) {
                    manager.closeSession(session)
                }
            }
    }
}

// MARK: - Group Header

private struct GroupHeader: View {
    let group: SessionGroup
    let manager: SessionManager
    @State private var isEditing = false
    @State private var editName = ""

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 12))

            if isEditing {
                TextField("", text: $editName)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        if !editName.trimmingCharacters(in: .whitespaces).isEmpty {
                            manager.renameGroup(group, to: editName)
                        }
                        isEditing = false
                    }
            } else {
                Text(group.name)
                    .fontWeight(.medium)
            }

            Spacer()

            Text("\(manager.sessions.filter { manager.sessionGroupMap[$0.id] == group.id }.count)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contextMenu {
            Button("Rename") {
                editName = group.name
                isEditing = true
            }
            Divider()
            Button("Delete Group", role: .destructive) {
                manager.deleteGroup(group)
            }
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
