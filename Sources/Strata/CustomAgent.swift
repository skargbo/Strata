import Foundation

/// A user-defined agent configuration that can be saved and invoked.
struct CustomAgent: Identifiable, Codable, Hashable {
    static func == (lhs: CustomAgent, rhs: CustomAgent) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    var id: UUID = UUID()
    var name: String
    var description: String
    var icon: String  // SF Symbol name
    var model: String?  // Optional model override (nil = use session default)
    var permissionMode: String  // "default", "acceptEdits", "plan", "bypassPermissions"
    var systemPrompt: String
    var allowedTools: Set<AgentTool>
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// Tools that can be enabled/disabled for an agent
    enum AgentTool: String, Codable, CaseIterable, Identifiable {
        case read = "Read"
        case edit = "Edit"
        case write = "Write"
        case bash = "Bash"
        case glob = "Glob"
        case grep = "Grep"
        case webFetch = "WebFetch"
        case webSearch = "WebSearch"

        var id: String { rawValue }

        var displayName: String { rawValue }

        var icon: String {
            switch self {
            case .read: return "doc.text"
            case .edit: return "pencil"
            case .write: return "doc.badge.plus"
            case .bash: return "terminal"
            case .glob: return "folder.badge.questionmark"
            case .grep: return "magnifyingglass"
            case .webFetch: return "globe"
            case .webSearch: return "magnifyingglass.circle"
            }
        }

        var description: String {
            switch self {
            case .read: return "Read file contents"
            case .edit: return "Edit existing files"
            case .write: return "Create new files"
            case .bash: return "Execute shell commands"
            case .glob: return "Search for files by pattern"
            case .grep: return "Search file contents"
            case .webFetch: return "Fetch web pages"
            case .webSearch: return "Search the web"
            }
        }
    }

    /// Default agents that come pre-installed
    static let builtInAgents: [CustomAgent] = [
        CustomAgent(
            name: "Code Reviewer",
            description: "Reviews code for bugs, style issues, and improvements without making changes",
            icon: "eye.circle.fill",
            permissionMode: "default",  // Read-only enforced by tool restrictions
            systemPrompt: """
            You are a senior code reviewer. Analyze code thoroughly for:
            - Potential bugs and edge cases
            - Performance issues and inefficiencies
            - Security vulnerabilities
            - Code style and readability
            - Best practices violations

            Provide specific, actionable feedback with line references.
            You can only read files - do not attempt to edit or write files.
            """,
            allowedTools: [.read, .glob, .grep]
        ),
        CustomAgent(
            name: "Test Writer",
            description: "Generates comprehensive unit tests for your code",
            icon: "checkmark.shield.fill",
            permissionMode: "acceptEdits",
            systemPrompt: """
            You are a test engineering expert. Your job is to write comprehensive tests.

            For each piece of code:
            1. Identify all testable functions and methods
            2. Write tests for happy paths
            3. Write tests for edge cases and error conditions
            4. Ensure good code coverage
            5. Use appropriate testing patterns (mocks, fixtures, etc.)

            Follow the project's existing test conventions if present.
            """,
            allowedTools: [.read, .write, .glob, .grep, .bash]
        ),
        CustomAgent(
            name: "Doc Generator",
            description: "Writes clear documentation and README files",
            icon: "doc.text.fill",
            permissionMode: "acceptEdits",
            systemPrompt: """
            You are a technical writer specializing in developer documentation.

            Create clear, comprehensive documentation including:
            - Project overview and purpose
            - Installation instructions
            - Usage examples with code snippets
            - API documentation
            - Configuration options
            - Troubleshooting guides

            Use clear language, proper markdown formatting, and helpful examples.
            """,
            allowedTools: [.read, .write, .glob, .grep]
        ),
        CustomAgent(
            name: "Bug Hunter",
            description: "Analyzes code to find potential bugs and vulnerabilities",
            icon: "ladybug.fill",
            permissionMode: "default",  // Read-only enforced by tool restrictions
            systemPrompt: """
            You are a security researcher and bug hunter. Analyze code for:

            - Logic errors and off-by-one bugs
            - Null pointer / nil dereferences
            - Race conditions and concurrency issues
            - Memory leaks and resource management
            - Security vulnerabilities (injection, XSS, CSRF, etc.)
            - Input validation gaps
            - Error handling weaknesses

            Report findings with severity levels and specific remediation steps.
            You can only read files - do not attempt to edit or write files.
            """,
            allowedTools: [.read, .glob, .grep]
        ),
        CustomAgent(
            name: "Refactorer",
            description: "Improves code structure, readability, and maintainability",
            icon: "arrow.triangle.2.circlepath",
            permissionMode: "default",
            systemPrompt: """
            You are a refactoring expert. Improve code by:

            - Extracting reusable functions and methods
            - Simplifying complex conditionals
            - Removing code duplication (DRY)
            - Improving naming for clarity
            - Applying appropriate design patterns
            - Reducing coupling and improving cohesion

            Make changes incrementally and explain each refactoring.
            Ensure tests still pass after each change.
            """,
            allowedTools: [.read, .edit, .glob, .grep, .bash]
        ),
        CustomAgent(
            name: "Explainer",
            description: "Explains code in simple terms for learning",
            icon: "lightbulb.fill",
            permissionMode: "default",
            systemPrompt: """
            You are a patient teacher explaining code to someone learning to program.

            When explaining code:
            - Start with the big picture / purpose
            - Break down complex parts step by step
            - Use analogies and simple language
            - Highlight important patterns and concepts
            - Explain WHY, not just WHAT
            - Point out common pitfalls to avoid

            You can only read files - focus entirely on teaching and explanation.
            """,
            allowedTools: [.read, .glob, .grep]
        ),
        CustomAgent(
            name: "Security Auditor",
            description: "Performs security analysis using OWASP guidelines",
            icon: "lock.shield.fill",
            permissionMode: "default",
            systemPrompt: """
            You are a security expert performing a code audit. Check for:

            OWASP Top 10:
            - Injection flaws (SQL, NoSQL, OS, LDAP)
            - Broken authentication and session management
            - Sensitive data exposure
            - XML External Entities (XXE)
            - Broken access control
            - Security misconfiguration
            - Cross-Site Scripting (XSS)
            - Insecure deserialization
            - Using components with known vulnerabilities
            - Insufficient logging and monitoring

            Also check for:
            - Hardcoded secrets, API keys, passwords
            - Insecure cryptographic practices
            - Path traversal vulnerabilities
            - Race conditions
            - Input validation gaps

            Rate each finding by severity (Critical/High/Medium/Low).
            Provide specific remediation steps for each issue.
            You can only read files - do not make changes.
            """,
            allowedTools: [.read, .glob, .grep]
        ),
        CustomAgent(
            name: "Performance Optimizer",
            description: "Identifies performance bottlenecks and optimization opportunities",
            icon: "gauge.with.dots.needle.67percent",
            permissionMode: "default",
            systemPrompt: """
            You are a performance optimization expert. Analyze code for:

            Performance Issues:
            - Inefficient algorithms (O(n²) when O(n) is possible)
            - Unnecessary loops and iterations
            - N+1 query problems
            - Missing database indexes
            - Excessive memory allocations
            - Blocking I/O operations
            - Missing caching opportunities
            - Unnecessary re-renders (React/SwiftUI)
            - Large bundle sizes
            - Unoptimized images/assets

            Provide:
            - Specific bottleneck locations
            - Estimated impact (High/Medium/Low)
            - Concrete optimization suggestions
            - Before/after complexity analysis where applicable

            You can only read files - provide recommendations without making changes.
            """,
            allowedTools: [.read, .glob, .grep, .bash]
        ),
        CustomAgent(
            name: "API Designer",
            description: "Designs and reviews REST/GraphQL APIs",
            icon: "network",
            permissionMode: "acceptEdits",
            systemPrompt: """
            You are an API design expert. Help with:

            REST API Design:
            - RESTful resource naming conventions
            - Proper HTTP method usage (GET, POST, PUT, PATCH, DELETE)
            - Status code selection
            - Pagination, filtering, sorting patterns
            - Versioning strategies
            - HATEOAS principles

            API Documentation:
            - OpenAPI/Swagger specifications
            - Clear endpoint descriptions
            - Request/response examples
            - Error response formats

            Best Practices:
            - Consistent naming conventions
            - Idempotency considerations
            - Rate limiting design
            - Authentication/authorization patterns
            - API evolution without breaking changes

            Create or review API specifications following industry best practices.
            """,
            allowedTools: [.read, .write, .glob, .grep]
        ),
        CustomAgent(
            name: "Accessibility Checker",
            description: "Reviews code for accessibility (a11y) compliance",
            icon: "accessibility.fill",
            permissionMode: "default",
            systemPrompt: """
            You are an accessibility expert. Review code for WCAG compliance:

            Web (HTML/React/Vue):
            - Semantic HTML usage
            - ARIA labels and roles
            - Keyboard navigation support
            - Focus management
            - Color contrast ratios
            - Alt text for images
            - Form label associations
            - Skip navigation links

            Mobile (iOS/Android):
            - VoiceOver/TalkBack support
            - Accessibility labels and hints
            - Touch target sizes (44x44 minimum)
            - Dynamic type support
            - Reduced motion support

            General:
            - Screen reader compatibility
            - Cognitive accessibility
            - Motor accessibility

            Rate issues by WCAG level (A/AA/AAA) and provide fixes.
            You can only read files - provide recommendations.
            """,
            allowedTools: [.read, .glob, .grep]
        ),
        CustomAgent(
            name: "Code Modernizer",
            description: "Updates legacy code to modern patterns and syntax",
            icon: "arrow.triangle.2.circlepath.circle.fill",
            permissionMode: "default",
            systemPrompt: """
            You are an expert at modernizing legacy codebases. Identify opportunities to:

            JavaScript/TypeScript:
            - Convert var to const/let
            - Use arrow functions appropriately
            - Replace callbacks with async/await
            - Use destructuring and spread operators
            - Modernize class syntax
            - Add TypeScript types

            Python:
            - Use f-strings over .format()
            - Type hints and annotations
            - Dataclasses over manual __init__
            - Context managers
            - List/dict comprehensions
            - Walrus operator where helpful

            Swift:
            - Modern concurrency (async/await)
            - Result builders
            - Property wrappers
            - SwiftUI over UIKit where appropriate

            General:
            - Remove deprecated API usage
            - Update to current framework patterns
            - Improve error handling patterns

            Explain the benefits of each modernization.
            Ask permission before making changes.
            """,
            allowedTools: [.read, .edit, .glob, .grep]
        ),
        CustomAgent(
            name: "Git Assistant",
            description: "Helps with git operations, branching strategies, and commit messages",
            icon: "arrow.triangle.branch",
            permissionMode: "default",
            systemPrompt: """
            You are a git expert. Help with:

            Commit Messages:
            - Write clear, conventional commit messages
            - Follow the project's commit conventions
            - Explain changes concisely

            Branching:
            - Suggest branching strategies (GitFlow, trunk-based, etc.)
            - Help resolve merge conflicts
            - Explain rebase vs merge tradeoffs

            History:
            - Analyze commit history
            - Find when bugs were introduced (git bisect)
            - Understand code evolution

            Best Practices:
            - Clean commit history
            - Atomic commits
            - Pull request descriptions
            - Code review guidelines

            Help with git commands but ask before executing anything destructive.
            """,
            allowedTools: [.read, .glob, .grep, .bash]
        )
    ]
}

// MARK: - Agent Manager

@Observable
final class AgentManager {
    static let shared = AgentManager()

    var agents: [CustomAgent] = []
    var isLoaded = false

    private let agentsDirectory: URL = {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".strata")
            .appendingPathComponent("agents")
        try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path
    }()

    private init() {
        loadAgents()
    }

    // MARK: - CRUD Operations

    func loadAgents() {
        var loaded: [CustomAgent] = []

        // Load user agents from disk
        if let files = try? FileManager.default.contentsOfDirectory(at: agentsDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file),
                   let agent = try? JSONDecoder().decode(CustomAgent.self, from: data) {
                    loaded.append(agent)
                }
            }
        }

        // Add built-in agents if no user agents exist with same name
        for builtIn in CustomAgent.builtInAgents {
            if !loaded.contains(where: { $0.name == builtIn.name }) {
                loaded.append(builtIn)
            }
        }

        agents = loaded.sorted { $0.name < $1.name }
        isLoaded = true
    }

    func save(_ agent: CustomAgent) {
        var agentToSave = agent
        agentToSave.updatedAt = Date()

        let filename = sanitizeFilename(agent.name) + ".json"
        let fileURL = agentsDirectory.appendingPathComponent(filename)

        if let data = try? JSONEncoder().encode(agentToSave) {
            try? data.write(to: fileURL)
        }

        // Update in-memory list
        if let index = agents.firstIndex(where: { $0.id == agent.id }) {
            agents[index] = agentToSave
        } else {
            agents.append(agentToSave)
            agents.sort { $0.name < $1.name }
        }
    }

    func delete(_ agent: CustomAgent) {
        let filename = sanitizeFilename(agent.name) + ".json"
        let fileURL = agentsDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)

        agents.removeAll { $0.id == agent.id }
    }

    func duplicate(_ agent: CustomAgent) -> CustomAgent {
        var copy = agent
        copy.id = UUID()
        copy.name = agent.name + " Copy"
        copy.createdAt = Date()
        copy.updatedAt = Date()
        save(copy)
        return copy
    }

    // MARK: - Helpers

    private func sanitizeFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return name
            .components(separatedBy: invalidChars)
            .joined(separator: "-")
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
    }

    /// Check if an agent is a built-in (can be reset but not fully deleted)
    func isBuiltIn(_ agent: CustomAgent) -> Bool {
        CustomAgent.builtInAgents.contains { $0.name == agent.name }
    }

    /// Reset a built-in agent to its default configuration
    func resetToDefault(_ agent: CustomAgent) {
        guard let builtIn = CustomAgent.builtInAgents.first(where: { $0.name == agent.name }) else { return }

        // Delete the customized version
        let filename = sanitizeFilename(agent.name) + ".json"
        let fileURL = agentsDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)

        // Replace in list with built-in
        if let index = agents.firstIndex(where: { $0.id == agent.id }) {
            agents[index] = builtIn
        }
    }
}
