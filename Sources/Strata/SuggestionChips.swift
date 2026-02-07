import SwiftUI

/// Unified context-aware suggestion chips for skills, agents, and MCP servers.
struct SuggestionChips: View {
    let skills: [Skill]
    let agents: [CustomAgent]
    let mcpServers: [MCPServerPreset]

    var onSelectSkill: ((Skill) -> Void)?
    var onSelectAgent: ((CustomAgent) -> Void)?
    var onConnectMCP: ((MCPServerPreset) -> Void)?

    var body: some View {
        let hasAny = !skills.isEmpty || !agents.isEmpty || !mcpServers.isEmpty
        if hasAny {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Skills (orange)
                    ForEach(skills.prefix(2)) { skill in
                        ChipButton(
                            icon: "wand.and.stars",
                            label: "/\(skill.name)",
                            hint: skill.argumentHint,
                            color: .orange
                        ) {
                            onSelectSkill?(skill)
                        }
                    }

                    // Agents (purple)
                    ForEach(agents.prefix(2)) { agent in
                        ChipButton(
                            icon: "brain.head.profile",
                            label: agent.name,
                            hint: nil,
                            color: .purple
                        ) {
                            onSelectAgent?(agent)
                        }
                    }

                    // MCP Servers (blue)
                    ForEach(mcpServers.prefix(2)) { server in
                        ChipButton(
                            icon: "server.rack",
                            label: server.name,
                            hint: "Connect",
                            color: .blue
                        ) {
                            onConnectMCP?(server)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
    }
}

/// A single suggestion chip button.
private struct ChipButton: View {
    let icon: String
    let label: String
    let hint: String?
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)

                Text(label)
                    .fontWeight(.medium)

                if let hint = hint {
                    Text(hint)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                color.opacity(0.1),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Suggestion Logic

extension Session {
    /// Extract keywords from recent user messages.
    private func recentMessageKeywords() -> Set<String> {
        let stopWords: Set<String> = ["the", "a", "an", "and", "or", "to", "for", "with", "from", "in", "on", "of", "is", "are", "was", "were", "be", "been", "being", "have", "has", "had", "do", "does", "did", "will", "would", "could", "should", "may", "might", "must", "can", "this", "that", "these", "those", "it", "its", "you", "your", "i", "my", "we", "our", "they", "their", "not", "please", "help", "want", "need", "like", "get", "make"]

        let recentMessages = messages
            .filter { $0.role == .user }
            .suffix(3)
            .map(\.text)
            .joined(separator: " ")

        let words = recentMessages.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stopWords.contains($0) }

        return Set(words)
    }

    /// Suggest agents based on conversation context.
    func suggestedAgents() -> [CustomAgent] {
        let keywords = recentMessageKeywords()
        guard !keywords.isEmpty else { return [] }

        let agents = AgentManager.shared.agents

        let scored: [(CustomAgent, Int)] = agents.map { agent in
            let overlap = agent.keywords.intersection(keywords).count
            return (agent, overlap)
        }
        .filter { $0.1 > 0 }
        .sorted { $0.1 > $1.1 }

        return Array(scored.prefix(2).map(\.0))
    }

    /// Suggest MCP servers based on conversation context (excludes already connected servers).
    func suggestedMCPServers() -> [MCPServerPreset] {
        let keywords = recentMessageKeywords()
        guard !keywords.isEmpty else { return [] }

        // Get IDs of already configured servers
        let configuredNames = Set(MCPManager.shared.servers.map { $0.name.lowercased() })

        let scored: [(MCPServerPreset, Int)] = MCPCatalog.servers
            .filter { !configuredNames.contains($0.name.lowercased()) }
            .map { preset in
                let overlap = preset.keywords.intersection(keywords).count
                return (preset, overlap)
            }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }

        return Array(scored.prefix(2).map(\.0))
    }
}
