import SwiftUI

/// Renders markdown text with support for headers, code blocks, lists, inline formatting,
/// and file change badges.
struct MarkdownText: View {
    let text: String
    var bodyFontSize: CGFloat = 13
    var onFileChangeTapped: ((Int) -> Void)?

    // Parsed once and cached for the view body
    private var parsed: (stripped: String, changes: [FileChange]) {
        FileChangeParser.stripFileChanges(text)
    }

    var body: some View {
        let result = parsed
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(parseBlocks(from: result.stripped, changes: result.changes).enumerated()), id: \.offset) { _, block in
                blockView(block, changes: result.changes)
            }
        }
    }

    // MARK: - Block types

    private enum Block {
        case heading(level: Int, text: String)
        case codeBlock(language: String?, code: String)
        case paragraph(String)
        case unorderedListItem(String)
        case orderedListItem(number: String, text: String)
        case divider
        case blank
        case fileChangeBadge(index: Int)
    }

    // MARK: - Rendering

    @ViewBuilder
    private func blockView(_ block: Block, changes: [FileChange]) -> some View {
        switch block {
        case .heading(let level, let text):
            headingView(level: level, text: text)
        case .codeBlock(_, let code):
            codeBlockView(code)
        case .paragraph(let text):
            inlineMarkdown(text)
                .font(.system(size: bodyFontSize))
                .textSelection(.enabled)
        case .unorderedListItem(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\u{2022}")
                    .foregroundStyle(.secondary)
                inlineMarkdown(text)
                    .font(.system(size: bodyFontSize))
                    .textSelection(.enabled)
            }
            .padding(.leading, 12)
        case .orderedListItem(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(number).")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                inlineMarkdown(text)
                    .font(.system(size: bodyFontSize))
                    .textSelection(.enabled)
            }
            .padding(.leading, 12)
        case .divider:
            Divider()
                .padding(.vertical, 4)
        case .blank:
            Spacer().frame(height: 4)
        case .fileChangeBadge(let index):
            if index < changes.count {
                FileChangeBadgeView(change: changes[index]) {
                    onFileChangeTapped?(index)
                }
            }
        }
    }

    private func headingView(level: Int, text: String) -> some View {
        let font: Font = switch level {
        case 1: .title
        case 2: .title2
        case 3: .title3
        default: .headline
        }

        return inlineMarkdown(text)
            .font(font)
            .fontWeight(.semibold)
            .padding(.top, level == 1 ? 8 : 4)
            .textSelection(.enabled)
    }

    private func codeBlockView(_ code: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(code)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    // MARK: - Inline markdown → Text

    private func inlineMarkdown(_ string: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: string,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        }
        return Text(string)
    }

    // MARK: - Block parser

    private let placeholderPrefix = "\u{FFFC}FILECHANGE:"
    private let placeholderSuffix = "\u{FFFC}"

    private func parseBlocks(from text: String, changes: [FileChange]) -> [Block] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [Block] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // File change placeholder
            if trimmed.hasPrefix(placeholderPrefix) && trimmed.hasSuffix(placeholderSuffix) {
                let start = trimmed.index(trimmed.startIndex, offsetBy: placeholderPrefix.count)
                let end = trimmed.index(trimmed.endIndex, offsetBy: -placeholderSuffix.count)
                if start < end, let idx = Int(trimmed[start..<end]) {
                    blocks.append(.fileChangeBadge(index: idx))
                }
                i += 1
                continue
            }

            // Code block (fenced)
            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count {
                    if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        i += 1
                        break
                    }
                    codeLines.append(lines[i])
                    i += 1
                }
                blocks.append(.codeBlock(
                    language: language.isEmpty ? nil : language,
                    code: codeLines.joined(separator: "\n")
                ))
                continue
            }

            // Heading
            if let heading = parseHeading(trimmed) {
                blocks.append(heading)
                i += 1
                continue
            }

            // Horizontal rule
            if trimmed.count >= 3 && trimmed.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" }) {
                let chars = Set(trimmed)
                if chars.count == 1 {
                    blocks.append(.divider)
                    i += 1
                    continue
                }
            }

            // Unordered list item
            if let rest = parseUnorderedListItem(trimmed) {
                blocks.append(.unorderedListItem(rest))
                i += 1
                continue
            }

            // Ordered list item
            if let (num, rest) = parseOrderedListItem(trimmed) {
                blocks.append(.orderedListItem(number: num, text: rest))
                i += 1
                continue
            }

            // Blank line
            if trimmed.isEmpty {
                if let last = blocks.last, case .blank = last {
                    // skip consecutive blanks
                } else {
                    blocks.append(.blank)
                }
                i += 1
                continue
            }

            // Regular paragraph — collect consecutive non-blank, non-special lines
            var paraLines: [String] = [line]
            i += 1
            while i < lines.count {
                let next = lines[i]
                let nextTrimmed = next.trimmingCharacters(in: .whitespaces)
                if nextTrimmed.isEmpty
                    || nextTrimmed.hasPrefix("```")
                    || nextTrimmed.hasPrefix(placeholderPrefix)
                    || parseHeading(nextTrimmed) != nil
                    || parseUnorderedListItem(nextTrimmed) != nil
                    || parseOrderedListItem(nextTrimmed) != nil
                {
                    break
                }
                paraLines.append(next)
                i += 1
            }
            blocks.append(.paragraph(paraLines.joined(separator: "\n")))
        }

        return blocks
    }

    private func parseHeading(_ line: String) -> Block? {
        var level = 0
        for ch in line {
            if ch == "#" { level += 1 }
            else { break }
        }
        guard level >= 1 && level <= 6 && line.count > level else { return nil }
        let rest = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
        guard !rest.isEmpty else { return nil }
        return .heading(level: level, text: rest)
    }

    private func parseUnorderedListItem(_ line: String) -> String? {
        if (line.hasPrefix("- ") || line.hasPrefix("* ")) && line.count > 2 {
            return String(line.dropFirst(2))
        }
        return nil
    }

    private func parseOrderedListItem(_ line: String) -> (String, String)? {
        let parts = line.split(separator: ".", maxSplits: 1)
        guard parts.count == 2,
              let _ = Int(parts[0]),
              parts[1].hasPrefix(" ") else { return nil }
        return (String(parts[0]), String(parts[1]).trimmingCharacters(in: .whitespaces))
    }
}
