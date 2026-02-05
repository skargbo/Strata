import Foundation

/// Represents the hierarchy level of a memory file
enum MemoryFileLevel: String, CaseIterable {
    case user = "User"
    case project = "Project"
    case rules = "Rules"
    case local = "Local"

    var icon: String {
        switch self {
        case .user: return "person.circle"
        case .project: return "folder.circle"
        case .rules: return "list.bullet.rectangle"
        case .local: return "lock.circle"
        }
    }

    var description: String {
        switch self {
        case .user: return "Global preferences across all projects"
        case .project: return "Project-specific instructions"
        case .rules: return "Modular topic-specific rules"
        case .local: return "Private local overrides (gitignored)"
        }
    }
}

/// Represents a Claude Code memory file (CLAUDE.md or rules file)
struct MemoryFile: Identifiable, Hashable {
    let id: String              // Unique identifier (path-based)
    let level: MemoryFileLevel
    let path: String            // Absolute path
    let name: String            // Display name (filename or rule name)
    var content: String         // File content (empty if doesn't exist)
    var exists: Bool            // Whether file exists on disk
    var isModified: Bool        // Unsaved changes flag

    init(level: MemoryFileLevel, path: String, name: String) {
        self.id = path
        self.level = level
        self.path = path
        self.name = name
        self.content = ""
        self.exists = false
        self.isModified = false
    }

    /// Returns the relative path from working directory (for display)
    func relativePath(from workingDirectory: String) -> String {
        if path.hasPrefix(workingDirectory) {
            let relative = String(path.dropFirst(workingDirectory.count))
            return relative.hasPrefix("/") ? String(relative.dropFirst()) : relative
        }
        return path
    }
}
