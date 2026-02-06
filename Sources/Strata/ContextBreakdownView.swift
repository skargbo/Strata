import SwiftUI

/// Expandable popover showing breakdown of context token usage by source.
struct ContextBreakdownView: View {
    let breakdown: ContextBreakdown
    let totalTokens: Int
    let maxTokens: Int
    let cacheReadTokens: Int

    private var usagePercent: Double {
        guard maxTokens > 0 else { return 0 }
        return Double(totalTokens) / Double(maxTokens)
    }

    private var categories: [(label: String, tokens: Int, color: Color)] {
        [
            ("Conversation", breakdown.conversationTokens, .blue),
            ("Tool Results", breakdown.toolResultTokens, .purple),
            ("System Prompt", breakdown.systemPromptTokens, .orange)
        ].filter { $0.tokens > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Context Usage")
                    .font(.headline)
                Spacer()
                Text("\(Int(usagePercent * 100))%")
                    .font(.headline)
                    .foregroundStyle(usagePercent > 0.8 ? .red : (usagePercent > 0.5 ? .orange : .green))
            }

            // Total bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.08))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(usagePercent > 0.8 ? Color.red : (usagePercent > 0.5 ? Color.orange : Color.green))
                        .frame(width: geo.size.width * min(usagePercent, 1.0))
                }
            }
            .frame(height: 8)

            Text("\(totalTokens.formatted()) / \(maxTokens.formatted()) tokens")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Category breakdown
            VStack(alignment: .leading, spacing: 8) {
                ForEach(categories, id: \.label) { category in
                    CategoryRow(
                        label: category.label,
                        tokens: category.tokens,
                        total: totalTokens,
                        color: category.color
                    )
                }
            }

            // Files in context
            if !breakdown.filesInContext.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Files in context")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    ForEach(breakdown.filesInContext.suffix(5)) { file in
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                                .font(.caption)
                                .foregroundStyle(.blue)

                            Text((file.path as NSString).lastPathComponent)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Text("\(file.tokens.formatted()) tokens")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    if breakdown.filesInContext.count > 5 {
                        Text("+ \(breakdown.filesInContext.count - 5) more files")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Cache savings
            if cacheReadTokens > 0 {
                Divider()

                HStack(spacing: 6) {
                    Image(systemName: "memorychip")
                        .foregroundStyle(.green)
                    Text("Cache: \(cacheReadTokens.formatted()) tokens")
                        .font(.caption)

                    Spacer()

                    let savingsPercent = Double(cacheReadTokens) / Double(max(totalTokens, 1)) * 100
                    Text("\(Int(savingsPercent))% savings")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}

private struct CategoryRow: View {
    let label: String
    let tokens: Int
    let total: Int
    let color: Color

    private var percent: Double {
        guard total > 0 else { return 0 }
        return Double(tokens) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.caption)
                Spacer()
                Text("\(tokens.formatted())")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("(\(Int(percent * 100))%)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.06))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.7))
                        .frame(width: geo.size.width * min(percent, 1.0))
                }
            }
            .frame(height: 4)
        }
    }
}
