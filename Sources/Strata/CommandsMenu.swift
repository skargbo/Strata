import AppKit
import SwiftUI

struct AppCommands: Commands {
    let manager: SessionManager
    @FocusedValue(\.diffPanelToggle) var diffPanelToggle
    @FocusedValue(\.settingsToggle) var settingsToggle
    @FocusedValue(\.focusedModeToggle) var focusedModeToggle
    @FocusedValue(\.commandPaletteToggle) var commandPaletteToggle

    var body: some Commands {
        // Replace the default New Window command
        CommandGroup(replacing: .newItem) {
            Button("New Claude Session") {
                manager.newSession()
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("New Terminal Session") {
                manager.newTerminalSession()
            }
            .keyboardShortcut("t", modifiers: .command)

            Divider()

            Button("New Claude Session in Directory...") {
                pickDirectoryAndRun { dir in
                    manager.newSession(workingDirectory: dir)
                }
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("New Terminal in Directory...") {
                pickDirectoryAndRun { dir in
                    manager.newTerminalSession(workingDirectory: dir)
                }
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])

            Divider()

            Button("Close Session") {
                if let session = manager.selectedSession {
                    manager.closeSession(session)
                }
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(manager.selectedSession == nil)
        }

        CommandMenu("Tools") {
            Button("Command Palette") {
                commandPaletteToggle?.wrappedValue.toggle()
            }
            .keyboardShortcut("k", modifiers: .command)

            Divider()

            Button("Cancel Response") {
                if case .claude(let s) = manager.selectedSession {
                    s.cancel()
                }
            }
            .keyboardShortcut("c", modifiers: .control)
            .disabled({
                if case .claude(let s) = manager.selectedSession {
                    return !s.isResponding
                }
                return true
            }())

            Divider()

            Button("Toggle Changes Panel") {
                diffPanelToggle?.wrappedValue.toggle()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Button("Session Settings") {
                settingsToggle?.wrappedValue.toggle()
            }
            .keyboardShortcut(",", modifiers: .command)
            .disabled(manager.selectedSession == nil)

            Divider()

            Button {
                focusedModeToggle?.wrappedValue.toggle()
            } label: {
                if let binding = focusedModeToggle, binding.wrappedValue {
                    Text("Exit Focus Mode")
                } else {
                    Text("Enter Focus Mode")
                }
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(focusedModeToggle == nil)

            Divider()

            Picker("Appearance", selection: Binding(
                get: { manager.appearanceMode },
                set: { manager.appearanceMode = $0 }
            )) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
        }
    }
}

/// Open a directory picker panel and call the handler with the selected path.
private func pickDirectoryAndRun(handler: @escaping (String) -> Void) {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = true
    panel.prompt = "Select"
    panel.message = "Choose a working directory for the session"

    panel.begin { response in
        if response == .OK, let url = panel.url {
            handler(url.path)
        }
    }
}
