import SwiftUI
import UIKit

struct MovementRemindersView: View {
    @Environment(UserDataCoordinator.self) private var dataCoordinator
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var preferences = MovementReminderPreferences.off
    @State private var needsPermission = false

    var body: some View {
        Form {
            Section {
                Toggle("Reminders", isOn: enabledBinding)
                    .tint(TreniraColor.action)
            } footer: {
                Text("Off until you turn them on. trenira only reminds you at the time you choose.")
                    .font(TreniraType.caption)
            }

            if needsPermission {
                Section {
                    Text("Notifications are off for trenira in iOS Settings, so a reminder can't be delivered. Allow notifications there, then return here.")
                        .font(TreniraType.body)
                        .foregroundStyle(TreniraColor.label)
                    Button("Open iOS notification settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            openURL(url)
                        }
                    }
                } header: {
                    Text("Notifications are off")
                }
            }

            if preferences.enabled {
                Section {
                    Picker("Frequency", selection: frequencyBinding) {
                        ForEach(MovementReminderFrequency.allCases) { frequency in
                            Text(frequency.title).tag(frequency)
                        }
                    }
                    Text(preferences.frequency.summary)
                        .font(TreniraType.caption)
                        .foregroundStyle(TreniraColor.labelSecondary)
                    DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                } header: {
                    Text("When")
                }

                if preferences.frequency == .selectedDays {
                    Section {
                        ForEach(weekdayRows, id: \.weekday) { row in
                            Toggle(row.title, isOn: weekdayBinding(row.weekday))
                                .tint(TreniraColor.action)
                        }
                    } header: {
                        Text("Days")
                    } footer: {
                        Text(preferences.weekdays.isEmpty
                             ? "Choose at least one day. Nothing is sent until you do."
                             : "A reminder is sent only on these days.")
                            .font(TreniraType.caption)
                    }
                }

                if preferences.frequency == .weeklyReflection {
                    Section {
                        Picker("Day", selection: weeklyDayBinding) {
                            ForEach(weekdayRows, id: \.weekday) { row in
                                Text(row.title).tag(row.weekday)
                            }
                        }
                    } footer: {
                        Text("One reflection reminder on this day. It opens your week, not a workout.")
                            .font(TreniraType.caption)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(TreniraColor.canvas)
        .navigationTitle("Movement reminders")
        .navigationBarTitleDisplayMode(.inline)
        .tint(TreniraColor.action)
        .onAppear(perform: load)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refreshPermission() }
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { preferences.enabled },
            set: { enabled in
                Task { await setEnabled(enabled) }
            }
        )
    }

    private var frequencyBinding: Binding<MovementReminderFrequency> {
        Binding(
            get: { preferences.frequency },
            set: { frequency in
                preferences.frequency = frequency
                if frequency == .weeklyReflection, !(1...7).contains(preferences.weeklyWeekday) {
                    preferences.weeklyWeekday = Calendar.current.component(.weekday, from: .now)
                }
                Task { await save() }
            }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { date(hour: preferences.hour, minute: preferences.minute) },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                preferences.hour = parts.hour ?? preferences.hour
                preferences.minute = parts.minute ?? preferences.minute
                Task { await save() }
            }
        )
    }

    private var weeklyDayBinding: Binding<Int> {
        Binding(
            get: { preferences.weeklyWeekday },
            set: { weekday in
                preferences.weeklyWeekday = weekday
                Task { await save() }
            }
        )
    }

    private func weekdayBinding(_ weekday: Int) -> Binding<Bool> {
        Binding(
            get: { preferences.weekdays.contains(weekday) },
            set: { selected in
                if selected {
                    preferences.weekdays.append(weekday)
                } else {
                    preferences.weekdays.removeAll { $0 == weekday }
                }
                preferences = preferences.sanitized()
                Task { await save() }
            }
        )
    }

    private var weekdayRows: [(weekday: Int, title: String)] {
        Calendar.current.weekdaySymbols.enumerated().map { index, title in
            (weekday: index + 1, title: title)
        }
    }

    private var sessionActive: Bool {
        authManager.authState != .signedOut
    }

    private func load() {
        preferences = MovementReminderStore.load(ownerId: dataCoordinator.currentOwner.rawValue)
        Task { await refreshPermission() }
    }

    private func setEnabled(_ enabled: Bool) async {
        let result = await MovementReminderController.live.setEnabled(
            enabled,
            ownerId: dataCoordinator.currentOwner.rawValue,
            preferences: preferences
        )
        preferences = result.0
        needsPermission = result.1 == .needsPermission
    }

    private func save() async {
        let note = await MovementReminderController.live.save(
            preferences,
            ownerId: dataCoordinator.currentOwner.rawValue,
            sessionActive: sessionActive
        )
        preferences = MovementReminderStore.load(ownerId: dataCoordinator.currentOwner.rawValue)
        needsPermission = note == .needsPermission
    }

    private func refreshPermission() async {
        let note = await MovementReminderController.live.apply(
            ownerId: dataCoordinator.currentOwner.rawValue,
            sessionActive: sessionActive
        )
        preferences = MovementReminderStore.load(ownerId: dataCoordinator.currentOwner.rawValue)
        needsPermission = note == .needsPermission && preferences.enabled
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? .now
    }
}

struct WeeklyReflectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UserDataCoordinator.self) private var dataCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TreniraSpace.section) {
                Text("Your week")
                    .font(TreniraType.largeTitle)
                    .foregroundStyle(TreniraColor.label)
                    .accessibilityAddTraits(.isHeader)
                Text(DiaryReflection.weekly(activityCount: weekRecords.isEmpty ? 0 : weekRecords.count))
                    .font(TreniraType.body)
                    .foregroundStyle(TreniraColor.label)
                    .fixedSize(horizontal: false, vertical: true)
                Text(weekLine)
                    .font(TreniraType.caption)
                    .foregroundStyle(TreniraColor.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Back to home") { dismiss() }
                    .buttonStyle(TreniraPrimaryButtonStyle())
            }
            .padding(TreniraSpace.screen)
        }
        .background(TreniraColor.canvas)
        .navigationTitle("This week")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var weekRecords: [MovementRecord] {
        let records = MovementRecordStore.load(ownerId: dataCoordinator.currentOwner.rawValue)
        return MovementDiary.records(records, inWeekOf: .now)
    }

    private var weekLine: String {
        let summary = MovementDiary.summary(of: weekRecords)
        if summary.activityCount == 0 { return DiaryReflection.noMovement }
        let days = summary.dayCount == 1 ? "1 day" : "\(summary.dayCount) days"
        return "\(days) · \(MovementDurationFormat.exact(summary.activeSeconds))"
    }
}
