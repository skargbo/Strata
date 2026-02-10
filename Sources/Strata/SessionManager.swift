import Foundation

/// Manages multiple sessions (Claude chat and terminal).
@Observable
final class SessionManager {
    var sessions: [AnySession] = []
    var groups: [SessionGroup] = []
    var sessionGroupMap: [UUID: UUID] = [:]  // sessionId -> groupId
    var selectedSessionID: UUID?

    // Split-screen state
    var isSplitScreen: Bool = false
    var splitSessionID: UUID?
    var splitRatio: Double = 0.5

    var selectedSession: AnySession? {
        sessions.first { $0.id == selectedSessionID }
    }

    var splitSession: AnySession? {
        guard let id = splitSessionID else { return nil }
        return sessions.first { $0.id == id }
    }

    var appearanceMode: AppearanceMode = .dark {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
        }
    }

    private let persistence = PersistenceManager.shared

    init() {
        // Restore appearance from UserDefaults
        if let raw = UserDefaults.standard.string(forKey: "appearanceMode"),
           let mode = AppearanceMode(rawValue: raw) {
            self.appearanceMode = mode
        }

        // Restore sessions from disk
        restoreSessions()
    }

    // MARK: - Restore

    private func restoreSessions() {
        guard let manifest = persistence.loadManifest() else { return }

        // Restore groups
        if let groupsData = manifest.groups {
            groups = groupsData.map { SessionGroup(from: $0) }
        }

        // Restore sessions and group assignments
        for entry in manifest.sessionEntries {
            switch entry.type {
            case .claude:
                if let snapshot = persistence.loadSession(id: entry.id) {
                    let session = Session(restoring: snapshot)
                    wireDataChanged(session)
                    sessions.append(.claude(session))
                    if let groupId = entry.groupId {
                        sessionGroupMap[entry.id] = groupId
                    }
                }
            case .terminal:
                if let snapshot = persistence.loadTerminalSession(id: entry.id) {
                    let session = TerminalSession(restoring: snapshot)
                    sessions.append(.terminal(session))
                    if let groupId = entry.groupId {
                        sessionGroupMap[entry.id] = groupId
                    }
                }
            }
        }

        selectedSessionID = manifest.selectedSessionID ?? sessions.first?.id
        isSplitScreen = manifest.isSplitScreen ?? false
        splitSessionID = manifest.splitSessionID
        splitRatio = manifest.splitRatio ?? 0.5
    }

    // MARK: - Claude Sessions

    @discardableResult
    func newSession(
        name: String? = nil,
        workingDirectory: String = NSHomeDirectory()
    ) -> Session {
        let session = Session(name: name, workingDirectory: workingDirectory)
        wireDataChanged(session)
        sessions.append(.claude(session))
        selectedSessionID = session.id
        saveManifest()
        return session
    }

    // MARK: - Terminal Sessions

    @discardableResult
    func newTerminalSession(
        name: String? = nil,
        workingDirectory: String = NSHomeDirectory()
    ) -> TerminalSession {
        let session = TerminalSession(name: name, workingDirectory: workingDirectory)
        sessions.append(.terminal(session))
        selectedSessionID = session.id
        saveManifest()
        return session
    }

    // MARK: - Shared

    func closeSession(_ anySession: AnySession) {
        anySession.terminate()
        persistence.deleteSession(id: anySession.id)
        sessions.removeAll { $0.id == anySession.id }
        if selectedSessionID == anySession.id {
            selectedSessionID = sessions.last?.id
        }
        if splitSessionID == anySession.id {
            splitSessionID = nil
        }
        saveManifest()
    }

    func closeAll() {
        for session in sessions {
            session.terminate()
        }
        sessions.removeAll()
        selectedSessionID = nil
    }

    func select(_ id: UUID?) {
        selectedSessionID = id
    }

    // MARK: - Split Screen

    func enterSplitScreen() {
        guard !isSplitScreen else { return }
        isSplitScreen = true
        saveManifest()
    }

    func exitSplitScreen() {
        isSplitScreen = false
        saveManifest()
    }

    func toggleSplitScreen() {
        if isSplitScreen {
            exitSplitScreen()
        } else {
            enterSplitScreen()
        }
    }

    func selectSplitSession(_ id: UUID) {
        splitSessionID = id
        saveManifest()
    }

    // MARK: - Session Groups

    @discardableResult
    func createGroup(name: String) -> SessionGroup {
        let order = groups.map(\.order).max().map { $0 + 1 } ?? 0
        let group = SessionGroup(name: name, order: order)
        groups.append(group)
        saveManifest()
        return group
    }

    func deleteGroup(_ group: SessionGroup) {
        // Move all sessions in this group to ungrouped
        var map = sessionGroupMap
        for (sessionId, groupId) in map where groupId == group.id {
            map.removeValue(forKey: sessionId)
        }
        sessionGroupMap = map
        groups.removeAll { $0.id == group.id }
        saveManifest()
    }

    func renameGroup(_ group: SessionGroup, to name: String) {
        group.name = name
        saveManifest()
    }

    func moveSession(_ session: AnySession, to group: SessionGroup?) {
        // Use full reassignment to ensure @Observable triggers view updates
        var map = sessionGroupMap
        if let group = group {
            map[session.id] = group.id
        } else {
            map.removeValue(forKey: session.id)
        }
        sessionGroupMap = map
        saveManifest()
    }

    func sessionsInGroup(_ groupId: UUID?) -> [AnySession] {
        if let groupId = groupId {
            return sessions.filter { sessionGroupMap[$0.id] == groupId }
        } else {
            // Ungrouped sessions
            return sessions.filter { sessionGroupMap[$0.id] == nil }
        }
    }

    // MARK: - Persistence

    /// Save everything — called on app quit.
    func saveAll() {
        persistence.flushPendingSaves()

        // Save manifest
        saveManifest()

        // Save each session
        for session in sessions {
            switch session {
            case .claude(let s):
                persistence.saveSession(s.toSnapshot())
            case .terminal(let t):
                persistence.saveTerminalSession(t.toSnapshot())
            }
        }
    }

    func saveManifest() {
        let manifest = SessionManifest(
            groups: groups.isEmpty ? nil : groups.map { $0.toData() },
            sessionEntries: sessions.map { session in
                let groupId = sessionGroupMap[session.id]
                switch session {
                case .claude(let s):
                    return .init(id: s.id, type: .claude, name: s.name,
                                 createdAt: s.createdAt, workingDirectory: s.workingDirectory,
                                 groupId: groupId)
                case .terminal(let t):
                    return .init(id: t.id, type: .terminal, name: t.name,
                                 createdAt: t.createdAt, workingDirectory: t.workingDirectory,
                                 groupId: groupId)
                }
            },
            selectedSessionID: selectedSessionID,
            isSplitScreen: isSplitScreen ? true : nil,
            splitSessionID: splitSessionID,
            splitRatio: splitRatio != 0.5 ? splitRatio : nil
        )
        persistence.saveManifest(manifest)
    }

    private func wireDataChanged(_ session: Session) {
        session.onDataChanged = { [weak self, weak session] in
            guard let session else { return }
            self?.persistence.scheduleSave(for: session.id) { [weak session] in
                session?.toSnapshot()
            }
        }
    }
}
