import SwiftUI

/// A visually distinct card showing a tool invocation inline in the chat.
struct ToolActivityRow: View {
    let activity: ToolActivity
    @State private var isExpanded: Bool

    @State private var isHovered: Bool = false

    init(activity: ToolActivity, defaultExpanded: Bool = false) {
        self.activity = activity
        self._isExpanded = State(initialValue: defaultExpanded)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Colored left accent bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(activity.accentColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 0) {
                // Compact header (always visible)
                compactHeader

                // Expanded detail
                if isExpanded {
                    Divider()
                        .padding(.horizontal, 12)
                    expandedContent
                        .padding(12)
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(isHovered ? 0.15 : 0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.06 : 0), radius: 6, y: 2)
        .padding(.horizontal, 4)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    // MARK: - Header

    private var compactHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: activity.iconName)
                    .font(.callout)
                    .foregroundStyle(activity.iconColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.summaryText)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let detail = activity.detailSummary {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if hasExpandableContent {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var hasExpandableContent: Bool {
        switch activity.toolName {
        case "Bash": return activity.result.stdout != nil || activity.result.stderr != nil
        case "Edit": return activity.result.diffLines != nil
        case "Read": return activity.result.fileContent != nil
        case "Glob", "Grep": return activity.result.filenames != nil
        case "Write": return activity.input.filePath != nil
        default: return false
        }
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private var expandedContent: some View {
        switch activity.toolName {
        case "Bash":
            bashDetail
        case "Edit":
            editDetail
        case "Read":
            readDetail
        case "Glob", "Grep":
            searchDetail
        case "Write":
            writeDetail
        default:
            EmptyView()
        }
    }

    // MARK: - Bash

    private var bashDetail: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let command = activity.input.command {
                codeBlock(command)
            }
            if let stdout = activity.result.stdout, !stdout.isEmpty {
                ScrollView(.vertical) {
                    Text(stdout.prefix(2000))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
            }
            if let stderr = activity.result.stderr, !stderr.isEmpty {
                Text(stderr.prefix(500))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Edit (diff)

    private var editDetail: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let path = activity.input.filePath {
                Text(path.abbreviatingHome)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if let diffLines = activity.result.diffLines {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(diffLines) { line in
                            DiffLineView(line: line)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                }
                .padding(4)
                .background(
                    Color(nsColor: .controlBackgroundColor).opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 4)
                )
            }
        }
    }

    // MARK: - Read

    private var readDetail: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let path = activity.input.filePath {
                Text(path.abbreviatingHome)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if let content = activity.result.fileContent {
                let lines = content.components(separatedBy: "\n")
                let preview = lines.prefix(20).joined(separator: "\n")
                let truncated = lines.count > 20

                codeBlock(preview + (truncated ? "\n\u{2026} (\(lines.count) lines total)" : ""))
            }
        }
    }

    // MARK: - Glob / Grep

    private var searchDetail: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let filenames = activity.result.filenames {
                let display = filenames.prefix(15)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(display.enumerated()), id: \.offset) { _, name in
                        Text(name.abbreviatingHome)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    if filenames.count > 15 {
                        Text("\u{2026} and \(filenames.count - 15) more")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Write

    private var writeDetail: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let path = activity.input.filePath {
                Text(path.abbreviatingHome)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Helpers

    private func codeBlock(_ text: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            Color(nsColor: .controlBackgroundColor).opacity(0.5),
            in: RoundedRectangle(cornerRadius: 4)
        )
    }
}
