import Foundation

// MARK: - Skill Model

struct Skill: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let argumentHint: String?
    let userInvocable: Bool
    let instructions: String
    let source: SkillSource
    let filePath: String
    let keywords: Set<String>

    enum SkillSource: String, Hashable {
        case personal
        case project
    }
}

// MARK: - Skill Parser

struct SkillParser {
    /// Parse a SKILL.md file into a Skill struct.
    /// Uses plain string operations — no YAML library.
    static func parse(content: String, directoryName: String, filePath: String, source: Skill.SkillSource) -> Skill? {
        let lines = content.components(separatedBy: "\n")

        // Find frontmatter delimiters (lines that are exactly "---")
        guard let firstDelim = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return nil
        }
        let searchStart = lines.index(after: firstDelim)
        guard searchStart < lines.count,
              let secondDelim = lines[searchStart...].firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" })
        else {
            return nil
        }

        // Parse key-value pairs between delimiters
        var fields: [String: String] = [:]
        for i in (firstDelim + 1)..<secondDelim {
            let line = lines[i]
            guard let colonIdx = line.firstIndex(of: ":") else { continue }
            let key = String(line[line.startIndex..<colonIdx])
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            var value = String(line[line.index(after: colonIdx)...])
                .trimmingCharacters(in: .whitespaces)
            // Strip surrounding quotes
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            fields[key] = value
        }

        let name = fields["name"] ?? directoryName
        let description = fields["description"] ?? ""
        let argumentHint = fields["argument-hint"]
        let userInvocable = fields["user-invocable"]?.lowercased() != "false"

        // Markdown body after second ---
        let bodyStart = lines.index(after: secondDelim)
        let instructions: String
        if bodyStart < lines.count {
            instructions = lines[bodyStart...].joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            instructions = ""
        }

        let keywords = extractKeywords(from: description)
        let skillId = "\(source.rawValue)-\(name)"

        return Skill(
            id: skillId,
            name: name,
            description: description,
            argumentHint: argumentHint,
            userInvocable: userInvocable,
            instructions: instructions,
            source: source,
            filePath: filePath,
            keywords: keywords
        )
    }

    /// Extract meaningful keywords from text for matching.
    static func extractKeywords(from text: String) -> Set<String> {
        let stopwords: Set<String> = [
            "this", "that", "what", "when", "where", "which", "with",
            "from", "into", "have", "does", "will", "would", "could",
            "should", "been", "being", "about", "also", "they", "them",
            "then", "than", "each", "make", "made", "like", "just",
            "over", "such", "some", "only", "very", "more", "most",
            "your", "their", "other", "after", "before", "used", "using",
        ]

        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 && !stopwords.contains($0) }

        return Set(words)
    }
}

// MARK: - Skill Scanner

struct SkillScanner {
    /// Scan personal and project skill directories for SKILL.md files.
    static func scan(workingDirectory: String) -> [Skill] {
        var skills: [Skill] = []
        let fm = FileManager.default

        // Personal: ~/.claude/skills/
        let personalDir = (NSHomeDirectory() as NSString)
            .appendingPathComponent(".claude/skills")
        skills.append(contentsOf: scanDirectory(personalDir, source: .personal, fm: fm))

        // Project: {workingDirectory}/.claude/skills/
        let projectDir = (workingDirectory as NSString)
            .appendingPathComponent(".claude/skills")
        if projectDir != personalDir {
            skills.append(contentsOf: scanDirectory(projectDir, source: .project, fm: fm))
        }

        return skills
    }

    private static func scanDirectory(
        _ path: String,
        source: Skill.SkillSource,
        fm: FileManager
    ) -> [Skill] {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return []
        }

        do {
            let entries = try fm.contentsOfDirectory(atPath: path)
            return entries.compactMap { entry -> Skill? in
                let entryPath = (path as NSString).appendingPathComponent(entry)
                var entryIsDir: ObjCBool = false
                guard fm.fileExists(atPath: entryPath, isDirectory: &entryIsDir),
                      entryIsDir.boolValue else {
                    return nil
                }

                let skillFile = (entryPath as NSString).appendingPathComponent("SKILL.md")
                guard let content = try? String(contentsOfFile: skillFile, encoding: .utf8) else {
                    return nil
                }
                return SkillParser.parse(
                    content: content,
                    directoryName: entry,
                    filePath: skillFile,
                    source: source
                )
            }
        } catch {
            return []
        }
    }
}
