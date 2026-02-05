import Foundation

/// Runs a Node.js bridge process that uses the Claude Agent SDK.
/// Communicates via newline-delimited JSON on stdin/stdout.
final class ClaudeRunner: @unchecked Sendable {
    private var process: Process?
    private var stdinPipe: Pipe?
    private let readQueue = DispatchQueue(label: "com.strata.runner.read", qos: .userInteractive)

    var onToken: ((String) -> Void)?
    var onSetText: ((String) -> Void)?
    var onTurnComplete: (() -> Void)?
    var onToolActivity: ((ToolActivity) -> Void)?
    var onComplete: ((String, String?, UsageInfo?) -> Void)?
    var onError: ((String) -> Void)?
    var onPermissionRequest: ((PermissionRequest) -> Void)?
    var onDebug: ((String) -> Void)?

    private(set) var isRunning = false
    private var currentWorkingDirectory: String?
    private var expectedNonce: String?
    private var nonceValidated = false

    /// Start the Node.js bridge process.
    func startBridge() {
        guard process == nil else { return }

        guard let nodePath = Self.findNode() else {
            onError?("Node.js not found. Install from https://nodejs.org")
            return
        }

        guard let bridgePath = Self.findBridgeScript() else {
            onError?("claude-bridge.mjs not found. Run npm install in Resources/.")
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: nodePath)
        proc.arguments = [bridgePath]

        // Set working directory to bridge script's directory so node_modules resolves
        let bridgeDir = (bridgePath as NSString).deletingLastPathComponent
        proc.currentDirectoryURL = URL(fileURLWithPath: bridgeDir)

        // Allowlist environment variables — avoid leaking secrets (AWS keys, tokens, etc.)
        let allowedKeys = [
            "PATH", "HOME", "USER", "LOGNAME", "SHELL", "TMPDIR",
            "ANTHROPIC_API_KEY",
            "NODE_PATH", "NVM_DIR",
            "LANG", "LC_ALL", "LC_CTYPE"
        ]
        let fullEnv = ProcessInfo.processInfo.environment
        var safeEnv: [String: String] = [:]
        for key in allowedKeys {
            if let value = fullEnv[key] {
                safeEnv[key] = value
            }
        }
        safeEnv["TERM"] = "dumb"
        safeEnv["NO_COLOR"] = "1"

        // Generate a startup nonce for bridge authentication
        let nonce = UUID().uuidString
        safeEnv["STRATA_BRIDGE_NONCE"] = nonce
        self.expectedNonce = nonce
        self.nonceValidated = false

        proc.environment = safeEnv

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        self.stdinPipe = stdin
        self.process = proc

        // Read stdout asynchronously
        let outHandle = stdout.fileHandleForReading
        readQueue.async { [weak self] in
            var accumulated = ""
            while true {
                let data = outHandle.availableData
                if data.isEmpty { break } // EOF

                guard let chunk = String(data: data, encoding: .utf8) else { continue }
                let combined = accumulated + chunk
                let lines = combined.components(separatedBy: "\n")

                for (i, line) in lines.enumerated() {
                    if i == lines.count - 1 && !combined.hasSuffix("\n") {
                        accumulated = line
                        continue
                    }
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        self?.processLine(trimmed)
                    }
                }
                if combined.hasSuffix("\n") {
                    accumulated = ""
                }
            }
        }

        // Read stderr — only for debug logging, NOT treated as errors.
        // The SDK and Claude Code produce plenty of stderr output (progress, warnings, etc.)
        let errHandle = stderr.fileHandleForReading
        readQueue.async {
            while true {
                let data = errHandle.availableData
                if data.isEmpty { break }
                // Silently consume stderr; bridge uses stdout JSON for all real communication.
            }
        }

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.process = nil
                self?.stdinPipe = nil
                self?.expectedNonce = nil
                self?.nonceValidated = false
                if self?.isRunning == true {
                    self?.isRunning = false
                    self?.onError?("Bridge process terminated unexpectedly.")
                }
            }
        }

        do {
            try proc.run()
        } catch {
            onError?("Failed to start bridge: \(error.localizedDescription)")
        }
    }

    /// Send a message to Claude via the bridge.
    func send(
        message: String,
        sessionId: String? = nil,
        workingDirectory: String = NSHomeDirectory(),
        permissionMode: String = "default",
        model: String? = nil,
        systemPrompt: String? = nil
    ) {
        guard process != nil else {
            startBridge()
            // Retry after a short delay to let the process start
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.send(
                    message: message,
                    sessionId: sessionId,
                    workingDirectory: workingDirectory,
                    permissionMode: permissionMode,
                    model: model,
                    systemPrompt: systemPrompt
                )
            }
            return
        }

        guard !isRunning else {
            onError?("A request is already in progress.")
            return
        }

        // Validate and canonicalize working directory
        guard let validatedCwd = Self.validateWorkingDirectory(workingDirectory) else {
            onError?("Invalid working directory: \(workingDirectory)")
            return
        }

        isRunning = true
        currentWorkingDirectory = validatedCwd

        var command: [String: Any] = [
            "type": "query",
            "prompt": message,
            "cwd": validatedCwd,
            "permissionMode": permissionMode,
        ]
        if let sid = sessionId {
            command["sessionId"] = sid
        }
        if let model = model {
            command["model"] = model
        }
        if let systemPrompt = systemPrompt {
            command["systemPrompt"] = systemPrompt
        }

        writeJSON(command)
    }

    /// Respond to a permission request.
    func respondToPermission(requestId: String, allow: Bool, message: String? = nil) {
        var response: [String: Any] = [
            "type": "permission_response",
            "requestId": requestId,
            "behavior": allow ? "allow" : "deny",
        ]
        if let msg = message {
            response["message"] = msg
        }
        writeJSON(response)
    }

    /// Send a compact request to summarize the conversation.
    func compact(
        sessionId: String,
        workingDirectory: String,
        permissionMode: String = "default",
        model: String? = nil,
        focusInstructions: String? = nil
    ) {
        var command: [String: Any] = [
            "type": "compact",
            "sessionId": sessionId,
            "cwd": workingDirectory,
            "permissionMode": permissionMode,
        ]
        if let model = model {
            command["model"] = model
        }
        if let focus = focusInstructions, !focus.isEmpty {
            command["focusInstructions"] = focus
        }
        isRunning = true
        writeJSON(command)
    }

    /// Cancel the current request.
    func cancel() {
        writeJSON(["type": "cancel"])
        isRunning = false
    }

    /// Shut down the bridge process.
    func shutdown() {
        stdinPipe?.fileHandleForWriting.closeFile()
        process?.terminate()
        process = nil
        stdinPipe = nil
        isRunning = false
        expectedNonce = nil
        nonceValidated = false
    }

    // MARK: - Validation

    /// Canonicalize and validate a working directory path.
    /// Resolves symlinks, rejects null bytes, and verifies the directory exists.
    private static func validateWorkingDirectory(_ path: String) -> String? {
        guard !path.contains("\0") else { return nil }
        let resolved = (path as NSString).resolvingSymlinksInPath
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir),
              isDir.boolValue else { return nil }
        return resolved
    }

    // MARK: - Private

    private func writeJSON(_ obj: [String: Any]) {
        guard let handle = stdinPipe?.fileHandleForWriting,
              let data = try? JSONSerialization.data(withJSONObject: obj),
              let jsonStr = String(data: data, encoding: .utf8) else {
            return
        }
        let line = jsonStr + "\n"
        if let lineData = line.data(using: .utf8) {
            handle.write(lineData)
        }
    }

    private func processLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            #if DEBUG
            NSLog("[bridge] Malformed JSON line: %@", String(line.prefix(200)))
            #endif
            return
        }

        // The first message from the bridge must echo back the startup nonce
        if !nonceValidated {
            guard type == "ready",
                  let echoedNonce = json["nonce"] as? String,
                  echoedNonce == expectedNonce else {
                DispatchQueue.main.async { [weak self] in
                    self?.shutdown()
                    self?.onError?("Bridge authentication failed.")
                }
                return
            }
            nonceValidated = true
            return
        }

        switch type {
        case "token":
            if let text = json["text"] as? String {
                DispatchQueue.main.async { [weak self] in
                    self?.onToken?(text)
                }
            }

        case "set_text":
            // Full message snapshot — replaces (not appends) the response
            if let text = json["text"] as? String {
                DispatchQueue.main.async { [weak self] in
                    self?.onSetText?(text)
                }
            }

        case "permission_request":
            if let requestId = json["requestId"] as? String,
               let toolName = json["toolName"] as? String {

                var inputSummary: [String: String] = [:]
                if let input = json["input"] as? [String: Any] {
                    for (k, v) in input {
                        inputSummary[k] = "\(v)"
                    }
                }

                let reason = json["reason"] as? String

                let request = PermissionRequest(
                    id: requestId,
                    toolName: toolName,
                    inputSummary: inputSummary,
                    reason: reason,
                    workingDirectory: currentWorkingDirectory
                )

                DispatchQueue.main.async { [weak self] in
                    self?.onPermissionRequest?(request)
                }
            }

        case "result":
            let resultText = json["text"] as? String ?? ""
            let sid = json["sessionId"] as? String

            var usage: UsageInfo?
            if let usageDict = json["usage"] as? [String: Any] {
                var info = UsageInfo()
                info.inputTokens = usageDict["inputTokens"] as? Int ?? 0
                info.outputTokens = usageDict["outputTokens"] as? Int ?? 0
                info.cacheReadTokens = usageDict["cacheReadTokens"] as? Int ?? 0
                info.cacheCreationTokens = usageDict["cacheCreationTokens"] as? Int ?? 0
                info.costUSD = json["costUSD"] as? Double ?? 0
                info.durationMs = json["durationMs"] as? Int ?? 0
                info.contextTokens = json["contextTokens"] as? Int ?? 0
                usage = info
            }

            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
                self?.onComplete?(resultText, sid, usage)
            }

        case "error":
            let message = json["message"] as? String ?? "Unknown error"
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
                self?.onError?(message)
            }

        case "turn_complete":
            DispatchQueue.main.async { [weak self] in
                self?.onTurnComplete?()
            }

        case "tool_activity":
            let toolName = json["toolName"] as? String ?? "Unknown"
            let inputDict = json["input"] as? [String: Any] ?? [:]
            let resultData = json["result"]

            let input = Self.parseToolInput(toolName: toolName, dict: inputDict)
            let result = Self.parseToolResult(toolName: toolName, data: resultData)

            let activity = ToolActivity(
                toolName: toolName,
                input: input,
                result: result
            )

            DispatchQueue.main.async { [weak self] in
                self?.onToolActivity?(activity)
            }

        case "tool_progress", "tool_use_summary":
            break

        case "debug":
            if let message = json["message"] as? String {
                #if DEBUG
                NSLog("[bridge debug] %@", message)
                #endif
                DispatchQueue.main.async { [weak self] in
                    self?.onDebug?(message)
                }
            }

        default:
            break
        }
    }

    // MARK: - Tool Activity Parsing

    private static func parseToolInput(toolName: String, dict: [String: Any]) -> ToolActivityInput {
        var input = ToolActivityInput()
        input.filePath = dict["file_path"] as? String
        input.command = dict["command"] as? String
        input.description = dict["description"] as? String
        input.oldString = dict["old_string"] as? String
        input.newString = dict["new_string"] as? String
        input.content = dict["content"] as? String
        input.pattern = dict["pattern"] as? String
        input.path = dict["path"] as? String
        input.raw = dict

        // Task tool fields
        input.subject = dict["subject"] as? String
        input.taskId = dict["taskId"] as? String
        input.taskStatus = dict["status"] as? String
        input.activeForm = dict["activeForm"] as? String

        return input
    }

    private static func parseToolResult(toolName: String, data: Any?) -> ToolActivityResult {
        var result = ToolActivityResult()

        if let str = data as? String {
            // Some tools return a plain string result
            result.stdout = str
            return result
        }

        guard let dict = data as? [String: Any] else {
            result.raw = data
            return result
        }

        switch toolName {
        case "Bash":
            result.stdout = dict["stdout"] as? String
            result.stderr = dict["stderr"] as? String
            result.interrupted = dict["interrupted"] as? Bool ?? false

        case "Edit":
            // Compute diff from input old/new strings
            let oldStr = dict["oldString"] as? String ?? ""
            let newStr = dict["newString"] as? String ?? ""
            if !oldStr.isEmpty || !newStr.isEmpty {
                result.diffLines = FileChangeParser.diffFromEdit(
                    oldString: oldStr,
                    newString: newStr
                )
            }

        case "Read":
            if let file = dict["file"] as? [String: Any] {
                result.fileContent = file["content"] as? String
            } else if let content = dict["content"] as? String {
                result.fileContent = content
            }

        case "Write":
            // Write results don't have much to show
            break

        case "Glob":
            result.filenames = dict["filenames"] as? [String]
            result.fileCount = dict["numFiles"] as? Int

        case "Grep":
            result.filenames = dict["filenames"] as? [String]
            result.fileCount = dict["numFiles"] as? Int

        case "TaskCreate", "TaskUpdate", "TaskGet":
            result.taskResult = Self.parseSessionTask(dict)

        case "TodoWrite", "TodoUpdate":
            // TodoWrite uses newTodos array with content/activeForm/status fields
            if let newTodos = dict["newTodos"] as? [[String: Any]] {
                result.taskListResult = newTodos.enumerated().compactMap { index, todo in
                    Self.parseTodoItem(todo, index: index)
                }
            }

        case "TaskList", "TodoRead":
            // Result may be array directly or nested under a key
            if let arr = data as? [[String: Any]] {
                result.taskListResult = arr.compactMap { Self.parseSessionTask($0) }
            } else if let tasks = dict["tasks"] as? [[String: Any]] {
                result.taskListResult = tasks.compactMap { Self.parseSessionTask($0) }
            } else if let newTodos = dict["newTodos"] as? [[String: Any]] {
                result.taskListResult = newTodos.enumerated().compactMap { index, todo in
                    Self.parseTodoItem(todo, index: index)
                }
            }

        default:
            result.raw = data
        }

        return result
    }

    private static func parseSessionTask(_ dict: [String: Any]) -> SessionTask? {
        // ID is required, but subject can have a fallback
        guard let id = (dict["id"] as? String) ?? (dict["id"] as? Int).map({ String($0) })
                ?? (dict["taskId"] as? String) else { return nil }
        let subject = dict["subject"] as? String ?? dict["title"] as? String ?? "Task #\(id)"
        return SessionTask(
            id: id,
            subject: subject,
            status: SessionTask.TaskStatus(rawValue: dict["status"] as? String ?? "pending") ?? .pending,
            activeForm: dict["activeForm"] as? String,
            description: dict["description"] as? String,
            blockedBy: dict["blockedBy"] as? [String]
        )
    }

    /// Parse a todo item from the SDK's TodoWrite format (content/activeForm/status, no id)
    private static func parseTodoItem(_ dict: [String: Any], index: Int) -> SessionTask? {
        let content = dict["content"] as? String ?? "Task \(index + 1)"
        let statusStr = dict["status"] as? String ?? "pending"
        let status = SessionTask.TaskStatus(rawValue: statusStr) ?? .pending
        return SessionTask(
            id: String(index + 1),
            subject: content,
            status: status,
            activeForm: dict["activeForm"] as? String,
            description: nil,
            blockedBy: nil
        )
    }

    // MARK: - Path Resolution

    private static func findNode() -> String? {
        let paths = [
            "/usr/local/bin/node",
            "/opt/homebrew/bin/node",
            "\(NSHomeDirectory())/.nvm/versions/node",
            "/usr/bin/node",
        ]

        // Check direct paths first
        for path in paths {
            if path.contains(".nvm") {
                // For nvm, find the current default
                if let nvmNode = findNvmNode() {
                    return nvmNode
                }
                continue
            }
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Check PATH
        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/local/bin:/usr/bin:/bin"
        for dir in pathEnv.split(separator: ":") {
            let nodePath = "\(dir)/node"
            if FileManager.default.isExecutableFile(atPath: nodePath) {
                return nodePath
            }
        }
        return nil
    }

    private static func findNvmNode() -> String? {
        let nvmDir = "\(NSHomeDirectory())/.nvm/versions/node"
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: nvmDir) else {
            return nil
        }
        // Pick the latest version
        let sorted = contents.sorted { $0.compare($1, options: .numeric) == .orderedDescending }
        if let latest = sorted.first {
            let nodePath = "\(nvmDir)/\(latest)/bin/node"
            if FileManager.default.isExecutableFile(atPath: nodePath) {
                return nodePath
            }
        }
        return nil
    }

    private static func findBridgeScript() -> String? {
        // 1. Look relative to this source file → project root / bridge/
        let sourceDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let projectRoot = sourceDir
            .deletingLastPathComponent()  // Sources/
            .deletingLastPathComponent()  // project root
        let devPath = projectRoot.appendingPathComponent("bridge/claude-bridge.mjs").path
        if FileManager.default.fileExists(atPath: devPath) {
            return devPath
        }

        // 2. Look in Bundle.main (packaged app)
        if let bundledURL = Bundle.main.url(
            forResource: "claude-bridge",
            withExtension: "mjs",
            subdirectory: "bridge"
        ) {
            return bundledURL.path
        }

        // 3. Look next to the executable
        if let execURL = Bundle.main.executableURL {
            let siblingPath = execURL
                .deletingLastPathComponent()
                .appendingPathComponent("bridge/claude-bridge.mjs")
                .path
            if FileManager.default.fileExists(atPath: siblingPath) {
                return siblingPath
            }
        }

        return nil
    }
}
