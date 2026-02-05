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

    var contextUsagePercent: Double {
        guard contextTokens > 0 else { return 0 }
        return Double(contextTokens) / Double(settings.model.maxContextTokens)
    }

    // Permission state
    var pendingPermission: PermissionRequest?

    // The current streaming response (built up token by token)
    var currentResponse: String = ""

    // When true, the next token/setText creates a new assistant message
    // (set after a tool completes, so each assistant turn is separate).
    private(set) var needsNewAssistantMessage: Bool = false

    /// Called by SessionManager when data changes that should be persisted.
    var onDataChanged: (() -> Void)?

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
            tasks: tasks.values.map { $0.toData() }
        )
    }

    /// Send a message to Claude.
    func send(_ text: String) {
        guard !text.isEmpty, !isResponding else { return }

        // Add user message
        messages.append(ChatMessage(role: .user, text: text))
        isResponding = true
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
        isCompacting = false
        needsNewAssistantMessage = false
        lastUsage = nil
        totalCost = 0
        tasks.removeAll()
    }

    /// Compact the conversation to free context window space.
    func compact(focusInstructions: String? = nil) {
        guard let sid = sessionId, !isResponding else { return }
        isCompacting = true
        isResponding = true
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

    /// Respond to a pending permission request.
    func respondToPermission(allow: Bool) {
        guard let request = pendingPermission else { return }
        runner.respondToPermission(
            requestId: request.id,
            allow: allow,
            message: allow ? nil : "User denied permission"
        )
        pendingPermission = nil
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

            self.needsNewAssistantMessage = true
            self.onDataChanged?()
        }

        runner.onComplete = { [weak self] fullText, sid, usage in
            guard let self = self else { return }
            self.isResponding = false
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
        }

        runner.onError = { [weak self] error in
            guard let self = self else { return }
            self.isResponding = false
            self.messages.append(ChatMessage(role: .system, text: "Error: \(error)"))
        }

        runner.onPermissionRequest = { [weak self] request in
            guard let self = self else { return }
            self.pendingPermission = request
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
}
