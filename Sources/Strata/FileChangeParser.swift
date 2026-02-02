import Foundation

// MARK: - Models

enum FileChangeAction: String {
    case update = "Update"
    case write = "Write"
    case read = "Read"
    case create = "Create"
    case delete = "Delete"
}

enum DiffLineKind {
    case addition
    case removal
    case context
    case ellipsis

    var persistenceKey: String {
        switch self {
        case .addition: "addition"
        case .removal: "removal"
        case .context: "context"
        case .ellipsis: "ellipsis"
        }
    }

    static func from(_ key: String) -> DiffLineKind {
        switch key {
        case "addition": .addition
        case "removal": .removal
        case "context": .context
        default: .ellipsis
        }
    }
}

struct DiffLine: Identifiable {
    let id = UUID()
    let kind: DiffLineKind
    let text: String
    let lineNumber: Int?
}

struct FileChange: Identifiable {
    let id = UUID()
    let action: FileChangeAction
    let filePath: String
    let summaryLine: String
    let diffLines: [DiffLine]

    var fileName: String {
        (filePath as NSString).lastPathComponent
    }
}

// MARK: - Parser

struct FileChangeParser {
    private static let actionKeywords: [String: FileChangeAction] = [
        "Update": .update,
        "Write": .write,
        "Read": .read,
        "Create": .create,
        "Delete": .delete,
    ]

    /// Extract all file change blocks from message text.
    static func parse(_ text: String) -> [FileChange] {
        stripFileChanges(text).changes
    }

    /// Return the text with file change blocks replaced by placeholder tokens,
    /// plus the extracted changes.
    static func stripFileChanges(_ text: String) -> (stripped: String, changes: [FileChange]) {
        let lines = text.components(separatedBy: "\n")
        var changes: [FileChange] = []
        var outputLines: [String] = []
        var i = 0

        while i < lines.count {
            if let (change, consumed) = tryParseChangeBlock(lines: lines, startIndex: i) {
                changes.append(change)
                outputLines.append("\u{FFFC}FILECHANGE:\(changes.count - 1)\u{FFFC}")
                i += consumed
            } else {
                outputLines.append(lines[i])
                i += 1
            }
        }

        return (outputLines.joined(separator: "\n"), changes)
    }

    // MARK: - Private

    /// Try to parse a file change block starting at the given line index.
    /// Returns the parsed FileChange and the number of lines consumed, or nil.
    private static func tryParseChangeBlock(lines: [String], startIndex: Int) -> (FileChange, Int)? {
        let headerLine = lines[startIndex].trimmingCharacters(in: .whitespaces)

        // Match: Action(filepath)
        guard let (action, filePath) = parseActionHeader(headerLine) else {
            return nil
        }

        var consumed = 1
        var summaryLine = ""
        var diffLines: [DiffLine] = []

        // Next line should be the summary with ⎿
        let nextIdx = startIndex + consumed
        if nextIdx < lines.count && lines[nextIdx].contains("\u{23BF}") {
            // Extract summary text after ⎿
            let parts = lines[nextIdx].components(separatedBy: "\u{23BF}")
            if parts.count > 1 {
                summaryLine = parts[1].trimmingCharacters(in: .whitespaces)
            }
            consumed += 1
        }

        // Collect diff content lines
        while startIndex + consumed < lines.count {
            let line = lines[startIndex + consumed]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Stop conditions
            if trimmed.isEmpty { break }
            if parseActionHeader(trimmed) != nil { break }

            // Check for ellipsis
            if trimmed == "..." {
                diffLines.append(DiffLine(kind: .ellipsis, text: "...", lineNumber: nil))
                consumed += 1
                continue
            }

            // Try to parse as a diff line (leading whitespace + line number + content)
            if let diffLine = parseDiffLine(line) {
                diffLines.append(diffLine)
                consumed += 1
            } else {
                break
            }
        }

        // Skip trailing blank line if present
        if startIndex + consumed < lines.count &&
            lines[startIndex + consumed].trimmingCharacters(in: .whitespaces).isEmpty {
            consumed += 1
        }

        let change = FileChange(
            action: action,
            filePath: filePath,
            summaryLine: summaryLine,
            diffLines: diffLines
        )
        return (change, consumed)
    }

    /// Parse action header like "Update(path/to/file.swift)"
    private static func parseActionHeader(_ line: String) -> (FileChangeAction, String)? {
        for (keyword, action) in actionKeywords {
            if line.hasPrefix("\(keyword)(") && line.hasSuffix(")") {
                let start = line.index(line.startIndex, offsetBy: keyword.count + 1)
                let end = line.index(before: line.endIndex)
                let path = String(line[start..<end])
                if !path.isEmpty {
                    return (action, path)
                }
            }
        }
        return nil
    }

    /// Compute diff lines from an old/new string replacement (used by ToolActivityRow).
    static func diffFromEdit(oldString: String, newString: String) -> [DiffLine] {
        var lines: [DiffLine] = []
        let oldLines = oldString.components(separatedBy: "\n")
        let newLines = newString.components(separatedBy: "\n")

        for (i, line) in oldLines.enumerated() {
            lines.append(DiffLine(kind: .removal, text: line, lineNumber: i + 1))
        }
        for (i, line) in newLines.enumerated() {
            lines.append(DiffLine(kind: .addition, text: line, lineNumber: i + 1))
        }
        return lines
    }

    /// Parse a single diff content line.
    /// Format: "      38 -  code" or "      38 +  code" or "      38    code"
    private static func parseDiffLine(_ rawLine: String) -> DiffLine? {
        // Must start with whitespace
        guard let first = rawLine.first, first == " " || first == "\t" else {
            return nil
        }

        let stripped = rawLine.drop(while: { $0 == " " || $0 == "\t" })
        guard !stripped.isEmpty else { return nil }

        // Extract line number (leading digits)
        var numStr = ""
        var rest = stripped[stripped.startIndex...]
        while let ch = rest.first, ch.isNumber {
            numStr.append(ch)
            rest = rest[rest.index(after: rest.startIndex)...]
        }

        guard !numStr.isEmpty, let lineNum = Int(numStr) else {
            return nil
        }

        // After the number, expect at least one space
        guard let nextChar = rest.first, nextChar == " " else {
            return nil
        }
        rest = rest[rest.index(after: rest.startIndex)...]

        // Check for +/- indicator
        if let indicator = rest.first {
            if indicator == "-" {
                let content = String(rest.dropFirst()).trimmingCharacters(in: .init(charactersIn: " "))
                return DiffLine(kind: .removal, text: content, lineNumber: lineNum)
            }
            if indicator == "+" {
                let content = String(rest.dropFirst()).trimmingCharacters(in: .init(charactersIn: " "))
                return DiffLine(kind: .addition, text: content, lineNumber: lineNum)
            }
        }

        // Context line
        let content = String(rest)
        return DiffLine(kind: .context, text: content, lineNumber: lineNum)
    }
}
