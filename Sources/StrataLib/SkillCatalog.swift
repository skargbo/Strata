import Foundation

// MARK: - Catalog Models

struct CatalogSkill: Identifiable, Hashable, Codable, Equatable {
    let id: String
    let name: String
    let source: String
    var description: String?
    var instructions: String?
    var installs: Int?
    var isInstalled: Bool = false
    // Synthesized Equatable compares all fields, which lets SwiftUI detect
    // when description/instructions are populated after a lazy fetch.
    // Synthesized Hashable hashes all fields, which is consistent.
}

struct CatalogSource: Identifiable, Hashable, Codable {
    var id: String { name }
    let name: String
    var skills: [CatalogSkill]

    var displayName: String {
        SkillCatalog.sourceDisplayNames[name]
            ?? name.split(separator: "/").first
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            ?? name
    }
}

// MARK: - Disk Cache

private struct CatalogCache: Codable {
    let fetchedAt: Date
    let sources: [CatalogSource]
}

// MARK: - GitHub API Response

private struct GitHubDirectoryEntry: Decodable {
    let name: String
    let type: String // "dir" or "file"
}

// MARK: - skills.sh Search Response

private struct SkillsSearchResponse: Decodable {
    let skills: [SkillsSearchEntry]

    struct SkillsSearchEntry: Decodable {
        let skillId: String
        let name: String
        let installs: Int
        let source: String
    }
}

// MARK: - SkillCatalog

@Observable
final class SkillCatalog {
    static let shared = SkillCatalog()

    static let allowedSources: [String] = [
        "anthropics/skills",
        "vercel-labs/agent-skills",
        "supabase/agent-skills",
        "expo/skills",
        "remotion-dev/skills",
    ]

    static let sourceDisplayNames: [String: String] = [
        "anthropics/skills": "Anthropic",
        "vercel-labs/agent-skills": "Vercel",
        "supabase/agent-skills": "Supabase",
        "expo/skills": "Expo",
        "remotion-dev/skills": "Remotion",
    ]

    var sources: [CatalogSource] = []
    var searchResults: [CatalogSkill] = []
    var isLoading: Bool = false
    var isSearching: Bool = false
    var error: String? = nil
    var lastFetched: Date? = nil

    private static let cacheTTL: TimeInterval = 3600
    private static let searchAPI = "https://skills.sh/api/search"

    /// In-memory cache for fetched SKILL.md content keyed by skill id.
    private var detailCache: [String: (description: String, instructions: String)] = [:]

    private var cacheFileURL: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/strata", isDirectory: true)
        return dir.appendingPathComponent("catalog.json")
    }

    private init() {
        loadCache()
    }

    // MARK: - Featured (Browse)

    func fetchFeatured(force: Bool = false) async {
        if !force,
           !sources.isEmpty,
           let last = lastFetched,
           Date().timeIntervalSince(last) < Self.cacheTTL
        {
            return
        }

        await MainActor.run { isLoading = true; error = nil }

        var builtSources: [CatalogSource] = []

        await withTaskGroup(of: CatalogSource?.self) { group in
            for source in Self.allowedSources {
                group.addTask {
                    await self.fetchSourceDirectory(source)
                }
            }
            for await result in group {
                if let source = result {
                    builtSources.append(source)
                }
            }
        }

        // Sort sources in allowlist order
        let order = Self.allowedSources
        builtSources.sort { a, b in
            (order.firstIndex(of: a.name) ?? 999) < (order.firstIndex(of: b.name) ?? 999)
        }

        let result = builtSources
        await MainActor.run {
            self.sources = result
            self.lastFetched = Date()
            self.isLoading = false
            if result.isEmpty {
                self.error = "Could not load skill sources"
            }
        }

        saveCache()
    }

    private func fetchSourceDirectory(_ source: String) async -> CatalogSource? {
        let urlString = "https://api.github.com/repos/\(source)/contents/skills"
        guard let url = URL(string: urlString) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

            let (data, _) = try await URLSession.shared.data(for: request)
            let entries = try JSONDecoder().decode([GitHubDirectoryEntry].self, from: data)

            let dirNames = entries
                .filter { $0.type == "dir" }
                .map(\.name)
                .sorted()

            // Fetch SKILL.md for each skill in parallel so descriptions are
            // available immediately when the user clicks a skill.
            var skills: [CatalogSkill] = []
            await withTaskGroup(of: CatalogSkill.self) { group in
                for name in dirNames {
                    group.addTask {
                        let skillId = "\(source)/\(name)"
                        let detail = await self.fetchSkillMD(source: source, name: name)
                        let skill = CatalogSkill(
                            id: skillId,
                            name: name,
                            source: source,
                            description: detail?.description,
                            instructions: detail?.instructions
                        )
                        // Cache the detail so catalogDetail never needs a second fetch
                        if let detail {
                            self.detailCache[skillId] = detail
                        }
                        return skill
                    }
                }
                for await skill in group {
                    skills.append(skill)
                }
            }
            skills.sort { $0.name < $1.name }

            return CatalogSource(name: source, skills: skills)
        } catch {
            return nil
        }
    }

    /// Fetch and parse a single SKILL.md from raw GitHub content.
    private func fetchSkillMD(source: String, name: String) async -> (description: String, instructions: String)? {
        let urlString = "https://raw.githubusercontent.com/\(source)/main/skills/\(name)/SKILL.md"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let content = String(data: data, encoding: .utf8) else { return nil }

            let parsed = SkillParser.parse(
                content: content,
                directoryName: name,
                filePath: urlString,
                source: .personal
            )

            return (
                description: parsed?.description ?? "",
                instructions: parsed?.instructions ?? content
            )
        } catch {
            return nil
        }
    }

    // MARK: - Search (skills.sh)

    func search(query: String) async {
        guard !query.isEmpty else {
            await MainActor.run { searchResults = [] }
            return
        }

        await MainActor.run { isSearching = true }

        let allowed = Set(Self.allowedSources)
        let urlString = "\(Self.searchAPI)?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&limit=30"

        guard let url = URL(string: urlString) else {
            await MainActor.run { isSearching = false }
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(SkillsSearchResponse.self, from: data)

            let filtered = response.skills
                .filter { allowed.contains($0.source) }
                .map { entry in
                    CatalogSkill(
                        id: "\(entry.source)/\(entry.skillId)",
                        name: entry.skillId,
                        source: entry.source,
                        installs: entry.installs
                    )
                }

            let results = filtered
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
            }
        } catch {
            await MainActor.run {
                self.searchResults = []
                self.isSearching = false
            }
        }
    }

    // MARK: - Lazy Detail Fetch

    /// Fetch SKILL.md for a skill and update its description/instructions.
    func fetchDetail(for skill: CatalogSkill) async -> (description: String, instructions: String)? {
        // Check memory cache
        if let cached = detailCache[skill.id] {
            return cached
        }

        let urlString = "https://raw.githubusercontent.com/\(skill.source)/main/skills/\(skill.name)/SKILL.md"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let content = String(data: data, encoding: .utf8) else { return nil }

            let parsed = SkillParser.parse(
                content: content,
                directoryName: skill.name,
                filePath: urlString,
                source: .personal
            )

            let detail = (
                description: parsed?.description ?? "",
                instructions: parsed?.instructions ?? content
            )

            detailCache[skill.id] = detail

            // Update in-place in sources
            await MainActor.run {
                for i in sources.indices {
                    for j in sources[i].skills.indices {
                        if sources[i].skills[j].id == skill.id {
                            sources[i].skills[j].description = detail.description
                            sources[i].skills[j].instructions = detail.instructions
                        }
                    }
                }
                // Also update in search results
                for i in searchResults.indices {
                    if searchResults[i].id == skill.id {
                        searchResults[i].description = detail.description
                        searchResults[i].instructions = detail.instructions
                    }
                }
            }

            return detail
        } catch {
            return nil
        }
    }

    // MARK: - Install / Uninstall

    func install(_ skill: CatalogSkill) throws {
        let fm = FileManager.default
        let skillDir = (NSHomeDirectory() as NSString)
            .appendingPathComponent(".claude/skills/\(skill.name)")

        try fm.createDirectory(atPath: skillDir, withIntermediateDirectories: true)

        // Reconstruct SKILL.md
        var content = "---\n"
        content += "name: \(skill.name)\n"
        if let desc = skill.description, !desc.isEmpty {
            content += "description: \(desc)\n"
        }
        content += "---\n"
        if let instr = skill.instructions, !instr.isEmpty {
            content += "\n\(instr)\n"
        }

        let filePath = (skillDir as NSString).appendingPathComponent("SKILL.md")
        try content.write(toFile: filePath, atomically: true, encoding: .utf8)

        markSkillInstalled(name: skill.name, installed: true)
    }

    func uninstall(_ skill: CatalogSkill) throws {
        let fm = FileManager.default
        let skillDir = (NSHomeDirectory() as NSString)
            .appendingPathComponent(".claude/skills/\(skill.name)")

        if fm.fileExists(atPath: skillDir) {
            try fm.removeItem(atPath: skillDir)
        }

        markSkillInstalled(name: skill.name, installed: false)
    }

    /// Cross-reference catalog skills against locally installed skills.
    func markInstalled(localSkills: [Skill]) {
        let localNames = Set(localSkills.map(\.name))
        for i in sources.indices {
            for j in sources[i].skills.indices {
                sources[i].skills[j].isInstalled = localNames.contains(
                    sources[i].skills[j].name
                )
            }
        }
        for i in searchResults.indices {
            searchResults[i].isInstalled = localNames.contains(searchResults[i].name)
        }
    }

    private func markSkillInstalled(name: String, installed: Bool) {
        for i in sources.indices {
            for j in sources[i].skills.indices {
                if sources[i].skills[j].name == name {
                    sources[i].skills[j].isInstalled = installed
                }
            }
        }
        for i in searchResults.indices {
            if searchResults[i].name == name {
                searchResults[i].isInstalled = installed
            }
        }
    }

    // MARK: - Disk Cache

    func loadCache() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: cacheFileURL.path) else { return }

        do {
            let data = try Data(contentsOf: cacheFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cache = try decoder.decode(CatalogCache.self, from: data)
            self.sources = cache.sources
            self.lastFetched = cache.fetchedAt
        } catch {
            // Cache is corrupted — ignore it
        }
    }

    private func saveCache() {
        let fm = FileManager.default
        let dir = cacheFileURL.deletingLastPathComponent()

        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let cache = CatalogCache(
                fetchedAt: lastFetched ?? Date(),
                sources: sources
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(cache)
            try data.write(to: cacheFileURL, options: .atomic)
        } catch {
            // Non-fatal — caching is best-effort
        }
    }
}
