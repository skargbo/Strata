import SwiftUI

/// Displays the conversation as a list of message bubbles.
struct ChatView: View {
    let messages: [ChatMessage]
    let isResponding: Bool
    var respondingStartedAt: Date? = nil
    var toolCardsDefaultExpanded: Bool = false
    var messageSpacing: CGFloat = 12
    var bodyFontSize: CGFloat = 13
    var onFileChangeTapped: ((Int) -> Void)?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: messageSpacing) {
                    Color.clear
                        .frame(height: 0)
                        .id("scroll-top")

                    ForEach(messages) { message in
                        if message.role == .tool, let activity = message.toolActivity {
                            ToolActivityRow(activity: activity, defaultExpanded: toolCardsDefaultExpanded)
                                .id(message.id)
                                .padding(.horizontal, 12)
                        } else {
                            MessageRow(message: message, bodyFontSize: bodyFontSize, onFileChangeTapped: onFileChangeTapped)
                                .id(message.id)
                        }
                    }

                    if isResponding {
                        ThinkingIndicator(
                            label: activityLabel,
                            startedAt: respondingStartedAt
                        )
                        .padding(.horizontal, 16)
                        .id("activity-indicator")
                    }
                }
                .padding(.vertical, 16)
            }
            .onChange(of: messages.count) {
                scrollToBottom(proxy)
            }
            .onChange(of: messages.last?.text) {
                scrollToBottom(proxy)
            }
        }
    }

    private var activityLabel: String {
        guard let last = messages.last else { return "Thinking..." }

        if last.role == .tool {
            return "Working..."
        }

        if last.role == .assistant, !last.text.isEmpty {
            return "Responding..."
        }

        return "Thinking..."
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let lastId = messages.last?.id {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}

struct MessageRow: View {
    let message: ChatMessage
    var bodyFontSize: CGFloat = 13
    var onFileChangeTapped: ((Int) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Role icon
            Group {
                switch message.role {
                case .user:
                    Image(systemName: "person.circle.fill")
                        .foregroundStyle(.blue)
                case .assistant:
                    Image(systemName: "square.stack.3d.down.dottedline")
                        .foregroundStyle(.orange)
                case .system:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                case .tool:
                    Image(systemName: "wrench.fill")
                        .foregroundStyle(.purple)
                }
            }
            .font(.title3)
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                // Role label
                Text(roleLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                // Message content
                if message.text.isEmpty && message.role == .assistant {
                    Text("...")
                        .foregroundStyle(.tertiary)
                } else if message.role == .assistant {
                    MarkdownText(text: message.text, bodyFontSize: bodyFontSize, onFileChangeTapped: onFileChangeTapped)
                        .foregroundStyle(.primary)
                } else {
                    Text(message.text)
                        .textSelection(.enabled)
                        .font(.system(size: bodyFontSize))
                        .foregroundStyle(message.role == .system ? .secondary : .primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 4)
    }

    private var bubbleBackground: Color {
        switch message.role {
        case .assistant: Color.orange.opacity(0.04)
        case .user: Color.blue.opacity(0.04)
        case .system, .tool: Color.clear
        }
    }

    private var roleLabel: String {
        switch message.role {
        case .user: return "You"
        case .assistant: return "Claude"
        case .system: return "System"
        case .tool: return "Tool"
        }
    }
}

// MARK: - Thinking Indicator with Timer

/// Shows a spinner with activity label and elapsed time.
struct ThinkingIndicator: View {
    let label: String
    let startedAt: Date?

    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)

            Text(label)
                .foregroundStyle(.secondary)
                .font(.callout)

            if elapsedSeconds > 0 {
                Text("for \(formattedElapsedTime)")
                    .foregroundStyle(.tertiary)
                    .font(.callout)
                    .monospacedDigit()
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: startedAt) {
            startTimer()
        }
    }

    /// Formats elapsed time as "Xs", "Xm Ys", or "Xh Ym" depending on duration.
    private var formattedElapsedTime: String {
        if elapsedSeconds < 60 {
            return "\(elapsedSeconds)s"
        } else if elapsedSeconds < 3600 {
            let minutes = elapsedSeconds / 60
            let seconds = elapsedSeconds % 60
            return "\(minutes)m \(seconds)s"
        } else {
            let hours = elapsedSeconds / 3600
            let minutes = (elapsedSeconds % 3600) / 60
            return "\(hours)h \(minutes)m"
        }
    }

    private func startTimer() {
        stopTimer()
        updateElapsed()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateElapsed()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateElapsed() {
        guard let start = startedAt else {
            elapsedSeconds = 0
            return
        }
        elapsedSeconds = Int(Date().timeIntervalSince(start))
    }
}
