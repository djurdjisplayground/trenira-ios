import SwiftUI

struct MovementCheckInView: View {
    var onFinished: () -> Void = {}
    @State private var minutes: MovementMinutes?
    @State private var energy: MovementEnergy?
    @State private var setting: MovementSetting?
    @State private var suggestion: MovementSuggestionRoute?

    private var profile: CompanionProfile {
        CompanionProfileStore.load() ?? CompanionProfile(skipped: true)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TreniraSpace.section) {
                Text("What fits today?")
                    .font(TreniraType.title)
                    .foregroundStyle(TreniraColor.label)
                    .accessibilityAddTraits(.isHeader)
                Text("Time, energy, and where you are. Then a suggestion that fits.")
                    .font(TreniraType.body)
                    .foregroundStyle(TreniraColor.labelSecondary)

                question("How much time do you have?", options: MovementMinutes.allCases, title: { $0.title }, selected: { minutes == $0 }) {
                    minutes = $0
                }
                question("How is your energy?", options: MovementEnergy.allCases, title: { $0.title }, selected: { energy == $0 }) {
                    energy = $0
                }
                question("Where are you?", options: MovementSetting.allCases, title: { $0.title }, selected: { setting == $0 }) {
                    setting = $0
                }

                Button("See a suggestion") {
                    guard let minutes, let energy, let setting else { return }
                    AnalyticsService.capture(
                        .dailyCheckInCompleted,
                        properties: [
                            "minutes": String(minutes.rawValue),
                            "setting": setting.rawValue
                        ]
                    )
                    suggestion = MovementSuggestionRoute(minutes: minutes, energy: energy, setting: setting)
                }
                .buttonStyle(TreniraPrimaryButtonStyle())
                .disabled(minutes == nil || energy == nil || setting == nil)
            }
            .padding(TreniraSpace.screen)
        }
        .background(TreniraColor.canvas)
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $suggestion) { route in
            MovementSuggestionView(profile: profile, route: route, onFinished: onFinished)
        }
    }

    private func question<Item: Identifiable>(
        _ title: String,
        options: [Item],
        title optionTitle: @escaping (Item) -> String,
        selected: @escaping (Item) -> Bool,
        onTap: @escaping (Item) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: TreniraSpace.stack) {
            Text(title)
                .font(TreniraType.section)
                .foregroundStyle(TreniraColor.label)
            ForEach(options) { item in
                TreniraChoiceRow(title: optionTitle(item), isSelected: selected(item)) {
                    onTap(item)
                }
            }
        }
    }
}

struct MovementSuggestionRoute: Identifiable, Hashable {
    var minutes: MovementMinutes
    var energy: MovementEnergy
    var setting: MovementSetting
    var id: String { "\(minutes.rawValue)-\(energy.rawValue)-\(setting.rawValue)" }
}

struct MovementSuggestionView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(WorkoutSessionStore.self) private var sessionStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(LocalizationStore.self) private var l10n
    @Environment(TestingTimeStore.self) private var testingTimeStore
    @Environment(AppTabRouter.self) private var tabRouter
    @Environment(UserDataCoordinator.self) private var dataCoordinator

    let profile: CompanionProfile
    let route: MovementSuggestionRoute
    var onFinished: () -> Void

    @State private var startFlow: WorkoutStartFlow?
    @State private var pendingVideo: SavedVideo?
    @State private var offerVideoRecord = false
    @State private var videoCompletion: SavedVideo?
    @State private var recordWalk = false
    @State private var walkMinutes = 0
    @State private var selfRecord: ChosenMovement?

    private var ownerId: String { dataCoordinator.currentOwner.rawValue }

    private var suggestions: [MovementSuggestion] {
        let workouts = workoutStore.workouts
            .filter { !$0.isDraft && !$0.exercises.isEmpty && $0.deletedAt == nil }
            .map { SavedStrengthOption(id: $0.id, name: $0.name) }
        let videos = SavedVideoStore.load(ownerId: ownerId).map {
            SavedVideoOption(id: $0.id, title: $0.title, durationMinutes: $0.durationMinutes)
        }
        return MovementRecommendationEngine.suggest(
            profile: profile,
            checkIn: MovementCheckIn(minutes: route.minutes, energy: route.energy, setting: route.setting),
            workouts: workouts,
            savedVideos: videos
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TreniraSpace.section) {
                Text("Something that fits")
                    .font(TreniraType.title)
                    .foregroundStyle(TreniraColor.label)
                    .accessibilityAddTraits(.isHeader)
                ForEach(suggestions) { item in
                    suggestionCard(item)
                }
            }
            .padding(TreniraSpace.screen)
        }
        .background(TreniraColor.canvas)
        .navigationTitle("Suggestion")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $startFlow) { _ in
            WorkoutStartFlowCover(flow: $startFlow)
        }
        .onChange(of: startFlow?.id) { _, flowID in
            tabRouter.isWorkoutFlowPresented = flowID != nil
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, pendingVideo != nil {
                offerVideoRecord = true
            }
        }
        .confirmationDialog(
            "Did you do this video?",
            isPresented: $offerVideoRecord,
            titleVisibility: .visible
        ) {
            Button("Record it") {
                videoCompletion = pendingVideo
                pendingVideo = nil
            }
            Button("Not now", role: .cancel) {
                pendingVideo = nil
            }
        } message: {
            Text("Opening the video does not mark it done.")
        }
        .navigationDestination(isPresented: $recordWalk) {
            MovementWalkView(
                plannedMinutes: walkMinutes > 0 ? walkMinutes : route.minutes.rawValue,
                ownerId: ownerId,
                onFinished: onFinished
            )
        }
        .navigationDestination(item: $selfRecord) { choice in
            MovementSelfStartView(
                category: choice.category,
                ownerId: ownerId,
                plannedMinutes: choice.minutes,
                onFinished: onFinished
            )
        }
        .navigationDestination(item: $videoCompletion) { video in
            MovementCompletionView(
                title: video.title,
                kind: .externalVideo,
                plannedMinutes: video.durationMinutes,
                initialActualMinutes: video.durationMinutes ?? route.minutes.rawValue,
                videoId: video.id,
                ownerId: ownerId,
                onSaved: onFinished
            )
        }
    }

    private func suggestionCard(_ item: MovementSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.title)
                .font(TreniraType.section)
                .foregroundStyle(TreniraColor.label)
            Text(item.detail)
                .font(TreniraType.body)
                .foregroundStyle(TreniraColor.label)
                .fixedSize(horizontal: false, vertical: true)
            Text(item.reason)
                .font(TreniraType.caption)
                .foregroundStyle(TreniraColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if item.isActionable, let workoutId = item.workoutId,
               let workout = workoutStore.workout(id: workoutId) {
                Button("Start this workout") {
                    AnalyticsService.capture(.movementSuggestionSelected, properties: ["suggestion": "strength"])
                    startFlow = WorkoutStartCoordinator.begin(
                        workout: workout,
                        sessionStore: sessionStore,
                        globalProgress: globalProgressStore,
                        testingTime: testingTimeStore,
                        localization: l10n
                    )
                }
                .buttonStyle(TreniraPrimaryButtonStyle())
            } else if item.kind == .walk {
                Button("Record this walk") {
                    AnalyticsService.capture(.movementSuggestionSelected, properties: ["suggestion": "walk"])
                    walkMinutes = route.minutes.rawValue
                    recordWalk = true
                }
                .buttonStyle(TreniraPrimaryButtonStyle())
                if shorterMinutes < route.minutes.rawValue {
                    Button("Use \(shorterMinutes) minutes") {
                        AnalyticsService.capture(.movementSuggestionSelected, properties: ["suggestion": "walk"])
                        walkMinutes = shorterMinutes
                        recordWalk = true
                    }
                    .buttonStyle(TreniraSecondaryButtonStyle())
                }
            } else if item.kind == .selfDirected, let format = item.format {
                Button("Record your movement") {
                    let token = format.recordKind?.analyticsActivityType ?? "other"
                    AnalyticsService.capture(.movementSuggestionSelected, properties: ["suggestion": token])
                    selfRecord = ChosenMovement(category: format, minutes: route.minutes.rawValue)
                }
                .buttonStyle(TreniraPrimaryButtonStyle())
                if shorterMinutes < route.minutes.rawValue {
                    Button("Use \(shorterMinutes) minutes") {
                        let token = format.recordKind?.analyticsActivityType ?? "other"
                        AnalyticsService.capture(.movementSuggestionSelected, properties: ["suggestion": token])
                        selfRecord = ChosenMovement(category: format, minutes: shorterMinutes)
                    }
                    .buttonStyle(TreniraSecondaryButtonStyle())
                }
            } else if item.kind == .video, item.videoId == nil {
                NavigationLink {
                    SavedVideosView(ownerId: ownerId)
                } label: {
                    Text("Save a video")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TreniraSecondaryButtonStyle())
            } else if item.kind == .video, let videoId = item.videoId,
                      let video = SavedVideoStore.load(ownerId: ownerId).first(where: { $0.id == videoId }),
                      let url = video.url {
                Button("Open video") {
                    AnalyticsService.capture(.movementSuggestionSelected, properties: ["suggestion": "video"])
                    pendingVideo = video
                    openURL(url)
                }
                .buttonStyle(TreniraSecondaryButtonStyle())
                NavigationLink {
                    MovementCompletionView(
                        title: video.title,
                        kind: .externalVideo,
                        plannedMinutes: video.durationMinutes,
                        initialActualMinutes: video.durationMinutes ?? route.minutes.rawValue,
                        videoId: video.id,
                        ownerId: ownerId,
                        onSaved: onFinished
                    )
                } label: {
                    Text("Record this video")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TreniraSecondaryButtonStyle())
            }
            NavigationLink {
                MovementChoiceView(ownerId: ownerId, onFinished: onFinished)
            } label: {
                Text("Choose something else")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(TreniraSecondaryButtonStyle())
        }
        .treniraCard()
        .accessibilityElement(children: .combine)
    }

    private var shorterMinutes: Int {
        let minutes = route.minutes.rawValue
        return minutes > 2 ? max(2, minutes / 2) : 2
    }
}
