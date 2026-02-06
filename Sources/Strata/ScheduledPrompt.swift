import Foundation

/// A prompt that runs automatically on a schedule.
struct ScheduledPrompt: Identifiable, Codable {
    let id: UUID
    var name: String
    var prompt: String
    var workingDirectory: String
    var schedule: Schedule
    var isEnabled: Bool
    var notifyOnComplete: Bool
    var createdAt: Date
    var lastRunAt: Date?
    var lastResult: ScheduleResult?

    init(
        id: UUID = UUID(),
        name: String,
        prompt: String,
        workingDirectory: String,
        schedule: Schedule,
        isEnabled: Bool = true,
        notifyOnComplete: Bool = true
    ) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.workingDirectory = workingDirectory
        self.schedule = schedule
        self.isEnabled = isEnabled
        self.notifyOnComplete = notifyOnComplete
        self.createdAt = Date()
    }

    /// Calculate the next run date from now.
    func nextRunDate(after date: Date = Date()) -> Date? {
        guard isEnabled else { return nil }
        return schedule.nextDate(after: date)
    }
}

// MARK: - Schedule

enum Schedule: Codable, Equatable {
    case once(Date)
    case daily(hour: Int, minute: Int)
    case weekdays(hour: Int, minute: Int)  // Mon-Fri
    case weekly(dayOfWeek: Int, hour: Int, minute: Int)  // 1=Sunday, 2=Monday, etc.
    case interval(TimeInterval)  // Run every N seconds

    /// Human-readable description of the schedule.
    var displayText: String {
        switch self {
        case .once(let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return "Once on \(formatter.string(from: date))"
        case .daily(let hour, let minute):
            return "Daily at \(formatTime(hour: hour, minute: minute))"
        case .weekdays(let hour, let minute):
            return "Weekdays at \(formatTime(hour: hour, minute: minute))"
        case .weekly(let day, let hour, let minute):
            let dayName = Calendar.current.weekdaySymbols[day - 1]
            return "Every \(dayName) at \(formatTime(hour: hour, minute: minute))"
        case .interval(let seconds):
            if seconds < 60 {
                return "Every \(Int(seconds)) seconds"
            } else if seconds < 3600 {
                return "Every \(Int(seconds / 60)) minutes"
            } else {
                return "Every \(Int(seconds / 3600)) hours"
            }
        }
    }

    /// Calculate the next occurrence after the given date.
    func nextDate(after date: Date) -> Date? {
        let calendar = Calendar.current

        switch self {
        case .once(let scheduledDate):
            return scheduledDate > date ? scheduledDate : nil

        case .daily(let hour, let minute):
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = hour
            components.minute = minute
            components.second = 0

            guard let candidate = calendar.date(from: components) else { return nil }
            if candidate > date {
                return candidate
            }
            return calendar.date(byAdding: .day, value: 1, to: candidate)

        case .weekdays(let hour, let minute):
            var current = date
            for _ in 0..<8 {  // Check up to 8 days ahead
                var components = calendar.dateComponents([.year, .month, .day], from: current)
                components.hour = hour
                components.minute = minute
                components.second = 0

                guard let candidate = calendar.date(from: components) else { return nil }
                let weekday = calendar.component(.weekday, from: candidate)

                // Weekday: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
                let isWeekday = weekday >= 2 && weekday <= 6

                if isWeekday && candidate > date {
                    return candidate
                }
                current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
            }
            return nil

        case .weekly(let dayOfWeek, let hour, let minute):
            var current = date
            for _ in 0..<8 {
                var components = calendar.dateComponents([.year, .month, .day], from: current)
                components.hour = hour
                components.minute = minute
                components.second = 0

                guard let candidate = calendar.date(from: components) else { return nil }
                let weekday = calendar.component(.weekday, from: candidate)

                if weekday == dayOfWeek && candidate > date {
                    return candidate
                }
                current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
            }
            return nil

        case .interval(let seconds):
            return date.addingTimeInterval(seconds)
        }
    }

    private func formatTime(hour: Int, minute: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }
}

// MARK: - Schedule Result

struct ScheduleResult: Identifiable, Codable {
    let id: UUID
    let scheduledPromptId: UUID
    let startedAt: Date
    let completedAt: Date
    let success: Bool
    let responseText: String?
    let errorMessage: String?

    init(
        scheduledPromptId: UUID,
        startedAt: Date,
        completedAt: Date = Date(),
        success: Bool,
        responseText: String? = nil,
        errorMessage: String? = nil
    ) {
        self.id = UUID()
        self.scheduledPromptId = scheduledPromptId
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.success = success
        self.responseText = responseText
        self.errorMessage = errorMessage
    }

    var duration: TimeInterval {
        completedAt.timeIntervalSince(startedAt)
    }
}
