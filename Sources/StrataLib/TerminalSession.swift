import AppKit
import SwiftTerm

/// Represents a terminal (shell) session. Owns the cached
/// LocalProcessTerminalView so the PTY process survives view recreation
/// during session switches.
@Observable
final class TerminalSession: Identifiable {
    let id: UUID
    var name: String
    var workingDirectory: String
    let createdAt: Date
    var isRunning: Bool = true

    let shellPath: String

    /// Cached terminal view — the PTY process lives as long as this exists.
    /// Created lazily on first access, reused on subsequent view recreations.
    private var cachedTerminalView: LocalProcessTerminalView?

    init(
        name: String? = nil,
        workingDirectory: String = NSHomeDirectory()
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.workingDirectory = workingDirectory

        let dirName = (workingDirectory as NSString).lastPathComponent
        self.name = name ?? "Terminal \u{2014} \(dirName)"

        self.shellPath = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    }

    /// Restore from persisted data. The PTY is dead — the shell will
    /// re-launch when the user navigates to this session.
    init(restoring snapshot: TerminalSessionSnapshot) {
        self.id = snapshot.id
        self.name = snapshot.name
        self.workingDirectory = snapshot.workingDirectory
        self.createdAt = snapshot.createdAt
        self.shellPath = snapshot.shellPath
        self.isRunning = false
    }

    /// Create a Codable snapshot of the current metadata.
    func toSnapshot() -> TerminalSessionSnapshot {
        TerminalSessionSnapshot(
            id: id,
            name: name,
            workingDirectory: workingDirectory,
            createdAt: createdAt,
            shellPath: shellPath
        )
    }

    /// Returns the cached terminal view, creating it on first call.
    /// The view (and its PTY process) persists across SwiftUI view recreation.
    func getOrCreateTerminalView(delegate: LocalProcessTerminalViewDelegate) -> LocalProcessTerminalView {
        if let existing = cachedTerminalView {
            // Re-assign delegate since the coordinator may have been recreated
            existing.processDelegate = delegate
            return existing
        }

        let terminalView = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        terminalView.processDelegate = delegate

        // Font
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        // Apply default (dark) colors — these get updated dynamically by the wrapper
        Self.applyColors(to: terminalView, isDark: true)

        // Build environment
        var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")

        // Merge user's PATH and other important vars.
        // SSH_AUTH_SOCK is intentionally included: terminal sessions are user-controlled
        // interactive shells (like Terminal.app) where the user expects git/ssh to work.
        // This is distinct from the Claude bridge (ClaudeRunner.swift), which does NOT
        // receive SSH_AUTH_SOCK because AI-controlled execution should not access SSH keys.
        let userEnv = ProcessInfo.processInfo.environment
        for key in ["PATH", "HOME", "USER", "LOGNAME", "SHELL", "TMPDIR", "SSH_AUTH_SOCK", "HOMEBREW_PREFIX"] {
            if let value = userEnv[key] {
                // Remove any existing entry for this key
                env.removeAll { $0.hasPrefix("\(key)=") }
                env.append("\(key)=\(value)")
            }
        }

        // Start the shell as a login shell (prefix argv[0] with "-")
        let execName = "-" + (shellPath as NSString).lastPathComponent
        terminalView.startProcess(
            executable: shellPath,
            args: [],
            environment: env,
            execName: execName
        )

        // Navigate to working directory by sending a cd command to the shell
        let escapedDir = workingDirectory.replacingOccurrences(of: "'", with: "'\\''")
        let cdCommand = "cd '\(escapedDir)' && clear\n"
        let bytes = Array(cdCommand.utf8)
        terminalView.send(source: terminalView, data: ArraySlice(bytes))

        cachedTerminalView = terminalView
        return terminalView
    }

    /// Apply light or dark terminal colors to a view.
    static func applyColors(to view: LocalProcessTerminalView, isDark: Bool) {
        if isDark {
            view.nativeBackgroundColor = NSColor(calibratedRed: 0.1, green: 0.1, blue: 0.12, alpha: 1)
            view.nativeForegroundColor = NSColor(calibratedWhite: 0.9, alpha: 1)
        } else {
            // Light mode — using design palette: #FFFFFF bg, #1D1D1F fg
            view.nativeBackgroundColor = NSColor.white
            view.nativeForegroundColor = NSColor(calibratedRed: 0.114, green: 0.114, blue: 0.122, alpha: 1)
        }
        view.caretColor = NSColor.orange
    }

    /// Kill the shell process and release the cached view.
    func terminate() {
        if let view = cachedTerminalView {
            // Send exit command to the shell, then release the view
            // (LocalProcessTerminalView cleans up the PTY on deinit)
            let exitBytes = Array("exit\n".utf8)
            view.send(source: view, data: ArraySlice(exitBytes))
        }
        cachedTerminalView = nil
        isRunning = false
    }
}
