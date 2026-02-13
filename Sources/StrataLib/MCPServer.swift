import Foundation
import SwiftUI

/// Configuration for an MCP (Model Context Protocol) server.
struct MCPServerConfig: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String                    // Human-readable name, e.g., "Postgres Database"
    var command: String                 // Command to run, e.g., "npx" or "/usr/local/bin/mcp-server"
    var args: [String]                  // Arguments, e.g., ["-y", "@modelcontextprotocol/server-postgres"]
    var env: [String: String]           // Environment variables, e.g., {"DATABASE_URL": "..."}
    var enabled: Bool = true            // Whether the server should be used
    var autoStart: Bool = true          // Start automatically with sessions

    init(name: String, command: String, args: [String] = [], env: [String: String] = [:]) {
        self.name = name
        self.command = command
        self.args = args
        self.env = env
    }

    // Hashable conformance
    static func == (lhs: MCPServerConfig, rhs: MCPServerConfig) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Status of an MCP server connection
enum MCPServerStatus: String, Codable {
    case stopped
    case starting
    case running
    case error

    var icon: String {
        switch self {
        case .stopped: return "circle"
        case .starting: return "circle.dotted"
        case .running: return "circle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .stopped: return "secondary"
        case .starting: return "orange"
        case .running: return "green"
        case .error: return "red"
        }
    }
}

/// Information about a tool provided by an MCP server
struct MCPTool: Identifiable, Codable {
    var id: String { name }
    let name: String
    let description: String?
    let inputSchema: [String: Any]?

    enum CodingKeys: String, CodingKey {
        case name, description
    }

    init(name: String, description: String? = nil, inputSchema: [String: Any]? = nil) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        inputSchema = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
    }
}

/// Manager for MCP server configurations and status
@Observable
class MCPManager {
    static let shared = MCPManager()

    var servers: [MCPServerConfig] = []
    var serverStatus: [UUID: MCPServerStatus] = [:]
    var serverTools: [UUID: [MCPTool]] = [:]
    var serverErrors: [UUID: String] = [:]

    private let configPath: URL

    private init() {
        // Store configs in ~/.strata/mcp-servers.json
        let strataDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".strata")
        configPath = strataDir.appendingPathComponent("mcp-servers.json")

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: strataDir, withIntermediateDirectories: true)

        load()
    }

    // MARK: - CRUD Operations

    func add(_ config: MCPServerConfig) {
        servers.append(config)
        serverStatus[config.id] = .stopped
        save()
    }

    func update(_ config: MCPServerConfig) {
        if let index = servers.firstIndex(where: { $0.id == config.id }) {
            servers[index] = config
            save()
        }
    }

    func remove(_ config: MCPServerConfig) {
        servers.removeAll { $0.id == config.id }
        serverStatus.removeValue(forKey: config.id)
        serverTools.removeValue(forKey: config.id)
        serverErrors.removeValue(forKey: config.id)
        save()
    }

    func removeAll() {
        servers.removeAll()
        serverStatus.removeAll()
        serverTools.removeAll()
        serverErrors.removeAll()
        save()
    }

    // MARK: - Status Updates

    func updateStatus(_ serverId: UUID, status: MCPServerStatus) {
        serverStatus[serverId] = status
    }

    func updateTools(_ serverId: UUID, tools: [MCPTool]) {
        serverTools[serverId] = tools
    }

    func updateError(_ serverId: UUID, error: String?) {
        if let error = error {
            serverErrors[serverId] = error
        } else {
            serverErrors.removeValue(forKey: serverId)
        }
    }

    func status(for serverId: UUID) -> MCPServerStatus {
        serverStatus[serverId] ?? .stopped
    }

    func tools(for serverId: UUID) -> [MCPTool] {
        serverTools[serverId] ?? []
    }

    func error(for serverId: UUID) -> String? {
        serverErrors[serverId]
    }

    // MARK: - Persistence

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(servers)
            try data.write(to: configPath)
        } catch {
            print("Failed to save MCP servers: \(error)")
        }
    }

    func load() {
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            // Create default/example configs if none exist
            createDefaultConfigs()
            return
        }

        do {
            let data = try Data(contentsOf: configPath)
            servers = try JSONDecoder().decode([MCPServerConfig].self, from: data)
            // Initialize status for all servers
            for server in servers {
                serverStatus[server.id] = .stopped
            }
        } catch {
            print("Failed to load MCP servers: \(error)")
        }
    }

    private func createDefaultConfigs() {
        // Add a few example/common MCP servers
        let examples: [MCPServerConfig] = [
            MCPServerConfig(
                name: "Filesystem",
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"],
                env: [:]
            ),
        ]

        for var config in examples {
            config.enabled = false  // Disabled by default
            config.autoStart = false
            servers.append(config)
            serverStatus[config.id] = .stopped
        }

        save()
    }

    // MARK: - Import/Export

    func exportConfigs() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(servers)
    }

    func importConfigs(from data: Data) throws {
        let imported = try JSONDecoder().decode([MCPServerConfig].self, from: data)
        for var config in imported {
            // Generate new IDs to avoid conflicts
            config.id = UUID()
            config.enabled = false
            add(config)
        }
    }

    // MARK: - Helpers

    /// Get all enabled servers that should auto-start
    var autoStartServers: [MCPServerConfig] {
        servers.filter { $0.enabled && $0.autoStart }
    }

    /// Get all running servers
    var runningServers: [MCPServerConfig] {
        servers.filter { serverStatus[$0.id] == .running }
    }

    /// Get all tools from all running servers
    var allAvailableTools: [(server: MCPServerConfig, tool: MCPTool)] {
        var result: [(MCPServerConfig, MCPTool)] = []
        for server in runningServers {
            for tool in tools(for: server.id) {
                result.append((server, tool))
            }
        }
        return result
    }
}

// MARK: - MCP Server Catalog

/// A preset MCP server from the catalog
struct MCPServerPreset: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let category: Category
    let command: String
    let args: [String]
    let envKeys: [String]  // Environment variables the user needs to provide
    let npmPackage: String?
    let repoURL: String?
    let keywords: Set<String>  // Keywords for context-aware suggestions

    init(name: String, description: String, category: Category, command: String, args: [String], envKeys: [String], npmPackage: String?, repoURL: String?, keywords: Set<String>? = nil) {
        self.name = name
        self.description = description
        self.category = category
        self.command = command
        self.args = args
        self.envKeys = envKeys
        self.npmPackage = npmPackage
        self.repoURL = repoURL
        // Auto-extract keywords from name and description if not provided
        self.keywords = keywords ?? Self.extractKeywords(from: "\(name) \(description)")
    }

    private static func extractKeywords(from text: String) -> Set<String> {
        let stopWords: Set<String> = ["the", "a", "an", "and", "or", "to", "for", "with", "from", "in", "on", "of", "is", "are", "was", "were", "be", "been", "being", "have", "has", "had", "do", "does", "did", "will", "would", "could", "should", "may", "might", "must", "can", "this", "that", "these", "those", "it", "its", "use", "using", "via", "based", "more", "all"]
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stopWords.contains($0) }
        return Set(words)
    }

    enum Category: String, CaseIterable {
        case database = "Database"
        case filesystem = "Filesystem"
        case productivity = "Productivity"
        case development = "Development"
        case search = "Search"
        case communication = "Communication"
        case thirdParty = "Third Party"

        var icon: String {
            switch self {
            case .database: return "cylinder"
            case .filesystem: return "folder"
            case .productivity: return "briefcase"
            case .development: return "hammer"
            case .search: return "magnifyingglass"
            case .communication: return "bubble.left.and.bubble.right"
            case .thirdParty: return "building.2"
            }
        }
    }

    /// Convert to a server config (user still needs to fill in env values)
    func toConfig() -> MCPServerConfig {
        var config = MCPServerConfig(name: name, command: command, args: args)
        config.enabled = false
        config.autoStart = false
        // Initialize env with empty values for required keys
        for key in envKeys {
            config.env[key] = ""
        }
        return config
    }
}

/// Catalog of popular MCP servers
struct MCPCatalog {
    static let servers: [MCPServerPreset] = [
        // Database
        MCPServerPreset(
            name: "PostgreSQL",
            description: "Query PostgreSQL databases with read-only access",
            category: .database,
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-postgres"],
            envKeys: ["POSTGRES_CONNECTION_STRING"],
            npmPackage: "@modelcontextprotocol/server-postgres",
            repoURL: "https://github.com/modelcontextprotocol/servers/tree/main/src/postgres"
        ),
        MCPServerPreset(
            name: "SQLite",
            description: "Query local SQLite databases",
            category: .database,
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-sqlite", "--db-path", "~/database.db"],
            envKeys: [],
            npmPackage: "@modelcontextprotocol/server-sqlite",
            repoURL: "https://github.com/modelcontextprotocol/servers/tree/main/src/sqlite"
        ),

        // Filesystem
        MCPServerPreset(
            name: "Filesystem",
            description: "Read, write, and manage files in specified directories",
            category: .filesystem,
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-filesystem", "~/Documents"],
            envKeys: [],
            npmPackage: "@modelcontextprotocol/server-filesystem",
            repoURL: "https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem"
        ),
        MCPServerPreset(
            name: "Google Drive",
            description: "Search and read files from Google Drive",
            category: .filesystem,
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-gdrive"],
            envKeys: ["GDRIVE_CREDENTIALS_PATH"],
            npmPackage: "@modelcontextprotocol/server-gdrive",
            repoURL: "https://github.com/modelcontextprotocol/servers/tree/main/src/gdrive"
        ),

        // Development
        MCPServerPreset(
            name: "GitHub",
            description: "Manage repositories, issues, pull requests, and more",
            category: .development,
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-github"],
            envKeys: ["GITHUB_PERSONAL_ACCESS_TOKEN"],
            npmPackage: "@modelcontextprotocol/server-github",
            repoURL: "https://github.com/modelcontextprotocol/servers/tree/main/src/github"
        ),
        MCPServerPreset(
            name: "GitLab",
            description: "Interact with GitLab repositories and CI/CD",
            category: .development,
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-gitlab"],
            envKeys: ["GITLAB_PERSONAL_ACCESS_TOKEN", "GITLAB_API_URL"],
            npmPackage: "@modelcontextprotocol/server-gitlab",
            repoURL: "https://github.com/modelcontextprotocol/servers/tree/main/src/gitlab"
        ),
        MCPServerPreset(
            name: "Sentry",
            description: "Retrieve and analyze issues from Sentry",
            category: .development,
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-sentry"],
            envKeys: ["SENTRY_AUTH_TOKEN", "SENTRY_ORG"],
            npmPackage: "@modelcontextprotocol/server-sentry",
            repoURL: "https://github.com/modelcontextprotocol/servers/tree/main/src/sentry"
        ),

        // Search
        MCPServerPreset(
            name: "Brave Search",
            description: "Web and local search using Brave Search API",
            category: .search,
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-brave-search"],
            envKeys: ["BRAVE_API_KEY"],
            npmPackage: "@modelcontextprotocol/server-brave-search",
            repoURL: "https://github.com/modelcontextprotocol/servers/tree/main/src/brave-search"
        ),
        MCPServerPreset(
            name: "Fetch",
            description: "Fetch and convert web pages to markdown",
            category: .search,
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-fetch"],
            envKeys: [],
            npmPackage: "@modelcontextprotocol/server-fetch",
            repoURL: "https://github.com/modelcontextprotocol/servers/tree/main/src/fetch"
        ),
        MCPServerPreset(
            name: "Puppeteer",
            description: "Browser automation for web scraping and screenshots",
            category: .search,
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-puppeteer"],
            envKeys: [],
            npmPackage: "@modelcontextprotocol/server-puppeteer",
            repoURL: "https://github.com/modelcontextprotocol/servers/tree/main/src/puppeteer"
        ),

        // Communication
        MCPServerPreset(
            name: "Slack",
            description: "Read and post messages to Slack channels",
            category: .communication,
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-slack"],
            envKeys: ["SLACK_BOT_TOKEN", "SLACK_TEAM_ID"],
            npmPackage: "@modelcontextprotocol/server-slack",
            repoURL: "https://github.com/modelcontextprotocol/servers/tree/main/src/slack"
        ),

        // Productivity
        MCPServerPreset(
            name: "Google Maps",
            description: "Location services, directions, and place details",
            category: .productivity,
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-google-maps"],
            envKeys: ["GOOGLE_MAPS_API_KEY"],
            npmPackage: "@modelcontextprotocol/server-google-maps",
            repoURL: "https://github.com/modelcontextprotocol/servers/tree/main/src/google-maps"
        ),
        MCPServerPreset(
            name: "Memory",
            description: "Persistent memory using a knowledge graph",
            category: .productivity,
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-memory"],
            envKeys: [],
            npmPackage: "@modelcontextprotocol/server-memory",
            repoURL: "https://github.com/modelcontextprotocol/servers/tree/main/src/memory"
        ),
        MCPServerPreset(
            name: "Sequential Thinking",
            description: "Dynamic problem-solving through thought sequences",
            category: .productivity,
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-sequential-thinking"],
            envKeys: [],
            npmPackage: "@modelcontextprotocol/server-sequential-thinking",
            repoURL: "https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking"
        ),
        MCPServerPreset(
            name: "Time",
            description: "Get current time and timezone conversions",
            category: .productivity,
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-time"],
            envKeys: [],
            npmPackage: "@modelcontextprotocol/server-time",
            repoURL: "https://github.com/modelcontextprotocol/servers/tree/main/src/time"
        ),

        // Third Party (Official integrations from companies)
        MCPServerPreset(
            name: "Atlassian",
            description: "Interact with Jira issues and Confluence pages",
            category: .thirdParty,
            command: "npx",
            args: ["-y", "@anthropic/mcp-atlassian"],
            envKeys: ["ATLASSIAN_API_TOKEN", "ATLASSIAN_EMAIL", "ATLASSIAN_URL"],
            npmPackage: "@anthropic/mcp-atlassian",
            repoURL: "https://github.com/modelcontextprotocol/servers"
        ),
        MCPServerPreset(
            name: "AWS",
            description: "AWS best practices for development workflows",
            category: .thirdParty,
            command: "npx",
            args: ["-y", "@aws/mcp"],
            envKeys: ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"],
            npmPackage: "@aws/mcp",
            repoURL: "https://github.com/awslabs/mcp"
        ),
        MCPServerPreset(
            name: "Notion",
            description: "Search and manage Notion pages and databases",
            category: .thirdParty,
            command: "npx",
            args: ["-y", "@notionhq/mcp-server"],
            envKeys: ["NOTION_API_KEY"],
            npmPackage: "@notionhq/mcp-server",
            repoURL: "https://github.com/makenotion/notion-mcp-server"
        ),
        MCPServerPreset(
            name: "Linear",
            description: "Manage Linear issues, projects, and teams",
            category: .thirdParty,
            command: "npx",
            args: ["-y", "@linear/mcp-server"],
            envKeys: ["LINEAR_API_KEY"],
            npmPackage: "@linear/mcp-server",
            repoURL: "https://github.com/linear/linear-mcp-server"
        ),
        MCPServerPreset(
            name: "Stripe",
            description: "Manage Stripe payments, customers, and subscriptions",
            category: .thirdParty,
            command: "npx",
            args: ["-y", "@stripe/mcp"],
            envKeys: ["STRIPE_API_KEY"],
            npmPackage: "@stripe/mcp",
            repoURL: "https://github.com/stripe/agent-toolkit"
        ),
        MCPServerPreset(
            name: "Apify",
            description: "Use 6,000+ tools to extract data from websites",
            category: .thirdParty,
            command: "npx",
            args: ["-y", "apify-mcp-server"],
            envKeys: ["APIFY_API_TOKEN"],
            npmPackage: "apify-mcp-server",
            repoURL: "https://github.com/apify/apify-mcp-server"
        ),
        MCPServerPreset(
            name: "Cloudflare",
            description: "Manage Cloudflare Workers, KV, and D1 databases",
            category: .thirdParty,
            command: "npx",
            args: ["-y", "@cloudflare/mcp-server"],
            envKeys: ["CLOUDFLARE_API_TOKEN"],
            npmPackage: "@cloudflare/mcp-server",
            repoURL: "https://github.com/cloudflare/mcp-server-cloudflare"
        ),
        MCPServerPreset(
            name: "Raygun",
            description: "Access crash reporting and error tracking data",
            category: .thirdParty,
            command: "npx",
            args: ["-y", "@anthropic/mcp-raygun"],
            envKeys: ["RAYGUN_API_KEY"],
            npmPackage: "@anthropic/mcp-raygun",
            repoURL: "https://github.com/MindscapeHQ/mcp-server-raygun"
        ),
    ]

    static let registryURL = URL(string: "https://github.com/modelcontextprotocol/servers")!

    static func servers(in category: MCPServerPreset.Category) -> [MCPServerPreset] {
        servers.filter { $0.category == category }
    }

    static func search(_ query: String) -> [MCPServerPreset] {
        guard !query.isEmpty else { return servers }
        let lowercased = query.lowercased()
        return servers.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.description.lowercased().contains(lowercased)
        }
    }
}

// MARK: - FocusedValue Key for Panel Toggle

struct MCPPanelToggleKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var mcpPanelToggle: Binding<Bool>? {
        get { self[MCPPanelToggleKey.self] }
        set { self[MCPPanelToggleKey.self] = newValue }
    }
}
