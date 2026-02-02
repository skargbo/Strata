import AppKit
import SwiftUI
import SwiftTerm

/// Displays an embedded terminal session using SwiftTerm.
struct TerminalSessionView: View {
    @Bindable var session: TerminalSession

    var body: some View {
        VStack(spacing: 0) {
            TerminalNSViewWrapper(session: session)

            Divider()

            // Status bar
            HStack(spacing: 12) {
                Image(systemName: "terminal.fill")
                    .foregroundStyle(.green)

                Text(session.shellPath)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Circle()
                    .fill(session.isRunning ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
                Text(session.isRunning ? "Running" : "Exited")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)
        }
        .navigationTitle(session.name)
        .navigationSubtitle(session.workingDirectory)
    }
}

// MARK: - NSViewRepresentable

/// Wraps SwiftTerm's LocalProcessTerminalView for use in SwiftUI.
/// The actual view is cached in TerminalSession, so the PTY process
/// survives when SwiftUI recreates this wrapper during session switches.
struct TerminalNSViewWrapper: NSViewRepresentable {
    let session: TerminalSession
    @Environment(\.colorScheme) private var colorScheme

    func makeNSView(context: Context) -> NSView {
        let terminalView = session.getOrCreateTerminalView(delegate: context.coordinator)

        // Apply colors for current appearance
        TerminalSession.applyColors(to: terminalView, isDark: colorScheme == .dark)

        // Wrap in a container so SwiftUI can manage layout
        let container = NSView(frame: .zero)
        container.autoresizesSubviews = true
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(terminalView)
        NSLayoutConstraint.activate([
            terminalView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            terminalView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            terminalView.topAnchor.constraint(equalTo: container.topAnchor),
            terminalView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        // Ensure the terminal gets keyboard focus
        DispatchQueue.main.async {
            terminalView.window?.makeFirstResponder(terminalView)
        }

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Update terminal colors when appearance changes
        if let terminalView = nsView.subviews.first as? LocalProcessTerminalView {
            TerminalSession.applyColors(to: terminalView, isDark: colorScheme == .dark)

            // Re-focus the terminal when the view is updated (e.g. session switch back)
            DispatchQueue.main.async {
                terminalView.window?.makeFirstResponder(terminalView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let session: TerminalSession

        init(session: TerminalSession) {
            self.session = session
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            DispatchQueue.main.async { [weak self] in
                self?.session.isRunning = false
            }
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
            // SwiftTerm handles SIGWINCH internally
        }

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            DispatchQueue.main.async { [weak self] in
                if !title.isEmpty {
                    self?.session.name = title
                }
            }
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            if let dir = directory {
                DispatchQueue.main.async { [weak self] in
                    self?.session.workingDirectory = dir
                }
            }
        }
    }
}
