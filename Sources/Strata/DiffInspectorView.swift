import SwiftUI

// MARK: - Inspector Panel

struct DiffInspectorView: View {
    let changes: [FileChange]
    let tasks: [SessionTask]
    @Binding var isPresented: Bool

    @State private var changesExpanded = true
    @State private var tasksExpanded = true

    private var activeTasks: [SessionTask] {
        tasks.filter { $0.status != .deleted }
            .sorted { t1, t2 in
                let order: [SessionTask.TaskStatus] = [.in_progress, .pending, .completed]
                let i1 = order.firstIndex(of: t1.status) ?? 99
                let i2 = order.firstIndex(of: t2.status) ?? 99
                if i1 != i2 { return i1 < i2 }
                return (Int(t1.id) ?? 0) < (Int(t2.id) ?? 0)
            }
    }

    private var completedCount: Int {
        activeTasks.filter { $0.status == .completed }.count
    }

    private var inProgressTask: SessionTask? {
        activeTasks.first { $0.status == .in_progress }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top header with close button
            HStack {
                Text("Workspace")
                    .font(.headline)
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

            // Split content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // MARK: - Changes Section
                    InspectorSection(
                        title: "Changes",
                        icon: "doc.text.magnifyingglass",
                        count: changes.count,
                        countColor: .orange,
                        isExpanded: $changesExpanded
                    ) {
                        if changes.isEmpty {
                            Text("No file changes yet")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(changes) { change in
                                    FileChangeCard(change: change)
                                }
                            }
                        }
                    }

                    Divider()
                        .padding(.vertical, 8)

                    // MARK: - Tasks Section
                    InspectorSection(
                        title: "Todos",
                        icon: "checklist",
                        count: activeTasks.count,
                        countColor: .teal,
                        isExpanded: $tasksExpanded,
                        trailing: {
                            if !activeTasks.isEmpty {
                                Text("\(completedCount)/\(activeTasks.count)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    ) {
                        if activeTasks.isEmpty {
                            Text("No tasks yet")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                // Progress bar
                                if !activeTasks.isEmpty {
                                    TaskProgressIndicator(
                                        completed: completedCount,
                                        total: activeTasks.count,
                                        inProgressTask: inProgressTask
                                    )
                                    .padding(.bottom, 8)
                                }

                                // Task list
                                ForEach(activeTasks) { task in
                                    InspectorTaskRow(task: task)
                                }
                            }
                        }
                    }
                }
                .padding(12)
            }
        }
    }
}

// MARK: - Inspector Section

private struct InspectorSection<Content: View, Trailing: View>: View {
    let title: String
    let icon: String
    let count: Int
    let countColor: Color
    @Binding var isExpanded: Bool
    @ViewBuilder let trailing: () -> Trailing
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        icon: String,
        count: Int,
        countColor: Color,
        isExpanded: Binding<Bool>,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.count = count
        self.countColor = countColor
        self._isExpanded = isExpanded
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 10)

                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(countColor)

                    Text(title)
                        .font(.subheadline.weight(.medium))

                    if count > 0 {
                        Text("\(count)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(countColor, in: Capsule())
                    }

                    Spacer()

                    trailing()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Section content
            if isExpanded {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Task Progress Indicator

private struct TaskProgressIndicator: View {
    let completed: Int
    let total: Int
    let inProgressTask: SessionTask?

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.teal)
                        .frame(width: geo.size.width * min(progress, 1.0))
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)

            // Active task label
            if let active = inProgressTask {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.mini)
                    Text(active.activeForm ?? active.subject)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Inspector Task Row

private struct InspectorTaskRow: View {
    let task: SessionTask

    private var statusIcon: String {
        switch task.status {
        case .completed: return "checkmark.circle.fill"
        case .in_progress: return "circle.dotted"
        case .pending: return "circle"
        case .deleted: return "xmark.circle"
        }
    }

    private var statusColor: Color {
        switch task.status {
        case .completed: return .green
        case .in_progress: return .orange
        case .pending: return .secondary
        case .deleted: return .red
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            if task.status == .in_progress {
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: statusIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(statusColor)
                    .frame(width: 14, height: 14)
            }

            // Task subject
            Text(task.subject)
                .font(.caption)
                .foregroundStyle(task.status == .completed ? .secondary : .primary)
                .strikethrough(task.status == .completed)
                .lineLimit(2)

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            task.status == .in_progress
                ? Color.orange.opacity(0.1)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 4)
        )
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
                    Text(change.filePath.abbreviatingHome)
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
