import Foundation

/// Manages multiple sessions (Claude chat and terminal).
@Observable
final class SessionManager {
    var sessions: [AnySession] = []
    var selectedSessionID: UUID?

    var selectedSession: AnySession? {
        sessions.first { $0.id == selectedSessionID }
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

        for entry in manifest.sessionEntries {
            switch entry.type {
            case .claude:
                if let snapshot = persistence.loadSession(id: entry.id) {
                    let session = Session(restoring: snapshot)
                    wireDataChanged(session)
                    sessions.append(.claude(session))
                }
            case .terminal:
                if let snapshot = persistence.loadTerminalSession(id: entry.id) {
                    let session = TerminalSession(restoring: snapshot)
                    sessions.append(.terminal(session))
                }
            }
        }

        selectedSessionID = manifest.selectedSessionID ?? sessions.first?.id
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

    private func saveManifest() {
        let manifest = SessionManifest(
            sessionEntries: sessions.map { session in
                switch session {
                case .claude(let s):
                    return .init(id: s.id, type: .claude, name: s.name,
                                 createdAt: s.createdAt, workingDirectory: s.workingDirectory)
                case .terminal(let t):
                    return .init(id: t.id, type: .terminal, name: t.name,
                                 createdAt: t.createdAt, workingDirectory: t.workingDirectory)
                }
            },
            selectedSessionID: selectedSessionID
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
