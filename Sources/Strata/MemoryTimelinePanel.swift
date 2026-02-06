import SwiftUI

/// Inspector panel showing chronological history of what Claude accessed during the session.
struct MemoryTimelinePanel: View {
    let memoryEvents: [MemoryEvent]
    @Binding var isPresented: Bool

    private var groupedEvents: [(key: String, events: [MemoryEvent])] {
        let calendar = Calendar.current
        let now = Date()

        let grouped = Dictionary(grouping: memoryEvents.reversed()) { event -> String in
            if calendar.isDateInToday(event.timestamp) {
                return "Today"
            } else if calendar.isDateInYesterday(event.timestamp) {
                return "Yesterday"
            } else if calendar.isDate(event.timestamp, equalTo: now, toGranularity: .weekOfYear) {
                return "This Week"
            } else {
                return "Earlier"
            }
        }

        let order = ["Today", "Yesterday", "This Week", "Earlier"]
        return order.compactMap { key in
            guard let events = grouped[key] else { return nil }
            return (key: key, events: events)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("Memory Timeline", systemImage: "clock.arrow.circlepath")
                    .font(.headline)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if memoryEvents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)

                    Text("No events yet")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Text("Events will appear here as Claude reads files, runs commands, and makes changes.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16, pinnedViews: .sectionHeaders) {
                        ForEach(groupedEvents, id: \.key) { group in
                            Section {
                                ForEach(group.events) { event in
                                    MemoryEventCard(event: event)
                                }
                            } header: {
                                Text(group.key)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.bar)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct MemoryEventCard: View {
    let event: MemoryEvent

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Timeline dot and line
            VStack(spacing: 0) {
                Circle()
                    .fill(event.type.color)
                    .frame(width: 10, height: 10)
            }
            .frame(width: 16)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: event.type.icon)
                        .font(.caption)
                        .foregroundStyle(event.type.color)

                    Text(event.type.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(timeFormatter.string(from: event.timestamp))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(event.title)
                    .font(.callout)
                    .lineLimit(2)

                if let detail = event.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(event.type.color.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview

#Preview {
    MemoryTimelinePanel(
        memoryEvents: [
            MemoryEvent(
                timestamp: Date(),
                type: .fileRead,
                title: "Session.swift",
                detail: "@Observable final class Session...",
                filePath: "/path/to/Session.swift"
            ),
            MemoryEvent(
                timestamp: Date().addingTimeInterval(-60),
                type: .commandExecuted,
                title: "swift build",
                detail: "Build Succeeded",
                filePath: nil
            ),
            MemoryEvent(
                timestamp: Date().addingTimeInterval(-120),
                type: .fileEdited,
                title: "ChatMessage.swift",
                detail: "+15 lines, -3 lines",
                filePath: "/path/to/ChatMessage.swift"
            ),
            MemoryEvent(
                timestamp: Date().addingTimeInterval(-180),
                type: .taskCreated,
                title: "Implement context visualization",
                detail: nil,
                filePath: nil
            )
        ],
        isPresented: .constant(true)
    )
    .frame(width: 320, height: 500)
}
