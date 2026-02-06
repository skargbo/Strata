import Foundation
import UserNotifications

/// Manages scheduled prompts — persistence, timer scheduling, and execution.
@Observable
final class ScheduleManager {
    var schedules: [ScheduledPrompt] = []
    var isRunningSchedule: Bool = false
    var currentlyRunningId: UUID?

    private var timers: [UUID: Timer] = [:]
    private weak var sessionManager: SessionManager?
    private var scheduledRunsGroupId: UUID?

    /// Name for the auto-created sidebar group
    private static let scheduledRunsGroupName = "Scheduled Runs"

    private let storageURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let strataDir = appSupport.appendingPathComponent("Strata", isDirectory: true)
        try? FileManager.default.createDirectory(at: strataDir, withIntermediateDirectories: true)
        return strataDir.appendingPathComponent("schedules.json")
    }()

    init(sessionManager: SessionManager? = nil) {
        self.sessionManager = sessionManager
        loadSchedules()
        scheduleAllTimers()
        requestNotificationPermission()
    }

    /// Connect to the session manager (called after init if not provided)
    func connect(to sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        // Find existing "Scheduled Runs" group if it exists
        self.scheduledRunsGroupId = sessionManager.groups.first { $0.name == Self.scheduledRunsGroupName }?.id
    }

    // MARK: - CRUD

    func add(_ schedule: ScheduledPrompt) {
        schedules.append(schedule)
        saveSchedules()
        scheduleTimer(for: schedule)
    }

    func update(_ schedule: ScheduledPrompt) {
        guard let index = schedules.firstIndex(where: { $0.id == schedule.id }) else { return }
        schedules[index] = schedule
        saveSchedules()

        // Reschedule timer
        cancelTimer(for: schedule.id)
        if schedule.isEnabled {
            scheduleTimer(for: schedule)
        }
    }

    func delete(_ schedule: ScheduledPrompt) {
        cancelTimer(for: schedule.id)
        schedules.removeAll { $0.id == schedule.id }
        saveSchedules()
    }

    func toggle(_ schedule: ScheduledPrompt) {
        guard let index = schedules.firstIndex(where: { $0.id == schedule.id }) else { return }
        schedules[index].isEnabled.toggle()
        saveSchedules()

        if schedules[index].isEnabled {
            scheduleTimer(for: schedules[index])
        } else {
            cancelTimer(for: schedule.id)
        }
    }

    // MARK: - Execution

    func runNow(_ schedule: ScheduledPrompt) {
        guard !isRunningSchedule else { return }
        executeSchedule(schedule)
    }

    private func executeSchedule(_ schedule: ScheduledPrompt) {
        guard let sessionManager = sessionManager,
              let index = schedules.firstIndex(where: { $0.id == schedule.id }) else { return }

        isRunningSchedule = true
        currentlyRunningId = schedule.id

        // Try to find existing session if reusing
        var session: Session?

        if schedule.reuseSession, let lastId = schedule.lastSessionId {
            // Look for existing session
            if let anySession = sessionManager.sessions.first(where: { $0.id == lastId }),
               case .claude(let existingSession) = anySession {
                session = existingSession
            }
        }

        // Create new session if needed
        if session == nil {
            let groupId = getOrCreateScheduledRunsGroup()

            // Create session name
            let sessionName: String
            if schedule.reuseSession {
                // Persistent session - just use the schedule name
                sessionName = schedule.name
            } else {
                // One-off session - include timestamp
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, h:mm a"
                sessionName = "\(schedule.name) — \(formatter.string(from: Date()))"
            }

            let newSession = sessionManager.newSession(
                name: sessionName,
                workingDirectory: schedule.workingDirectory
            )

            // Move session to the Scheduled Runs group
            if let groupId = groupId {
                sessionManager.moveSession(.claude(newSession), to: sessionManager.groups.first { $0.id == groupId })
            }

            // Configure session for scheduled execution
            newSession.settings.permissionMode = schedule.permissionMode.rawValue
            newSession.settings.customSystemPrompt = "You are running as a scheduled task. Be concise in your response."

            session = newSession

            // Save the session ID for future reuse
            if schedule.reuseSession {
                schedules[index].lastSessionId = newSession.id
            }
        }

        guard let session = session else { return }

        // Track when we started
        let startedAt = Date()

        // Listen for completion to update our records
        session.onComplete = { [weak self] fullText, _, _ in
            guard let self = self else { return }

            let result = ScheduleResult(
                scheduledPromptId: schedule.id,
                startedAt: startedAt,
                success: true,
                responseText: fullText
            )

            self.recordResult(result, for: schedule.id)
            self.isRunningSchedule = false
            self.currentlyRunningId = nil
        }

        session.onError = { [weak self] error in
            guard let self = self else { return }

            let result = ScheduleResult(
                scheduledPromptId: schedule.id,
                startedAt: startedAt,
                success: false,
                errorMessage: error
            )

            self.recordResult(result, for: schedule.id)
            self.isRunningSchedule = false
            self.currentlyRunningId = nil
        }

        // Send the prompt
        session.send(schedule.prompt)

        // Update last run time
        schedules[index].lastRunAt = Date()
        saveSchedules()
    }

    /// Get or create the "Scheduled Runs" sidebar group
    private func getOrCreateScheduledRunsGroup() -> UUID? {
        guard let sessionManager = sessionManager else { return nil }

        // Check if we already have the group ID cached
        if let groupId = scheduledRunsGroupId,
           sessionManager.groups.contains(where: { $0.id == groupId }) {
            return groupId
        }

        // Look for existing group by name
        if let existing = sessionManager.groups.first(where: { $0.name == Self.scheduledRunsGroupName }) {
            scheduledRunsGroupId = existing.id
            return existing.id
        }

        // Create new group
        let group = sessionManager.createGroup(name: Self.scheduledRunsGroupName)
        scheduledRunsGroupId = group.id
        return group.id
    }

    // MARK: - Timer Management

    private func scheduleAllTimers() {
        for schedule in schedules where schedule.isEnabled {
            scheduleTimer(for: schedule)
        }
    }

    private func scheduleTimer(for schedule: ScheduledPrompt) {
        guard schedule.isEnabled,
              let nextRun = schedule.nextRunDate() else { return }

        let interval = nextRun.timeIntervalSinceNow
        guard interval > 0 else {
            // Already past, schedule for next occurrence
            if schedule.nextRunDate(after: Date().addingTimeInterval(1)) != nil {
                scheduleTimer(for: ScheduledPrompt(
                    id: schedule.id,
                    name: schedule.name,
                    prompt: schedule.prompt,
                    workingDirectory: schedule.workingDirectory,
                    schedule: schedule.schedule,
                    isEnabled: schedule.isEnabled,
                    notifyOnComplete: schedule.notifyOnComplete
                ))
            }
            return
        }

        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self = self,
                  let current = self.schedules.first(where: { $0.id == schedule.id }),
                  current.isEnabled else { return }

            self.executeSchedule(current)

            // Schedule next run
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.scheduleTimer(for: current)
            }
        }

        timers[schedule.id] = timer
    }

    private func cancelTimer(for id: UUID) {
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
    }

    // MARK: - Result Recording

    private func recordResult(_ result: ScheduleResult, for scheduleId: UUID) {
        guard let index = schedules.firstIndex(where: { $0.id == scheduleId }) else { return }

        schedules[index].lastResult = result
        saveSchedules()

        // Send notification if enabled
        if schedules[index].notifyOnComplete {
            sendNotification(for: schedules[index], result: result)
        }
    }

    // MARK: - Notifications

    /// Check if we're running as a proper app bundle (not via swift run)
    private var canUseNotifications: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    private func requestNotificationPermission() {
        guard canUseNotifications else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendNotification(for schedule: ScheduledPrompt, result: ScheduleResult) {
        guard canUseNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = result.success ? "Scheduled Task Complete" : "Scheduled Task Failed"
        content.subtitle = schedule.name
        content.sound = .default

        if result.success, let response = result.responseText {
            // Truncate for notification
            let preview = response.prefix(200)
            content.body = String(preview) + (response.count > 200 ? "..." : "")
        } else if let error = result.errorMessage {
            content.body = "Error: \(error)"
        }

        let request = UNNotificationRequest(
            identifier: result.id.uuidString,
            content: content,
            trigger: nil  // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Persistence

    private func loadSchedules() {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let loaded = try? JSONDecoder().decode([ScheduledPrompt].self, from: data) else {
            return
        }
        schedules = loaded
    }

    private func saveSchedules() {
        guard let data = try? JSONEncoder().encode(schedules) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}
