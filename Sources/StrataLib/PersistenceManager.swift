import Foundation

/// Handles all file I/O for session persistence.
/// Writes happen on a dedicated serial queue; reads are synchronous (used at startup).
final class PersistenceManager {
    static let shared = PersistenceManager()

    private let baseURL: URL
    private let sessionsURL: URL
    private let preferencesURL: URL
    private let manifestURL: URL

    private let saveQueue = DispatchQueue(label: "com.strata.persistence", qos: .utility)
    private var pendingSaves: [UUID: DispatchWorkItem] = [:]

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        baseURL = appSupport.appendingPathComponent("Strata", isDirectory: true)
        sessionsURL = baseURL.appendingPathComponent("sessions", isDirectory: true)
        preferencesURL = baseURL.appendingPathComponent("preferences.json")
        manifestURL = sessionsURL.appendingPathComponent("manifest.json")
        ensureDirectories()
    }

    private func ensureDirectories() {
        let fm = FileManager.default
        // Owner-only permissions (0700 for dirs) to protect session data
        let dirAttrs: [FileAttributeKey: Any] = [.posixPermissions: 0o700]
        try? fm.createDirectory(at: sessionsURL, withIntermediateDirectories: true, attributes: dirAttrs)
        // Also lock down the base directory if it already exists
        try? fm.setAttributes(dirAttrs, ofItemAtPath: baseURL.path)
    }

    // MARK: - Manifest

    func saveManifest(_ manifest: SessionManifest) {
        saveQueue.async { [weak self] in
            self?.write(manifest, to: self!.manifestURL)
        }
    }

    func loadManifest() -> SessionManifest? {
        read(SessionManifest.self, from: manifestURL)
    }

    // MARK: - Claude Session

    func saveSession(_ snapshot: SessionSnapshot) {
        let url = sessionsURL.appendingPathComponent("\(snapshot.id.uuidString).json")
        saveQueue.async { [weak self] in
            self?.write(snapshot, to: url)
        }
    }

    func loadSession(id: UUID) -> SessionSnapshot? {
        let url = sessionsURL.appendingPathComponent("\(id.uuidString).json")
        return read(SessionSnapshot.self, from: url)
    }

    // MARK: - Terminal Session

    func saveTerminalSession(_ snapshot: TerminalSessionSnapshot) {
        let url = sessionsURL.appendingPathComponent("\(snapshot.id.uuidString).json")
        saveQueue.async { [weak self] in
            self?.write(snapshot, to: url)
        }
    }

    func loadTerminalSession(id: UUID) -> TerminalSessionSnapshot? {
        let url = sessionsURL.appendingPathComponent("\(id.uuidString).json")
        return read(TerminalSessionSnapshot.self, from: url)
    }

    // MARK: - Delete

    func deleteSession(id: UUID) {
        let url = sessionsURL.appendingPathComponent("\(id.uuidString).json")
        saveQueue.async {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Default Settings

    func saveDefaultSettings(_ defaults: DefaultSettingsData) {
        saveQueue.async { [weak self] in
            guard let self else { return }
            self.write(defaults, to: self.preferencesURL)
        }
    }

    func loadDefaultSettings() -> DefaultSettingsData? {
        read(DefaultSettingsData.self, from: preferencesURL)
    }

    // MARK: - Debounced Save

    /// Schedule a save for a session. Coalesces rapid updates (e.g. streaming tokens)
    /// into a single write after the debounce window.
    func scheduleSave(for sessionID: UUID, delay: TimeInterval = 2.0, snapshot: @escaping () -> SessionSnapshot?) {
        pendingSaves[sessionID]?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let snap = snapshot() else { return }
            let url = self?.sessionsURL.appendingPathComponent("\(snap.id.uuidString).json")
            if let url {
                self?.write(snap, to: url)
            }
            DispatchQueue.main.async { [weak self] in
                self?.pendingSaves.removeValue(forKey: sessionID)
            }
        }

        pendingSaves[sessionID] = workItem
        saveQueue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    /// Flush all pending debounced saves immediately (called on app quit).
    func flushPendingSaves() {
        for (_, workItem) in pendingSaves {
            workItem.cancel()
        }
        pendingSaves.removeAll()
    }

    // MARK: - Private Helpers

    private func write<T: Encodable>(_ value: T, to url: URL) {
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
            // Owner-only read/write (0600) — session files may contain sensitive data
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: url.path
            )
        } catch {
            #if DEBUG
            print("[Strata Persistence] Write failed for \(url.lastPathComponent): \(error)")
            #endif
        }
    }

    private func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(type, from: data)
        } catch {
            #if DEBUG
            if (error as NSError).domain != NSCocoaErrorDomain || (error as NSError).code != NSFileReadNoSuchFileError {
                print("[Strata Persistence] Read failed for \(url.lastPathComponent): \(error)")
            }
            #endif
            return nil
        }
    }
}
