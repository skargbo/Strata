import AppKit
import Combine
import SwiftUI

enum AppVersion {
    static let current = "1.5.0"
}

@main
struct StrataApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var manager = SessionManager()
    @State private var scheduleManager = ScheduleManager()

    var body: some Scene {
        WindowGroup {
            ContentView(manager: manager, scheduleManager: scheduleManager)
                .preferredColorScheme(manager.appearanceMode.colorScheme)
                .onAppear {
                    // Connect schedule manager to session manager
                    scheduleManager.connect(to: manager)
                }
                .onChange(of: manager.appearanceMode, initial: true) { _, newMode in
                    // Resolve the NSAppearance for the selected mode
                    let resolved: NSAppearance? = {
                        switch newMode {
                        case .dark:  return NSAppearance(named: .darkAqua)
                        case .light: return NSAppearance(named: .aqua)
                        case .auto:  return nil
                        }
                    }()

                    // Set app-wide default for new windows
                    NSApp.appearance = resolved

                    // Force ALL existing windows (including popovers, sheets)
                    // to adopt the appearance immediately so AppKit-backed
                    // controls like NSPopUpButton repaint in the right mode.
                    for window in NSApp.windows {
                        window.appearance = resolved
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    manager.saveAll()
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 700)
        .commands {
            AppCommands(manager: manager)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Transform from CLI process to a proper GUI app so it can
        // receive keyboard focus when launched via `swift run`.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.applicationIconImage = Self.makeAppIcon()
    }

    /// Renders a macOS app icon programmatically — a rounded-rect with a
    /// sparkle glyph, matching the app's visual identity.
    private static func makeAppIcon() -> NSImage {
        let size: CGFloat = 512
        let image = NSImage(size: NSSize(width: size, height: size))

        image.lockFocus()

        let bounds = NSRect(x: 0, y: 0, width: size, height: size)

        // Background: rounded super-ellipse (macOS icon shape)
        let iconPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 16, dy: 16),
                                    xRadius: 100, yRadius: 100)

        // Gradient fill: dark charcoal to near-black
        let gradient = NSGradient(
            starting: NSColor(calibratedRed: 0.18, green: 0.18, blue: 0.20, alpha: 1),
            ending: NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.10, alpha: 1)
        )
        gradient?.draw(in: iconPath, angle: -90)

        // Subtle inner border
        NSColor.white.withAlphaComponent(0.1).setStroke()
        iconPath.lineWidth = 2
        iconPath.stroke()

        // Sparkle symbol (matches the assistant icon used in chat)
        if let symbolImage = NSImage(
            systemSymbolName: "square.stack.3d.down.dottedline",
            accessibilityDescription: "Claude"
        ) {
            let config = NSImage.SymbolConfiguration(pointSize: 180, weight: .medium)
            let configured = symbolImage.withSymbolConfiguration(config) ?? symbolImage

            // Tint orange
            let tinted = NSImage(size: configured.size)
            tinted.lockFocus()
            NSColor.orange.set()
            let symbolBounds = NSRect(origin: .zero, size: configured.size)
            configured.draw(in: symbolBounds)
            symbolBounds.fill(using: .sourceIn)
            tinted.unlockFocus()

            // Center the sparkle in the icon
            let symbolSize = tinted.size
            let x = (size - symbolSize.width) / 2
            let y = (size - symbolSize.height) / 2
            tinted.draw(
                in: NSRect(x: x, y: y, width: symbolSize.width, height: symbolSize.height),
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0
            )
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
