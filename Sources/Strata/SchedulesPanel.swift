import SwiftUI

/// Panel for managing scheduled prompts.
struct SchedulesPanel: View {
    @Bindable var manager: ScheduleManager
    @State private var showNewSchedule = false
    @State private var selectedSchedule: ScheduledPrompt?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if manager.schedules.isEmpty {
                    emptyState
                } else {
                    scheduleList
                }
            }
            .navigationTitle("Scheduled Prompts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewSchedule = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewSchedule) {
                ScheduleEditorView(manager: manager)
            }
            .sheet(item: $selectedSchedule) { schedule in
                ScheduleEditorView(manager: manager, editing: schedule)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No Scheduled Prompts")
                .font(.title2)
                .fontWeight(.medium)

            Text("Schedule prompts to run automatically at specific times.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showNewSchedule = true
            } label: {
                Label("Create Schedule", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
    }

    private var scheduleList: some View {
        List {
            ForEach(manager.schedules) { schedule in
                ScheduleRow(
                    schedule: schedule,
                    isRunning: manager.currentlyRunningId == schedule.id,
                    onToggle: { manager.toggle(schedule) },
                    onRunNow: { manager.runNow(schedule) },
                    onEdit: { selectedSchedule = schedule },
                    onDelete: { manager.delete(schedule) }
                )
            }
        }
    }
}

// MARK: - Schedule Row

private struct ScheduleRow: View {
    let schedule: ScheduledPrompt
    let isRunning: Bool
    let onToggle: () -> Void
    let onRunNow: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var nextRunText: String {
        guard schedule.isEnabled, let next = schedule.nextRunDate() else {
            return "Disabled"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: next, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(schedule.isEnabled ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)

                if isRunning {
                    Circle()
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: 16, height: 16)
                        .rotationEffect(.degrees(isRunning ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isRunning)
                }
            }
            .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(schedule.name)
                    .font(.headline)

                Text(schedule.prompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(schedule.schedule.displayText, systemImage: "clock")
                    Text("·")
                    Text("Next: \(nextRunText)")

                    if let lastResult = schedule.lastResult {
                        Text("·")
                        Image(systemName: lastResult.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(lastResult.success ? .green : .red)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            // Action buttons (visible on hover)
            if isHovered || isRunning {
                HStack(spacing: 8) {
                    if isRunning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button {
                            onRunNow()
                        } label: {
                            Image(systemName: "play.fill")
                        }
                        .buttonStyle(.plain)
                        .help("Run Now")
                    }

                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.plain)
                    .help("Edit")

                    Toggle("", isOn: Binding(
                        get: { schedule.isEnabled },
                        set: { _ in onToggle() }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Run Now") { onRunNow() }
                .disabled(isRunning)
            Button("Edit...") { onEdit() }
            Divider()
            Button(schedule.isEnabled ? "Disable" : "Enable") { onToggle() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
}

// MARK: - Schedule Editor

struct ScheduleEditorView: View {
    @Bindable var manager: ScheduleManager
    var editing: ScheduledPrompt?

    @State private var name: String = ""
    @State private var prompt: String = ""
    @State private var workingDirectory: String = NSHomeDirectory()
    @State private var scheduleType: ScheduleType = .daily
    @State private var selectedHour: Int = 9
    @State private var selectedMinute: Int = 0
    @State private var selectedDay: Int = 2  // Monday
    @State private var intervalMinutes: Int = 60
    @State private var notifyOnComplete: Bool = true

    @Environment(\.dismiss) private var dismiss

    enum ScheduleType: String, CaseIterable {
        case daily = "Daily"
        case weekdays = "Weekdays"
        case weekly = "Weekly"
        case interval = "Interval"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Prompt", text: $prompt, axis: .vertical)
                        .lineLimit(3...6)

                    HStack {
                        Text("Working Directory")
                        Spacer()
                        Button(workingDirectory.abbreviatingHome) {
                            pickDirectory()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }

                Section("Schedule") {
                    Picker("Frequency", selection: $scheduleType) {
                        ForEach(ScheduleType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    switch scheduleType {
                    case .daily, .weekdays:
                        timePicker

                    case .weekly:
                        Picker("Day", selection: $selectedDay) {
                            ForEach(1...7, id: \.self) { day in
                                Text(Calendar.current.weekdaySymbols[day - 1]).tag(day)
                            }
                        }
                        timePicker

                    case .interval:
                        Stepper("Every \(intervalMinutes) minutes", value: $intervalMinutes, in: 1...1440, step: 5)
                    }
                }

                Section("Options") {
                    Toggle("Notify when complete", isOn: $notifyOnComplete)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(editing == nil ? "New Schedule" : "Edit Schedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing == nil ? "Create" : "Save") {
                        save()
                        dismiss()
                    }
                    .disabled(name.isEmpty || prompt.isEmpty)
                }
            }
            .onAppear {
                if let schedule = editing {
                    loadFromSchedule(schedule)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 350)
    }

    private var timePicker: some View {
        HStack {
            Picker("Hour", selection: $selectedHour) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(formatHour(hour)).tag(hour)
                }
            }
            .frame(width: 100)

            Text(":")

            Picker("Minute", selection: $selectedMinute) {
                ForEach([0, 15, 30, 45], id: \.self) { minute in
                    Text(String(format: "%02d", minute)).tag(minute)
                }
            }
            .frame(width: 80)
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = hour
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }

    private func loadFromSchedule(_ schedule: ScheduledPrompt) {
        name = schedule.name
        prompt = schedule.prompt
        workingDirectory = schedule.workingDirectory
        notifyOnComplete = schedule.notifyOnComplete

        switch schedule.schedule {
        case .daily(let hour, let minute):
            scheduleType = .daily
            selectedHour = hour
            selectedMinute = minute
        case .weekdays(let hour, let minute):
            scheduleType = .weekdays
            selectedHour = hour
            selectedMinute = minute
        case .weekly(let day, let hour, let minute):
            scheduleType = .weekly
            selectedDay = day
            selectedHour = hour
            selectedMinute = minute
        case .interval(let seconds):
            scheduleType = .interval
            intervalMinutes = Int(seconds / 60)
        case .once:
            scheduleType = .daily  // Fallback
        }
    }

    private func buildSchedule() -> Schedule {
        switch scheduleType {
        case .daily:
            return .daily(hour: selectedHour, minute: selectedMinute)
        case .weekdays:
            return .weekdays(hour: selectedHour, minute: selectedMinute)
        case .weekly:
            return .weekly(dayOfWeek: selectedDay, hour: selectedHour, minute: selectedMinute)
        case .interval:
            return .interval(TimeInterval(intervalMinutes * 60))
        }
    }

    private func save() {
        let schedule = ScheduledPrompt(
            id: editing?.id ?? UUID(),
            name: name,
            prompt: prompt,
            workingDirectory: workingDirectory,
            schedule: buildSchedule(),
            isEnabled: editing?.isEnabled ?? true,
            notifyOnComplete: notifyOnComplete
        )

        if editing != nil {
            manager.update(schedule)
        } else {
            manager.add(schedule)
        }
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: workingDirectory)

        if panel.runModal() == .OK, let url = panel.url {
            workingDirectory = url.path
        }
    }
}

