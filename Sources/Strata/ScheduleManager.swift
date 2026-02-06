import Foundation
import UserNotifications

/// Manages scheduled prompts — persistence, timer scheduling, and execution.
@Observable
final class ScheduleManager {
    var schedules: [ScheduledPrompt] = []
    var isRunningSchedule: Bool = false
    var currentlyRunningId: UUID?

    private var timers: [UUID: Timer] = [:]
    private let runner = ClaudeRunner()
    private var pendingResult: (id: UUID, startedAt: Date, response: String)?

    private let storageURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let strataDir = appSupport.appendingPathComponent("Strata", isDirectory: true)
        try? FileManager.default.createDirectory(at: strataDir, withIntermediateDirectories: true)
        return strataDir.appendingPathComponent("schedules.json")
    }()

    init() {
        loadSchedules()
        setupRunnerCallbacks()
        scheduleAllTimers()
        requestNotificationPermission()
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
        guard let index = schedules.firstIndex(where: { $0.id == schedule.id }) else { return }

        isRunningSchedule = true
        currentlyRunningId = schedule.id
        pendingResult = (id: schedule.id, startedAt: Date(), response: "")

        runner.send(
            message: schedule.prompt,
            workingDirectory: schedule.workingDirectory,
            permissionMode: "plan",  // Safe mode for scheduled tasks
            model: nil,
            systemPrompt: "You are running as a scheduled task. Be concise in your response."
        )

        // Update last run time
        schedules[index].lastRunAt = Date()
        saveSchedules()
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
            if let futureRun = schedule.nextRunDate(after: Date().addingTimeInterval(1)) {
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

    // MARK: - Runner Callbacks

    private func setupRunnerCallbacks() {
        runner.onSetText = { [weak self] text in
            guard let self = self, var pending = self.pendingResult else { return }
            pending.response = text
            self.pendingResult = pending
        }

        runner.onToken = { [weak self] token in
            guard let self = self, var pending = self.pendingResult else { return }
            pending.response += token
            self.pendingResult = pending
        }

        runner.onComplete = { [weak self] fullText, _, _ in
            guard let self = self, let pending = self.pendingResult else { return }

            let result = ScheduleResult(
                scheduledPromptId: pending.id,
                startedAt: pending.startedAt,
                success: true,
                responseText: pending.response.isEmpty ? fullText : pending.response
            )

            self.recordResult(result)
            self.isRunningSchedule = false
            self.currentlyRunningId = nil
            self.pendingResult = nil
        }

        runner.onError = { [weak self] error in
            guard let self = self, let pending = self.pendingResult else { return }

            let result = ScheduleResult(
                scheduledPromptId: pending.id,
                startedAt: pending.startedAt,
                success: false,
                errorMessage: error
            )

            self.recordResult(result)
            self.isRunningSchedule = false
            self.currentlyRunningId = nil
            self.pendingResult = nil
        }
    }

    private func recordResult(_ result: ScheduleResult) {
        guard let index = schedules.firstIndex(where: { $0.id == result.scheduledPromptId }) else { return }

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
