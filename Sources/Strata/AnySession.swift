import Foundation

/// Discriminated union for session types, enabling a heterogeneous
/// sessions array in SessionManager.
enum AnySession: Identifiable {
    case claude(Session)
    case terminal(TerminalSession)

    var id: UUID {
        switch self {
        case .claude(let s): s.id
        case .terminal(let t): t.id
        }
    }

    var name: String {
        switch self {
        case .claude(let s): s.name
        case .terminal(let t): t.name
        }
    }

    var workingDirectory: String {
        switch self {
        case .claude(let s): s.workingDirectory
        case .terminal(let t): t.workingDirectory
        }
    }

    var isActive: Bool {
        switch self {
        case .claude(let s): s.isResponding
        case .terminal(let t): t.isRunning
        }
    }

    func terminate() {
        switch self {
        case .claude(let s): s.cancel()
        case .terminal(let t): t.terminate()
        }
    }
}
