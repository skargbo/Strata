import SwiftUI

/// Scope options for "Allow for Session"
enum PermissionScope: Identifiable, CaseIterable {
    case thisOnly       // Just this one request
    case thisPath       // This exact file/command
    case parentDir      // All in parent directory
    case allTool        // All uses of this tool

    var id: Self { self }

    func label(for request: PermissionRequest) -> String {
        switch self {
        case .thisOnly:
            return "This request only"
        case .thisPath:
            if let path = request.inputSummary["file_path"] ?? request.inputSummary["path"] {
                return "This file: \((path as NSString).lastPathComponent)"
            } else if let cmd = request.inputSummary["command"] {
                let short = cmd.count > 30 ? String(cmd.prefix(27)) + "..." : cmd
                return "This command: \(short)"
            }
            return "This exact request"
        case .parentDir:
            if let path = request.inputSummary["file_path"] ?? request.inputSummary["path"] {
                let dir = (path as NSString).deletingLastPathComponent
                return "All in \((dir as NSString).lastPathComponent)/"
            }
            return "All similar"
        case .allTool:
            return "All \(request.toolName) operations"
        }
    }

    func toApproval(for request: PermissionRequest) -> SessionPermissionApproval? {
        let path = request.inputSummary["file_path"] ?? request.inputSummary["path"]

        switch self {
        case .thisOnly:
            return nil  // No session approval, just allow this one
        case .thisPath:
            return SessionPermissionApproval(toolName: request.toolName, pathPattern: path)
        case .parentDir:
            if let path = path {
                let dir = (path as NSString).deletingLastPathComponent
                return SessionPermissionApproval(toolName: request.toolName, pathPattern: dir + "/*")
            }
            return SessionPermissionApproval(toolName: request.toolName, pathPattern: nil)
        case .allTool:
            return SessionPermissionApproval(toolName: request.toolName, pathPattern: nil)
        }
    }

    /// Whether this scope option is applicable for the given request
    func isApplicable(for request: PermissionRequest) -> Bool {
        switch self {
        case .thisOnly, .allTool:
            return true
        case .thisPath, .parentDir:
            // Only applicable for file-based tools
            let path = request.inputSummary["file_path"] ?? request.inputSummary["path"]
            return path != nil
        }
    }
}

/// A sheet that asks the user to allow or deny a tool use.
struct PermissionRequestView: View {
    let request: PermissionRequest
    let onAllow: () -> Void
    let onDeny: () -> Void
    var onAllowForSession: ((SessionPermissionApproval?) -> Void)?
    var queueCount: Int = 0  // How many more requests are queued after this one

    @State private var selectedScope: PermissionScope = .allTool
    @State private var showScopeOptions: Bool = false

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

            // Scope picker (shown when "Allow for Session" is selected)
            if showScopeOptions && onAllowForSession != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Allow for this session:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(applicableScopes) { scope in
                        HStack(spacing: 8) {
                            Image(systemName: selectedScope == scope ? "circle.inset.filled" : "circle")
                                .foregroundStyle(selectedScope == scope ? .blue : .secondary)
                                .font(.system(size: 14))

                            Text(scope.label(for: request))
                                .font(.callout)

                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedScope = scope
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.quaternary.opacity(0.5))
            }

            // Buttons
            HStack(spacing: 12) {
                Spacer()

                Button("Deny") {
                    onDeny()
                }
                .keyboardShortcut(.escape)
                .controlSize(.large)

                if onAllowForSession != nil {
                    Button(showScopeOptions ? "Confirm for Session" : "Allow for Session") {
                        if showScopeOptions {
                            // Confirm the selection
                            let approval = selectedScope.toApproval(for: request)
                            onAllowForSession?(approval)
                        } else {
                            // Show scope options
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showScopeOptions = true
                            }
                        }
                    }
                    .controlSize(.large)
                }

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

    /// Get applicable scope options for this request
    private var applicableScopes: [PermissionScope] {
        PermissionScope.allCases.filter { $0.isApplicable(for: request) }
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
