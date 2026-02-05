import Foundation

/// Scans and manages Claude Code memory files
struct MemoryScanner {
    /// Scan all memory files for a given working directory
    static func scan(workingDirectory: String) -> [MemoryFile] {
        var files: [MemoryFile] = []
        let fm = FileManager.default

        // 1. User-level: ~/.claude/CLAUDE.md
        let userPath = (NSHomeDirectory() as NSString)
            .appendingPathComponent(".claude/CLAUDE.md")
        files.append(loadFile(path: userPath, level: .user, name: "User Memory"))

        // 2. Project-level: Check both ./CLAUDE.md and ./.claude/CLAUDE.md
        let projectRoot = (workingDirectory as NSString)
            .appendingPathComponent("CLAUDE.md")
        let projectDotClaude = (workingDirectory as NSString)
            .appendingPathComponent(".claude/CLAUDE.md")

        // Prefer .claude/CLAUDE.md if it exists, otherwise use root CLAUDE.md
        if fm.fileExists(atPath: projectDotClaude) {
            files.append(loadFile(path: projectDotClaude, level: .project, name: "Project Memory"))
        } else {
            files.append(loadFile(path: projectRoot, level: .project, name: "Project Memory"))
        }

        // 3. Rules: ./.claude/rules/*.md
        let rulesDir = (workingDirectory as NSString)
            .appendingPathComponent(".claude/rules")
        if let entries = try? fm.contentsOfDirectory(atPath: rulesDir) {
            for entry in entries.sorted() where entry.hasSuffix(".md") {
                let rulePath = (rulesDir as NSString).appendingPathComponent(entry)
                let ruleName = (entry as NSString).deletingPathExtension
                files.append(loadFile(path: rulePath, level: .rules, name: ruleName))
            }
        }

        // 4. Local: ./CLAUDE.local.md
        let localPath = (workingDirectory as NSString)
            .appendingPathComponent("CLAUDE.local.md")
        files.append(loadFile(path: localPath, level: .local, name: "Local Memory"))

        return files
    }

    /// Load a single memory file from disk
    private static func loadFile(path: String, level: MemoryFileLevel, name: String) -> MemoryFile {
        var file = MemoryFile(level: level, path: path, name: name)
        if let content = try? String(contentsOfFile: path, encoding: .utf8) {
            file.content = content
            file.exists = true
        }
        return file
    }

    /// Save a memory file to disk
    static func save(_ file: MemoryFile) throws {
        let fm = FileManager.default
        let dir = (file.path as NSString).deletingLastPathComponent

        // Ensure parent directory exists
        if !fm.fileExists(atPath: dir) {
            try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }

        try file.content.write(toFile: file.path, atomically: true, encoding: .utf8)
    }

    /// Delete a memory file from disk
    static func delete(_ file: MemoryFile) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: file.path) {
            try fm.removeItem(atPath: file.path)
        }
    }

    /// Create a new rules file (doesn't save to disk yet)
    static func createRuleFile(workingDirectory: String, name: String) -> MemoryFile {
        let rulesDir = (workingDirectory as NSString)
            .appendingPathComponent(".claude/rules")

        let sanitizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileName = sanitizedName.hasSuffix(".md") ? sanitizedName : "\(sanitizedName).md"
        let path = (rulesDir as NSString).appendingPathComponent(fileName)

        var file = MemoryFile(
            level: .rules,
            path: path,
            name: (fileName as NSString).deletingPathExtension
        )
        file.content = "# \(sanitizedName)\n\n"
        file.exists = false
        file.isModified = true
        return file
    }

    /// Check if a rules directory exists for the working directory
    static func rulesDirectoryExists(workingDirectory: String) -> Bool {
        let rulesDir = (workingDirectory as NSString)
            .appendingPathComponent(".claude/rules")
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: rulesDir, isDirectory: &isDir) && isDir.boolValue
    }
}
