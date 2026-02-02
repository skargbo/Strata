import SwiftUI

// MARK: - Inspector Panel

struct DiffInspectorView: View {
    let changes: [FileChange]
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Label("Changes", systemImage: "doc.text.magnifyingglass")
                    .font(.headline)

                Text("\(changes.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.orange, in: Capsule())

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // File changes list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(changes) { change in
                        FileChangeCard(change: change)
                    }
                }
                .padding(12)
            }
        }
    }
}

// MARK: - File Change Card

struct FileChangeCard: View {
    let change: FileChange
    @State private var isExpanded = false
    @State private var isHovered = false

    private var previewLines: [DiffLine] {
        Array(change.diffLines.prefix(3))
    }

    private var hasMoreLines: Bool {
        change.diffLines.count > 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 8) {
                // Color-coded icon with tinted background
                Image(systemName: iconName(for: change.action))
                    .font(.caption)
                    .foregroundStyle(iconColor(for: change.action))
                    .frame(width: 24, height: 24)
                    .background(
                        iconColor(for: change.action).opacity(0.12),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 2) {
                    // Action label
                    Text(change.action.rawValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(iconColor(for: change.action))

                    // File path
                    Text(change.filePath)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.primary)
                }

                Spacer()

                // Expand/collapse chevron
                if !change.diffLines.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Summary line
            if !change.summaryLine.isEmpty {
                Text(change.summaryLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 32)
            }

            // Diff content
            if !change.diffLines.isEmpty {
                let linesToShow = isExpanded ? change.diffLines : previewLines

                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(linesToShow) { line in
                            DiffLineView(line: line)
                        }
                    }
                }
                .font(.system(.caption, design: .monospaced))
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )

                // Show all / Collapse toggle
                if hasMoreLines {
                    HoverTextButton(
                        text: isExpanded
                            ? "Collapse"
                            : "Show all (\(change.diffLines.count) lines)"
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isExpanded.toggle()
                        }
                    }
                    .padding(.leading, 4)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(isHovered ? 0.10 : 0.06), radius: isHovered ? 8 : 6, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(isHovered ? 0.15 : 0.08), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Diff Line

struct DiffLineView: View {
    let line: DiffLine

    var body: some View {
        HStack(spacing: 0) {
            // Line number gutter
            if let num = line.lineNumber {
                Text(String(format: "%4d", num))
                    .foregroundStyle(.tertiary)
                    .frame(width: 36, alignment: .trailing)
            } else {
                Spacer().frame(width: 36)
            }

            // Change indicator
            Text(indicator)
                .foregroundStyle(foregroundColor)
                .frame(width: 16, alignment: .center)

            // Code content
            Text(line.text)
                .foregroundStyle(foregroundColor)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
        .padding(.trailing, 4)
        .background(backgroundColor)
    }

    private var indicator: String {
        switch line.kind {
        case .addition: "+"
        case .removal: "-"
        case .context: " "
        case .ellipsis: ""
        }
    }

    private var foregroundColor: Color {
        switch line.kind {
        case .addition: .blue
        case .removal: .orange
        case .context: Color.primary
        case .ellipsis: Color.secondary
        }
    }

    private var backgroundColor: Color {
        switch line.kind {
        case .addition: .blue.opacity(0.08)
        case .removal: .orange.opacity(0.08)
        case .context, .ellipsis: .clear
        }
    }
}

// MARK: - Inline Badge (for use in chat)

struct FileChangeBadgeView: View {
    let change: FileChange
    var onTap: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: iconName(for: change.action))
                    .foregroundStyle(iconColor(for: change.action))
                Text(change.action.rawValue)
                    .fontWeight(.medium)
                Text(change.fileName)
                    .font(.system(.caption, design: .monospaced))
                if !change.summaryLine.isEmpty {
                    Text("(\(change.summaryLine))")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor).opacity(isHovered ? 0.7 : 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.primary.opacity(isHovered ? 0.15 : 0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - FocusedValue for menu bar toggle

struct DiffPanelToggleKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var diffPanelToggle: Binding<Bool>? {
        get { self[DiffPanelToggleKey.self] }
        set { self[DiffPanelToggleKey.self] = newValue }
    }
}

// MARK: - Helpers

func iconName(for action: FileChangeAction) -> String {
    switch action {
    case .update: "pencil.circle.fill"
    case .write: "doc.fill"
    case .create: "plus.circle.fill"
    case .read: "eye.circle.fill"
    case .delete: "trash.circle.fill"
    }
}

func iconColor(for action: FileChangeAction) -> Color {
    switch action {
    case .update: .orange
    case .write: .blue
    case .create: .green
    case .read: .gray
    case .delete: .red
    }
}

// MARK: - Hover Text Button

private struct HoverTextButton: View {
    let text: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption2)
                .foregroundStyle(isHovered ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}
