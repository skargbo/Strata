import AppKit
import Foundation

/// Represents a single Claude Code conversation session.
@Observable
final class Session: Identifiable {
    let id: UUID
    var name: String
    var settings: SessionSettings
    var createdAt: Date

    // Backward-compatible accessors
    var workingDirectory: String {
        get { settings.workingDirectory }
        set { settings.workingDirectory = newValue }
    }
    var permissionMode: String {
        get { settings.permissionMode }
        set { settings.permissionMode = newValue }
    }

    // Conversation state
    var messages: [ChatMessage] = []
    var isResponding: Bool = false
    var respondingStartedAt: Date?  // When thinking/responding started (for elapsed time display)
    var sessionId: String? // SDK session ID for conversation continuity
    var totalCost: Double = 0
    var lastUsage: UsageInfo?
    var contextTokens: Int = 0
    var isCompacting: Bool = false

    // Skills cache
    var cachedSkills: [Skill] = []
    var skillsLastScanned: Date? = nil

    // Task tracking
    var tasks: [String: SessionTask] = [:]

    // Memory & context tracking
    var memoryEvents: [MemoryEvent] = []
    var contextBreakdown = ContextBreakdown()
    var filesRead: [String: Int] = [:]  // path -> estimated tokens

    var contextUsagePercent: Double {
        guard contextTokens > 0 else { return 0 }
        return Double(contextTokens) / Double(settings.model.maxContextTokens)
    }

    // Permission state - queue to handle multiple rapid requests
    var pendingPermissions: [PermissionRequest] = []

    var currentPermission: PermissionRequest? {
        pendingPermissions.first
    }

    // The current streaming response (built up token by token)
    var currentResponse: String = ""

    // When true, the next token/setText creates a new assistant message
    // (set after a tool completes, so each assistant turn is separate).
    private(set) var needsNewAssistantMessage: Bool = false

    /// Called by SessionManager when data changes that should be persisted.
    var onDataChanged: (() -> Void)?

    /// External callback when response completes (for ScheduleManager).
    var onComplete: ((String, String?, UsageInfo?) -> Void)?

    /// External callback when an error occurs (for ScheduleManager).
    var onError: ((String) -> Void)?

    private let runner = ClaudeRunner()

    init(
        name: String? = nil,
        workingDirectory: String = NSHomeDirectory()
    ) {
        self.id = UUID()
        self.createdAt = Date()

        // Apply saved default settings if available, otherwise use defaults
        if let defaults = PersistenceManager.shared.loadDefaultSettings() {
            var data = defaults.settings
            data.workingDirectory = workingDirectory
            self.settings = SessionSettings(from: data)
        } else {
            self.settings = SessionSettings(workingDirectory: workingDirectory)
        }

        let dirName = (workingDirectory as NSString).lastPathComponent
        self.name = name ?? "Session \u{2014} \(dirName)"

        setupCallbacks()
    }

    /// Restore from persisted data. The runner is fresh — the first `send()`
    /// reconnects using the saved `sessionId`.
    init(restoring snapshot: SessionSnapshot) {
        self.id = snapshot.id
        self.name = snapshot.name
        self.createdAt = snapshot.createdAt
        self.settings = SessionSettings(from: snapshot.settings)
        self.messages = snapshot.messages.compactMap { ChatMessage.from($0) }
        self.sessionId = snapshot.sessionId
        self.totalCost = snapshot.totalCost
        self.lastUsage = snapshot.lastUsage.map { UsageInfo.from($0) }
        if let taskData = snapshot.tasks {
            for td in taskData {
                let task = SessionTask.from(td)
                self.tasks[task.id] = task
            }
        }
        if let eventData = snapshot.memoryEvents {
            self.memoryEvents = eventData.map { MemoryEvent.from($0) }
        }
        setupCallbacks()
    }

    /// Create a Codable snapshot of the current state.
    func toSnapshot() -> SessionSnapshot {
        SessionSnapshot(
            id: id,
            name: name,
            createdAt: createdAt,
            settings: settings.toData(),
            messages: messages.map { $0.toData() },
            sessionId: sessionId,
            totalCost: totalCost,
            lastUsage: lastUsage?.toData(),
            tasks: tasks.values.map { $0.toData() },
            memoryEvents: memoryEvents.isEmpty ? nil : memoryEvents.map { $0.toData() }
        )
    }

    /// Send a message to Claude.
    func send(_ text: String) {
        guard !text.isEmpty, !isResponding else { return }

        // Add user message
        messages.append(ChatMessage(role: .user, text: text))
        isResponding = true
        respondingStartedAt = Date()
        currentResponse = ""
        needsNewAssistantMessage = false

        // Add placeholder for assistant response
        messages.append(ChatMessage(role: .assistant, text: ""))

        runner.send(
            message: text,
            sessionId: sessionId,
            workingDirectory: settings.workingDirectory,
            permissionMode: settings.permissionMode,
            model: settings.model.rawValue,
            systemPrompt: settings.customSystemPrompt.isEmpty ? nil : settings.customSystemPrompt
        )
    }

    /// Send a skill invocation to Claude.
    /// Displays a clean `/skill-name` in chat but sends the full skill instructions to Claude.
    func sendSkill(_ skill: Skill, arguments: String) {
        guard !isResponding else { return }

        // Clean display text for chat
        let displayText = arguments.isEmpty
            ? "/\(skill.name)"
            : "/\(skill.name) \(arguments)"
        messages.append(ChatMessage(role: .user, text: displayText))

        // Actual message includes skill instructions
        let fullMessage: String
        if arguments.isEmpty {
            fullMessage = """
            Use the following skill instructions to help me:

            \(skill.instructions)
            """
        } else {
            fullMessage = """
            \(arguments)

            Use the following skill instructions:

            \(skill.instructions)
            """
        }

        isResponding = true
        respondingStartedAt = Date()
        currentResponse = ""
        needsNewAssistantMessage = false
        messages.append(ChatMessage(role: .assistant, text: ""))

        runner.send(
            message: fullMessage,
            sessionId: sessionId,
            workingDirectory: settings.workingDirectory,
            permissionMode: settings.permissionMode,
            model: settings.model.rawValue,
            systemPrompt: settings.customSystemPrompt.isEmpty ? nil : settings.customSystemPrompt
        )
    }

    /// Cancel the current response.
    func cancel() {
        runner.cancel()
        isResponding = false
        respondingStartedAt = nil
        needsNewAssistantMessage = false
        if !currentResponse.isEmpty {
            updateLastAssistantMessage(currentResponse + "\n\n*[Cancelled]*")
        } else {
            // Remove empty assistant placeholder
            if let last = messages.last, last.role == .assistant, last.text.isEmpty {
                messages.removeLast()
            }
        }
    }

    /// Clear the conversation and reset session state.
    func clear() {
        runner.cancel()
        messages.removeAll()
        sessionId = nil
        contextTokens = 0
        currentResponse = ""
        isResponding = false
        respondingStartedAt = nil
        isCompacting = false
        needsNewAssistantMessage = false
        lastUsage = nil
        totalCost = 0
        tasks.removeAll()
        pendingPermissions.removeAll()
        memoryEvents.removeAll()
        contextBreakdown = ContextBreakdown()
        filesRead.removeAll()
    }

    /// Compact the conversation to free context window space.
    func compact(focusInstructions: String? = nil) {
        guard let sid = sessionId, !isResponding else { return }
        isCompacting = true
        isResponding = true
        respondingStartedAt = Date()
        currentResponse = ""
        needsNewAssistantMessage = false
        messages.append(ChatMessage(role: .system, text: "Compacting conversation\u{2026}"))
        messages.append(ChatMessage(role: .assistant, text: ""))

        runner.compact(
            sessionId: sid,
            workingDirectory: settings.workingDirectory,
            permissionMode: settings.permissionMode,
            model: settings.model.rawValue,
            focusInstructions: focusInstructions
        )
    }

    /// Scan for available skills and cache the results.
    func scanSkills(force: Bool = false) {
        let now = Date()
        if !force,
           !cachedSkills.isEmpty,
           let lastScan = skillsLastScanned,
           now.timeIntervalSince(lastScan) < 30
        {
            return
        }
        cachedSkills = SkillScanner.scan(workingDirectory: settings.workingDirectory)
        skillsLastScanned = now
        SkillCatalog.shared.markInstalled(localSkills: cachedSkills)
    }

    /// Install a skill from the remote catalog.
    func installCatalogSkill(_ skill: CatalogSkill) throws {
        try SkillCatalog.shared.install(skill)
        scanSkills(force: true)
    }

    /// Uninstall a skill that was installed from the catalog.
    func uninstallCatalogSkill(_ skill: CatalogSkill) throws {
        try SkillCatalog.shared.uninstall(skill)
        scanSkills(force: true)
    }

    /// Match cached skills against recent messages using keyword overlap.
    func suggestedSkills() -> [Skill] {
        guard !cachedSkills.isEmpty else { return [] }

        let recentUserMessages = messages
            .filter { $0.role == .user }
            .suffix(3)
            .map(\.text)

        guard !recentUserMessages.isEmpty else { return [] }

        let messageText = recentUserMessages.joined(separator: " ")
        let messageKeywords = SkillParser.extractKeywords(from: messageText)

        guard !messageKeywords.isEmpty else { return [] }

        let scored: [(Skill, Int)] = cachedSkills
            .filter(\.userInvocable)
            .map { skill in
                let overlap = skill.keywords.intersection(messageKeywords).count
                return (skill, overlap)
            }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }

        return Array(scored.prefix(2).map(\.0))
    }

    /// Respond to the current (first) pending permission request.
    func respondToPermission(allow: Bool) {
        guard let request = pendingPermissions.first else { return }
        runner.respondToPermission(
            requestId: request.id,
            allow: allow,
            message: allow ? nil : "User denied permission"
        )
        pendingPermissions.removeFirst()
    }

    // MARK: - Private

    private func ensureAssistantMessage() {
        if needsNewAssistantMessage {
            messages.append(ChatMessage(role: .assistant, text: ""))
            currentResponse = ""
            needsNewAssistantMessage = false
        }
    }

    private func setupCallbacks() {
        runner.onToken = { [weak self] token in
            guard let self = self else { return }
            self.ensureAssistantMessage()
            self.currentResponse += token
            self.updateLastAssistantMessage(self.currentResponse)
        }

        // Full message snapshot for the current turn — replaces the text.
        runner.onSetText = { [weak self] text in
            guard let self = self else { return }
            self.ensureAssistantMessage()
            self.currentResponse = text
            self.updateLastAssistantMessage(text)
        }

        // A tool has finished — the current assistant turn is complete.
        runner.onTurnComplete = { [weak self] in
            guard let self = self else { return }
            self.needsNewAssistantMessage = true
        }

        // A tool activity with structured data (for inline display).
        runner.onToolActivity = { [weak self] activity in
            guard let self = self else { return }
            self.messages.append(ChatMessage(
                role: .tool,
                text: activity.summaryText,
                toolActivity: activity
            ))

            // Update task state from task tool results
            switch activity.toolName {
            case "TaskCreate", "TaskUpdate", "TaskGet":
                if let task = activity.result.taskResult {
                    if task.status == .deleted {
                        self.tasks.removeValue(forKey: task.id)
                    } else {
                        self.tasks[task.id] = task
                    }
                }
            case "TodoWrite", "TodoUpdate", "TaskList", "TodoRead":
                // TodoWrite returns newTodos array - replace all tasks
                if let list = activity.result.taskListResult {
                    var updated: [String: SessionTask] = [:]
                    for task in list { updated[task.id] = task }
                    self.tasks = updated
                }
            default:
                break
            }

            // Track memory events and context breakdown
            self.trackMemoryEvent(from: activity)

            self.needsNewAssistantMessage = true
            self.onDataChanged?()
        }

        runner.onComplete = { [weak self] fullText, sid, usage in
            guard let self = self else { return }
            self.isResponding = false
            self.respondingStartedAt = nil
            self.playNotificationIfEnabled()

            if let sid = sid {
                self.sessionId = sid
            }

            if let usage = usage {
                self.lastUsage = usage
                self.totalCost = usage.costUSD
                self.contextTokens = usage.contextTokens
            }

            if self.isCompacting {
                self.isCompacting = false
                // Update the compacting system message
                if let idx = self.messages.lastIndex(where: {
                    $0.role == .system && $0.text.contains("Compacting")
                }) {
                    self.messages[idx].text = "Conversation compacted."
                }
            }

            // Update the last assistant message with whatever we have
            if !self.currentResponse.isEmpty {
                self.updateLastAssistantMessage(self.currentResponse)
            }

            // Remove empty trailing assistant placeholder
            if let last = self.messages.last, last.role == .assistant, last.text.isEmpty {
                self.messages.removeLast()
            }

            self.onDataChanged?()

            // Call external completion callback
            self.onComplete?(fullText, sid, usage)
        }

        runner.onError = { [weak self] error in
            guard let self = self else { return }
            self.isResponding = false
            self.respondingStartedAt = nil
            self.messages.append(ChatMessage(role: .system, text: "Error: \(error)"))

            // Call external error callback
            self.onError?(error)
        }

        runner.onPermissionRequest = { [weak self] request in
            guard let self = self else { return }
            self.pendingPermissions.append(request)
            self.playNotificationIfEnabled()
        }
    }

    private func playNotificationIfEnabled() {
        guard settings.soundNotifications else { return }
        settings.notificationSound.play()
    }

    private func updateLastAssistantMessage(_ text: String) {
        // Search backwards — tool/system messages may have been appended
        // after the assistant placeholder.
        if let index = messages.lastIndex(where: { $0.role == .assistant }) {
            messages[index].text = text
        }
    }

    // MARK: - Memory & Context Tracking

    private func trackMemoryEvent(from activity: ToolActivity) {
        let now = Date()

        switch activity.toolName {
        case "Read":
            guard let filePath = activity.input.filePath else { return }
            let fileName = (filePath as NSString).lastPathComponent

            // Estimate tokens from content length
            let contentLength = activity.result.fileContent?.count ?? 0
            let estimatedTokens = max(contentLength / 4, 1)
            filesRead[filePath] = estimatedTokens

            // Update context breakdown
            contextBreakdown.filesInContext.append(ContextBreakdown.FileTokenInfo(
                path: filePath,
                tokens: estimatedTokens,
                timestamp: now
            ))
            contextBreakdown.toolResultTokens += estimatedTokens

            // Create memory event
            let preview = activity.result.fileContent?.prefix(100).description
            memoryEvents.append(MemoryEvent(
                timestamp: now,
                type: .fileRead,
                title: fileName,
                detail: preview,
                filePath: filePath
            ))

        case "Edit":
            guard let filePath = activity.input.filePath else { return }
            let fileName = (filePath as NSString).lastPathComponent

            // Count diff lines for detail
            let adds = activity.result.diffLines?.filter { $0.kind == .addition }.count ?? 0
            let removes = activity.result.diffLines?.filter { $0.kind == .removal }.count ?? 0
            let detail = adds > 0 || removes > 0
                ? "+\(adds) lines, -\(removes) lines"
                : nil

            memoryEvents.append(MemoryEvent(
                timestamp: now,
                type: .fileEdited,
                title: fileName,
                detail: detail,
                filePath: filePath
            ))

        case "Write":
            guard let filePath = activity.input.filePath else { return }
            let fileName = (filePath as NSString).lastPathComponent
            let contentLength = activity.input.content?.count ?? 0

            memoryEvents.append(MemoryEvent(
                timestamp: now,
                type: .fileCreated,
                title: fileName,
                detail: "\(contentLength) characters",
                filePath: filePath
            ))

        case "Bash":
            let command = activity.input.command ?? "command"
            let shortCommand = command.count > 60 ? String(command.prefix(57)) + "..." : command

            // Determine result detail
            var detail: String?
            if activity.result.interrupted {
                detail = "Interrupted"
            } else if let stderr = activity.result.stderr, !stderr.isEmpty {
                detail = "Error: " + String(stderr.prefix(50))
            } else if let stdout = activity.result.stdout {
                let firstLine = stdout.split(separator: "\n").first.map(String.init) ?? ""
                if !firstLine.isEmpty {
                    detail = firstLine.count > 50 ? String(firstLine.prefix(47)) + "..." : firstLine
                }
            }

            // Estimate tokens from output
            let outputLength = (activity.result.stdout?.count ?? 0) + (activity.result.stderr?.count ?? 0)
            contextBreakdown.toolResultTokens += outputLength / 4

            memoryEvents.append(MemoryEvent(
                timestamp: now,
                type: .commandExecuted,
                title: shortCommand,
                detail: detail,
                filePath: nil
            ))

        case "Glob", "Grep":
            let pattern = activity.input.pattern ?? "pattern"
            let count = activity.result.fileCount ?? 0
            let detail = "\(count) match\(count == 1 ? "" : "es")"

            memoryEvents.append(MemoryEvent(
                timestamp: now,
                type: .searchPerformed,
                title: pattern,
                detail: detail,
                filePath: nil
            ))

        case "TaskCreate":
            let subject = activity.input.subject ?? activity.result.taskResult?.subject ?? "task"
            memoryEvents.append(MemoryEvent(
                timestamp: now,
                type: .taskCreated,
                title: subject,
                detail: nil,
                filePath: nil
            ))

        case "TaskUpdate":
            if activity.input.taskStatus == "completed" || activity.result.taskResult?.status == .completed {
                let subject = activity.result.taskResult?.subject ?? "Task #\(activity.input.taskId ?? "?")"
                memoryEvents.append(MemoryEvent(
                    timestamp: now,
                    type: .taskCompleted,
                    title: subject,
                    detail: nil,
                    filePath: nil
                ))
            }

        default:
            break
        }

        // Estimate conversation tokens based on message count
        let conversationCharCount = messages
            .filter { $0.role == .user || $0.role == .assistant }
            .map(\.text.count)
            .reduce(0, +)
        contextBreakdown.conversationTokens = conversationCharCount / 4

        // Estimate system prompt tokens
        if !settings.customSystemPrompt.isEmpty {
            contextBreakdown.systemPromptTokens = settings.customSystemPrompt.count / 4
        }
    }
}
