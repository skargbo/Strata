import Foundation

// MARK: - ChatMessage <-> ChatMessageData

extension ChatMessage {
    func toData() -> ChatMessageData {
        ChatMessageData(
            id: id,
            role: role.persistenceKey,
            text: text,
            timestamp: timestamp,
            toolActivity: toolActivity?.toData()
        )
    }

    static func from(_ data: ChatMessageData) -> ChatMessage? {
        guard let role = Role.from(data.role) else { return nil }
        return ChatMessage(
            id: data.id,
            role: role,
            text: data.text,
            timestamp: data.timestamp,
            toolActivity: data.toolActivity.flatMap { ToolActivity.from($0) }
        )
    }
}

// MARK: - ToolActivity <-> ToolActivityData

extension ToolActivity {
    func toData() -> ToolActivityData {
        ToolActivityData(
            id: id,
            toolName: toolName,
            input: input.toData(),
            result: result.toData()
        )
    }

    static func from(_ data: ToolActivityData) -> ToolActivity {
        ToolActivity(
            toolName: data.toolName,
            input: ToolActivityInput.from(data.input),
            result: ToolActivityResult.from(data.result)
        )
    }
}

// MARK: - ToolActivityInput <-> ToolActivityInputData

extension ToolActivityInput {
    func toData() -> ToolActivityInputData {
        ToolActivityInputData(
            filePath: filePath,
            command: command,
            description: description,
            oldString: oldString,
            newString: newString,
            content: content,
            pattern: pattern,
            path: path,
            rawJSON: Self.encodeRawDictionary(raw)
        )
    }

    static func from(_ data: ToolActivityInputData) -> ToolActivityInput {
        ToolActivityInput(
            filePath: data.filePath,
            command: data.command,
            description: data.description,
            oldString: data.oldString,
            newString: data.newString,
            content: data.content,
            pattern: data.pattern,
            path: data.path,
            raw: decodeRawDictionary(data.rawJSON)
        )
    }

    private static func encodeRawDictionary(_ dict: [String: Any]) -> String? {
        guard !dict.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: dict)
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func decodeRawDictionary(_ json: String?) -> [String: Any] {
        guard let json, let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return obj
    }
}

// MARK: - ToolActivityResult <-> ToolActivityResultData

extension ToolActivityResult {
    func toData() -> ToolActivityResultData {
        ToolActivityResultData(
            stdout: stdout,
            stderr: stderr,
            interrupted: interrupted,
            fileContent: fileContent,
            filenames: filenames,
            fileCount: fileCount,
            diffLines: diffLines?.map { $0.toData() },
            rawJSON: Self.encodeRawValue(raw)
        )
    }

    static func from(_ data: ToolActivityResultData) -> ToolActivityResult {
        ToolActivityResult(
            stdout: data.stdout,
            stderr: data.stderr,
            interrupted: data.interrupted,
            fileContent: data.fileContent,
            filenames: data.filenames,
            fileCount: data.fileCount,
            diffLines: data.diffLines?.map { DiffLine.from($0) },
            raw: decodeRawValue(data.rawJSON)
        )
    }

    private static func encodeRawValue(_ value: Any?) -> String? {
        guard let value else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: [value])
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func decodeRawValue(_ json: String?) -> Any? {
        guard let json, let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [Any]
        else { return nil }
        return arr.first
    }
}

// MARK: - DiffLine <-> DiffLineData

extension DiffLine {
    func toData() -> DiffLineData {
        DiffLineData(kind: kind.persistenceKey, text: text, lineNumber: lineNumber)
    }

    static func from(_ data: DiffLineData) -> DiffLine {
        DiffLine(kind: DiffLineKind.from(data.kind), text: data.text, lineNumber: data.lineNumber)
    }
}

// MARK: - UsageInfo <-> UsageInfoData

extension UsageInfo {
    func toData() -> UsageInfoData {
        UsageInfoData(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheReadTokens: cacheReadTokens,
            cacheCreationTokens: cacheCreationTokens,
            costUSD: costUSD,
            durationMs: durationMs,
            contextTokens: contextTokens
        )
    }

    static func from(_ data: UsageInfoData) -> UsageInfo {
        UsageInfo(
            inputTokens: data.inputTokens,
            outputTokens: data.outputTokens,
            cacheReadTokens: data.cacheReadTokens,
            cacheCreationTokens: data.cacheCreationTokens,
            costUSD: data.costUSD,
            durationMs: data.durationMs,
            contextTokens: data.contextTokens
        )
    }
}
