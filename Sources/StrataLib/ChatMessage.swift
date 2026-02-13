import Foundation
import SwiftUI

/// A single message in a chat conversation.
struct ChatMessage: Identifiable {
    let id: UUID
    let role: Role
    var text: String
    let timestamp: Date
    var toolActivity: ToolActivity?

    enum Role {
        case user
        case assistant
        case system
        case tool
    }

    init(role: Role, text: String, toolActivity: ToolActivity? = nil) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.timestamp = Date()
        self.toolActivity = toolActivity
    }

    /// Restore from persisted data with explicit id and timestamp.
    init(id: UUID, role: Role, text: String, timestamp: Date, toolActivity: ToolActivity? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
        self.toolActivity = toolActivity
    }
}

// MARK: - Role Persistence

extension ChatMessage.Role {
    var persistenceKey: String {
        switch self {
        case .user: "user"
        case .assistant: "assistant"
        case .system: "system"
        case .tool: "tool"
        }
    }

    static func from(_ key: String) -> ChatMessage.Role? {
        switch key {
        case "user": .user
        case "assistant": .assistant
        case "system": .system
        case "tool": .tool
        default: nil
        }
    }
}

// MARK: - Tool Activity

/// Represents a single tool invocation with its input and result data.
struct ToolActivity: Identifiable {
    let id = UUID()
    let toolName: String
    let input: ToolActivityInput
    let result: ToolActivityResult

    var summaryText: String {
        switch toolName {
        case "Bash":
            let cmd = input.command ?? "command"
            return cmd.count > 80 ? String(cmd.prefix(77)) + "..." : cmd
        case "Edit":
            let file = (input.filePath as NSString?)?.lastPathComponent ?? "file"
            return "Edit \(file)"
        case "Write":
            let file = (input.filePath as NSString?)?.lastPathComponent ?? "file"
            return "Write \(file)"
        case "Read":
            let file = (input.filePath as NSString?)?.lastPathComponent ?? "file"
            return "Read \(file)"
        case "Glob":
            let pattern = input.pattern ?? "files"
            let count = result.fileCount ?? 0
            return "Search \(pattern) \u{2014} \(count) file\(count == 1 ? "" : "s")"
        case "Grep":
            let pattern = input.pattern ?? "pattern"
            let count = result.fileCount ?? 0
            return "Grep /\(pattern)/ \u{2014} \(count) match\(count == 1 ? "" : "es")"
        case "TaskCreate":
            // Subject may be in input or in result
            let subject = input.subject ?? result.taskResult?.subject ?? "task"
            return "Created task: \(subject)"
        case "TodoWrite":
            // TodoWrite updates the full task list
            let count = result.taskListResult?.count ?? 0
            let inProgress = result.taskListResult?.first { $0.status == .in_progress }
            if let active = inProgress {
                return "\(active.subject)"
            }
            return "Updated \(count) task\(count == 1 ? "" : "s")"
        case "TaskUpdate":
            // Status/id may be in input or result
            let status = input.taskStatus ?? result.taskResult?.status.rawValue ?? "updated"
            let id = input.taskId ?? result.taskResult?.id ?? "?"
            return "Task #\(id) \u{2192} \(status)"
        case "TodoUpdate":
            let count = result.taskListResult?.count ?? 0
            return "Updated \(count) task\(count == 1 ? "" : "s")"
        case "TaskList", "TodoRead":
            let count = result.taskListResult?.count ?? 0
            return "Listed \(count) task\(count == 1 ? "" : "s")"
        case "TaskGet":
            let id = input.taskId ?? result.taskResult?.id ?? "?"
            return "Fetched task #\(id)"
        default:
            return toolName
        }
    }

    var iconName: String {
        switch toolName {
        case "Bash": return "terminal.fill"
        case "Edit": return "pencil.circle.fill"
        case "Write": return "doc.fill"
        case "Read": return "doc.text.fill"
        case "Glob": return "doc.text.magnifyingglass"
        case "Grep": return "magnifyingglass"
        case "TaskCreate", "TaskUpdate", "TaskList", "TaskGet",
             "TodoWrite", "TodoUpdate", "TodoRead": return "checklist"
        default: return "wrench.fill"
        }
    }

    var iconColor: Color {
        switch toolName {
        case "Bash": return .orange
        case "Edit": return .yellow
        case "Write": return .blue
        case "Read": return .green
        case "Glob", "Grep": return .purple
        case "TaskCreate", "TaskUpdate", "TaskList", "TaskGet",
             "TodoWrite", "TodoUpdate", "TodoRead": return .teal
        default: return .gray
        }
    }

    /// Accent bar color for the card's left border.
    var accentColor: Color {
        switch toolName {
        case "Bash": return .orange
        case "Edit", "Write": return .blue
        case "Read": return .green
        case "Glob", "Grep": return .purple
        case "TaskCreate", "TaskUpdate", "TaskList", "TaskGet",
             "TodoWrite", "TodoUpdate", "TodoRead": return .teal
        default: return .gray
        }
    }

    /// Secondary summary line (e.g. "Added 1 line, removed 1 line").
    var detailSummary: String? {
        switch toolName {
        case "Edit":
            guard let diffLines = result.diffLines else { return nil }
            let adds = diffLines.filter { $0.kind == .addition }.count
            let removes = diffLines.filter { $0.kind == .removal }.count
            if adds == 0 && removes == 0 { return nil }
            var parts: [String] = []
            if adds > 0 { parts.append("\(adds) added") }
            if removes > 0 { parts.append("\(removes) removed") }
            return parts.joined(separator: ", ")
        case "Bash":
            if result.interrupted { return "Interrupted" }
            return nil
        default:
            return nil
        }
    }
}

struct ToolActivityInput {
    var filePath: String?
    var command: String?
    var description: String?
    var oldString: String?
    var newString: String?
    var content: String?
    var pattern: String?
    var path: String?
    var raw: [String: Any] = [:]

    // Task tool fields
    var subject: String?
    var taskId: String?
    var taskStatus: String?
    var activeForm: String?
}

struct ToolActivityResult {
    var stdout: String?
    var stderr: String?
    var interrupted: Bool = false
    var fileContent: String?
    var filenames: [String]?
    var fileCount: Int?
    var diffLines: [DiffLine]?
    var raw: Any?

    // Task tool results
    var taskResult: SessionTask?
    var taskListResult: [SessionTask]?
}

struct UsageInfo {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var costUSD: Double = 0
    var durationMs: Int = 0
    var contextTokens: Int = 0

    var totalInputTokens: Int {
        inputTokens + cacheReadTokens + cacheCreationTokens
    }
}

// MARK: - Context Breakdown

/// Breakdown of context token usage by source
struct ContextBreakdown {
    var conversationTokens: Int = 0
    var toolResultTokens: Int = 0
    var systemPromptTokens: Int = 0
    var filesInContext: [FileTokenInfo] = []
    var cacheTokens: Int = 0

    struct FileTokenInfo: Identifiable {
        let id = UUID()
        let path: String
        let tokens: Int
        let timestamp: Date
    }

    var totalEstimated: Int {
        conversationTokens + toolResultTokens + systemPromptTokens
    }
}

// MARK: - Memory Event

/// Represents a significant event in the session's memory/context
struct MemoryEvent: Identifiable {
    let id: UUID
    let timestamp: Date
    let type: MemoryEventType
    let title: String
    let detail: String?
    let filePath: String?

    enum MemoryEventType: String {
        case fileRead
        case fileEdited
        case fileCreated
        case commandExecuted
        case taskCreated
        case taskCompleted
        case searchPerformed

        var icon: String {
            switch self {
            case .fileRead: return "doc.text"
            case .fileEdited: return "pencil"
            case .fileCreated: return "doc.badge.plus"
            case .commandExecuted: return "terminal"
            case .taskCreated: return "checklist"
            case .taskCompleted: return "checkmark.circle"
            case .searchPerformed: return "magnifyingglass"
            }
        }

        var label: String {
            switch self {
            case .fileRead: return "Read file"
            case .fileEdited: return "Edited file"
            case .fileCreated: return "Created file"
            case .commandExecuted: return "Ran command"
            case .taskCreated: return "Created task"
            case .taskCompleted: return "Completed task"
            case .searchPerformed: return "Searched"
            }
        }

        var color: Color {
            switch self {
            case .fileRead: return .blue
            case .fileEdited: return .orange
            case .fileCreated: return .green
            case .commandExecuted: return .purple
            case .taskCreated: return .teal
            case .taskCompleted: return .green
            case .searchPerformed: return .gray
            }
        }
    }

    init(id: UUID = UUID(), timestamp: Date = Date(), type: MemoryEventType, title: String, detail: String? = nil, filePath: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.title = title
        self.detail = detail
        self.filePath = filePath
    }
}

/// A permission request from the SDK, asking the user to allow/deny a tool use.
struct PermissionRequest: Identifiable {
    let id: String                    // requestId from the bridge
    let toolName: String
    let inputSummary: [String: String]
    let reason: String?
    let workingDirectory: String?
    var status: PermissionStatus = .pending

    enum PermissionStatus {
        case pending, allowed, denied
    }

    /// Human-readable description of what the tool wants to do.
    var displayDescription: String {
        switch toolName {
        case "Bash":
            return inputSummary["command"] ?? "Run a command"
        case "Edit":
            let file = inputSummary["file_path"] ?? "a file"
            return "Edit \(file)"
        case "Write":
            let file = inputSummary["file_path"] ?? "a file"
            let len = inputSummary["contentLength"] ?? "?"
            return "Write to \(file) (\(len) chars)"
        case "Read":
            return "Read \(inputSummary["file_path"] ?? "a file")"
        default:
            return "\(toolName)"
        }
    }

    /// Whether the target path is outside the session working directory.
    /// Uses canonicalized paths to prevent symlink and `../` bypasses,
    /// and appends a trailing slash to avoid prefix collisions
    /// (e.g. `/project` matching `/projectEVIL`).
    var isOutsideWorkingDirectory: Bool {
        guard let cwd = workingDirectory else { return false }
        let filePath = inputSummary["file_path"] ?? inputSummary["path"] ?? ""
        guard !filePath.isEmpty else { return false }

        let canonicalCwd = URL(fileURLWithPath: cwd).standardized.path
            .hasSuffix("/") ? URL(fileURLWithPath: cwd).standardized.path
            : URL(fileURLWithPath: cwd).standardized.path + "/"
        let canonicalFile = URL(fileURLWithPath: filePath).standardized.path

        return !canonicalFile.hasPrefix(canonicalCwd) && canonicalFile != canonicalCwd.dropLast()
    }
}

// MARK: - Session Task

/// Represents a tracked task from Claude's TaskCreate/TaskUpdate tools.
struct SessionTask: Identifiable {
    let id: String                     // Task ID from the tool result (e.g. "1", "2")
    var subject: String
    var status: TaskStatus
    var activeForm: String?            // Present-continuous label (e.g. "Running tests")
    var description: String?
    var blockedBy: [String]?           // IDs of tasks blocking this one

    enum TaskStatus: String {
        case pending
        case in_progress
        case completed
        case deleted
    }
}
