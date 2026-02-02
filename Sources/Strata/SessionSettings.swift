import AppKit
import SwiftUI

/// Per-session settings that control model, permissions, appearance, and behavior.
@Observable
final class SessionSettings {
    // --- Existing settings (previously on Session directly) ---
    var workingDirectory: String
    var permissionMode: String // "default", "acceptEdits", "plan", "bypassPermissions"

    // --- New settings ---
    var toolCardsDefaultExpanded: Bool = false
    var soundNotifications: Bool = false
    var notificationSound: NotificationSound = .glass
    var model: ClaudeModel = .sonnet
    var customSystemPrompt: String = ""
    var theme: SessionTheme = SessionTheme()

    init(workingDirectory: String = NSHomeDirectory()) {
        self.workingDirectory = workingDirectory
        self.permissionMode = "default"
    }

    /// Restore from persisted data.
    init(from data: SessionSettingsData) {
        // Validate restored path: resolve symlinks, verify it still exists.
        // Falls back to home directory if the saved directory was deleted or is invalid.
        let restored = (data.workingDirectory as NSString).resolvingSymlinksInPath
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: restored, isDirectory: &isDir), isDir.boolValue {
            self.workingDirectory = restored
        } else {
            self.workingDirectory = NSHomeDirectory()
        }
        self.permissionMode = data.permissionMode
        self.toolCardsDefaultExpanded = data.toolCardsDefaultExpanded
        self.soundNotifications = data.soundNotifications
        self.notificationSound = NotificationSound(rawValue: data.notificationSound) ?? .glass
        self.model = ClaudeModel(rawValue: data.model) ?? .sonnet
        self.customSystemPrompt = data.customSystemPrompt
        self.theme = SessionTheme(
            accentColor: SessionTheme.AccentColor(rawValue: data.theme.accentColor) ?? .orange,
            fontSize: SessionTheme.FontSize(rawValue: data.theme.fontSize) ?? .regular,
            density: SessionTheme.Density(rawValue: data.theme.density) ?? .comfortable
        )
    }

    /// Convert to Codable data.
    func toData() -> SessionSettingsData {
        SessionSettingsData(
            workingDirectory: workingDirectory,
            permissionMode: permissionMode,
            toolCardsDefaultExpanded: toolCardsDefaultExpanded,
            soundNotifications: soundNotifications,
            notificationSound: notificationSound.rawValue,
            model: model.rawValue,
            customSystemPrompt: customSystemPrompt,
            theme: SessionThemeData(
                accentColor: theme.accentColor.rawValue,
                fontSize: theme.fontSize.rawValue,
                density: theme.density.rawValue
            )
        )
    }
}

// MARK: - Model Selection

enum ClaudeModel: String, CaseIterable, Identifiable {
    case sonnet = "claude-sonnet-4-5-20250929"
    case opus = "claude-opus-4-20250514"
    case haiku = "claude-haiku-3-5-20241022"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sonnet: "Claude Sonnet 4.5"
        case .opus: "Claude Opus 4"
        case .haiku: "Claude Haiku 3.5"
        }
    }

    var shortName: String {
        switch self {
        case .sonnet: "Sonnet"
        case .opus: "Opus"
        case .haiku: "Haiku"
        }
    }
}

// MARK: - Notification Sound

enum NotificationSound: String, CaseIterable, Identifiable {
    case basso = "Basso"
    case blow = "Blow"
    case bottle = "Bottle"
    case frog = "Frog"
    case funk = "Funk"
    case glass = "Glass"
    case hero = "Hero"
    case morse = "Morse"
    case ping = "Ping"
    case pop = "Pop"
    case purr = "Purr"
    case sosumi = "Sosumi"
    case submarine = "Submarine"
    case tink = "Tink"

    var id: String { rawValue }

    func play() {
        NSSound(named: NSSound.Name(rawValue))?.play()
    }
}

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable, Identifiable {
    case dark
    case light
    case auto

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark: "Dark"
        case .light: "Light"
        case .auto: "Auto"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .auto: nil
        }
    }
}

// MARK: - Theme / Appearance

struct SessionTheme {
    var accentColor: AccentColor = .orange
    var fontSize: FontSize = .regular
    var density: Density = .comfortable

    enum AccentColor: String, CaseIterable, Identifiable {
        case orange, blue, purple, green, pink, teal

        var id: String { rawValue }

        var color: Color {
            switch self {
            case .orange: .orange
            case .blue: .blue
            case .purple: .purple
            case .green: .green
            case .pink: .pink
            case .teal: .teal
            }
        }
    }

    enum FontSize: String, CaseIterable, Identifiable {
        case small, regular, large

        var id: String { rawValue }

        var bodySize: CGFloat {
            switch self {
            case .small: 12
            case .regular: 13
            case .large: 15
            }
        }
    }

    enum Density: String, CaseIterable, Identifiable {
        case compact, comfortable

        var id: String { rawValue }

        var messageSpacing: CGFloat {
            switch self {
            case .compact: 6
            case .comfortable: 12
            }
        }
    }
}
