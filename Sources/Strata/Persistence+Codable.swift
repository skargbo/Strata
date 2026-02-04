import Foundation

// MARK: - Session Manifest

/// Lightweight index of all sessions. Stored as `manifest.json`.
struct SessionManifest: Codable {
    var version: Int = 1
    var sessionEntries: [SessionEntry]
    var selectedSessionID: UUID?

    struct SessionEntry: Codable {
        let id: UUID
        let type: SessionType
        let name: String
        let createdAt: Date
        let workingDirectory: String
    }

    enum SessionType: String, Codable {
        case claude
        case terminal
    }
}

// MARK: - Claude Session Snapshot

struct SessionSnapshot: Codable {
    var version: Int = 1
    let id: UUID
    var name: String
    var createdAt: Date
    var settings: SessionSettingsData
    var messages: [ChatMessageData]
    /// SDK session ID for conversation resumption. Stored alongside conversation
    /// messages (which are themselves more sensitive). Protected by 0600 file
    /// permissions. The ID alone cannot resume a conversation without valid API
    /// credentials (ANTHROPIC_API_KEY). Cleared when the session is deleted.
    var sessionId: String?
    var totalCost: Double
    var lastUsage: UsageInfoData?
}

// MARK: - Terminal Session Snapshot

struct TerminalSessionSnapshot: Codable {
    var version: Int = 1
    let id: UUID
    var name: String
    var workingDirectory: String
    var createdAt: Date
    var shellPath: String
}

// MARK: - Session Settings Data

struct SessionSettingsData: Codable {
    var workingDirectory: String
    var permissionMode: String
    var toolCardsDefaultExpanded: Bool
    var soundNotifications: Bool
    var notificationSound: String
    var model: String
    var customSystemPrompt: String
    var theme: SessionThemeData
}

struct SessionThemeData: Codable {
    var accentColor: String
    var fontSize: String
    var density: String
}

// MARK: - Chat Message Data

struct ChatMessageData: Codable {
    let id: UUID
    let role: String
    var text: String
    let timestamp: Date
    var toolActivity: ToolActivityData?
}

// MARK: - Tool Activity Data

struct ToolActivityData: Codable {
    let id: UUID
    let toolName: String
    let input: ToolActivityInputData
    let result: ToolActivityResultData
}

struct ToolActivityInputData: Codable {
    var filePath: String?
    var command: String?
    var description: String?
    var oldString: String?
    var newString: String?
    var content: String?
    var pattern: String?
    var path: String?
    var rawJSON: String?
}

struct ToolActivityResultData: Codable {
    var stdout: String?
    var stderr: String?
    var interrupted: Bool
    var fileContent: String?
    var filenames: [String]?
    var fileCount: Int?
    var diffLines: [DiffLineData]?
    var rawJSON: String?
}

struct DiffLineData: Codable {
    let kind: String
    let text: String
    let lineNumber: Int?
}

// MARK: - Usage Info Data

struct UsageInfoData: Codable {
    var inputTokens: Int
    var outputTokens: Int
    var cacheReadTokens: Int
    var cacheCreationTokens: Int
    var costUSD: Double
    var durationMs: Int
    var contextTokens: Int = 0
}

// MARK: - Default Settings

struct DefaultSettingsData: Codable {
    var version: Int = 1
    var settings: SessionSettingsData
    var appearanceMode: String
}
