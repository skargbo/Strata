import Foundation

// MARK: - Session Manifest

/// Lightweight index of all sessions. Stored as `manifest.json`.
struct SessionManifest: Codable {
    var version: Int = 2
    var groups: [SessionGroupData]?  // Optional for backward compatibility
    var sessionEntries: [SessionEntry]
    var selectedSessionID: UUID?

    struct SessionEntry: Codable {
        let id: UUID
        let type: SessionType
        let name: String
        let createdAt: Date
        let workingDirectory: String
        var groupId: UUID?  // nil = ungrouped
    }

    enum SessionType: String, Codable {
        case claude
        case terminal
    }
}

// MARK: - Session Group Data

struct SessionGroupData: Codable, Identifiable {
    var id: UUID
    var name: String
    var isExpanded: Bool
    var order: Int
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
    var tasks: [SessionTaskData]?           // Optional for backward compatibility
    var memoryEvents: [MemoryEventData]?    // Optional for backward compatibility
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

    // Task tool fields
    var subject: String?
    var taskId: String?
    var taskStatus: String?
    var activeForm: String?
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

    // Task tool results
    var taskResult: SessionTaskData?
    var taskListResult: [SessionTaskData]?
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

// MARK: - Session Task Data

struct SessionTaskData: Codable {
    let id: String
    var subject: String
    var status: String
    var activeForm: String?
    var description: String?
    var blockedBy: [String]?
}

// MARK: - Memory Event Data

struct MemoryEventData: Codable {
    let id: UUID
    let timestamp: Date
    let type: String
    let title: String
    var detail: String?
    var filePath: String?
}

// MARK: - Context Breakdown Data

struct ContextBreakdownData: Codable {
    var conversationTokens: Int
    var toolResultTokens: Int
    var systemPromptTokens: Int
    var filesInContext: [FileTokenInfoData]
    var cacheTokens: Int

    struct FileTokenInfoData: Codable {
        let id: UUID
        let path: String
        let tokens: Int
        let timestamp: Date
    }
}

// MARK: - Default Settings

struct DefaultSettingsData: Codable {
    var version: Int = 1
    var settings: SessionSettingsData
    var appearanceMode: String
}
