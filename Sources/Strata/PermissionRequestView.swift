import SwiftUI

/// A sheet that asks the user to allow or deny a tool use.
struct PermissionRequestView: View {
    let request: PermissionRequest
    let onAllow: () -> Void
    let onDeny: () -> Void
    var queueCount: Int = 0  // How many more requests are queued after this one

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 36, height: 36)
                    .background(iconColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Permission Request")
                            .font(.headline)
                        if queueCount > 0 {
                            Text("+\(queueCount) more")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange, in: Capsule())
                        }
                    }
                    Text("Claude wants to use **\(request.toolName)**")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(20)

            Divider()

            // Details
            VStack(alignment: .leading, spacing: 12) {
                // Warning if path is outside working directory
                if request.isOutsideWorkingDirectory {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Outside working directory")
                                .font(.caption)
                                .fontWeight(.semibold)
                            if let cwd = request.workingDirectory {
                                Text(cwd)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }

                Text(request.displayDescription)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Show input details
                if !request.inputSummary.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(
                            Array(request.inputSummary.sorted(by: { $0.key < $1.key })),
                            id: \.key
                        ) { key, value in
                            HStack(alignment: .top, spacing: 8) {
                                Text(key)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .trailing)

                                Text(value)
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(4)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }

                if let reason = request.reason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)

            Divider()

            // Buttons
            HStack(spacing: 12) {
                Spacer()

                Button("Deny") {
                    onDeny()
                }
                .keyboardShortcut(.escape)
                .controlSize(.large)

                Button("Allow") {
                    onAllow()
                }
                .keyboardShortcut(.return)
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(width: 460)
    }

    private var iconName: String {
        switch request.toolName {
        case "Bash": return "terminal.fill"
        case "Edit": return "pencil"
        case "Write": return "doc.fill"
        case "Read": return "doc.text.fill"
        case "Glob", "Grep": return "magnifyingglass"
        default: return "wrench.fill"
        }
    }

    private var iconColor: Color {
        switch request.toolName {
        case "Bash": return .orange
        case "Edit", "Write": return .blue
        case "Read": return .green
        default: return .purple
        }
    }
}
