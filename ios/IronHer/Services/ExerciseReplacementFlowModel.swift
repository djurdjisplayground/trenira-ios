import Foundation
import Observation

enum ExerciseReplacementStep: Equatable {
    case selectReason
    case recommendations(reason: ExerciseReplacementReason)
    case selectScope(reason: ExerciseReplacementReason, replacement: ExerciseRecommendation)
}

enum ExerciseReplacementLoadState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case failed(String)
}

/// Explicit multi-step state for the Replace Exercise sheet.
@Observable
@MainActor
final class ExerciseReplacementFlowModel {
    private(set) var step: ExerciseReplacementStep = .selectReason
    private(set) var selectedReason: ExerciseReplacementReason?
    private(set) var recommendations: [ExerciseRecommendation] = []
    private(set) var selectedReplacement: ExerciseRecommendation?
    private(set) var loadState: ExerciseReplacementLoadState = .idle
    private(set) var shouldDismiss = false
    private(set) var statusMessage: String?

    let workoutId: UUID
    let entryId: UUID
    let isActiveSession: Bool
    let originalEntry: WorkoutExerciseEntry
    let originalExercise: Exercise

    private let rankingService: ExerciseReplacementService
    private var loadGeneration = 0

    init(
        workoutId: UUID,
        entryId: UUID,
        isActiveSession: Bool,
        originalEntry: WorkoutExerciseEntry,
        originalExercise: Exercise,
        rankingService: ExerciseReplacementService = ExerciseReplacementService()
    ) {
        self.workoutId = workoutId
        self.entryId = entryId
        self.isActiveSession = isActiveSession
        self.originalEntry = originalEntry
        self.originalExercise = originalExercise
        self.rankingService = rankingService
    }

    var isLoading: Bool {
        if case .loading = loadState { return true }
        return false
    }

    var navigationTitle: String {
        switch step {
        case .selectReason:
            return "Replace Exercise"
        case .recommendations(let reason):
            return reason == .cannotIncreaseWeight ? "Make this exercise harder" : "Replace Exercise"
        case .selectScope:
            return "Replace Exercise"
        }
    }

    var recommendationsSupportingText: String {
        switch selectedReason {
        case .cannotIncreaseWeight:
            return "Here are alternatives that can be more challenging without requiring heavier weight."
        case .equipmentUnavailable:
            return "Alternatives that keep a similar training focus with different equipment."
        case .discomfort:
            return "Alternatives that target the same muscles with a different feel."
        case .variety:
            return "Fresh options that preserve the intent of this exercise."
        case .other, .none:
            return "Suggested alternatives for this exercise."
        }
    }

    func selectReason(_ reason: ExerciseReplacementReason) {
        guard !isLoading else { return }

        selectedReason = reason
        selectedReplacement = nil
        statusMessage = nil
        loadGeneration += 1
        let generation = loadGeneration

        loadState = .loading
        step = .recommendations(reason: reason)
        recommendations = []

        // Defer ranking to the next main-queue turn so the loading UI can paint.
        // Prefer `DispatchQueue.main.async` over `Task { @MainActor }` to avoid
        // AX/Observation `unsafeForcedSync` diagnostics from a Swift concurrency frame.
        DispatchQueue.main.async { [weak self] in
            guard let self, generation == self.loadGeneration else { return }

            let results = self.rankingService.recommendations(
                for: self.originalExercise,
                reason: reason,
                from: ExerciseCatalog.all,
                currentReps: self.originalEntry.reps
            )

            guard generation == self.loadGeneration else { return }

            self.recommendations = results
            self.loadState = results.isEmpty ? .empty : .loaded
        }
    }

    func selectReplacement(_ recommendation: ExerciseRecommendation) {
        selectedReplacement = recommendation
        guard let reason = selectedReason else { return }
        step = .selectScope(reason: reason, replacement: recommendation)
    }

    func clearSelectedReplacement() {
        selectedReplacement = nil
        if let reason = selectedReason {
            step = .recommendations(reason: reason)
        } else {
            step = .selectReason
        }
    }

    func goBack() {
        switch step {
        case .selectReason:
            cancel()

        case .recommendations:
            loadGeneration += 1
            selectedReason = nil
            selectedReplacement = nil
            recommendations = []
            loadState = .idle
            statusMessage = nil
            step = .selectReason

        case .selectScope:
            selectedReplacement = nil
            if let reason = selectedReason {
                step = .recommendations(reason: reason)
            } else {
                step = .selectReason
            }
        }
    }

    func cancel() {
        loadGeneration += 1
        shouldDismiss = true
    }

    func noteStatus(_ message: String) {
        statusMessage = message
    }

    func retryRecommendations() {
        guard let reason = selectedReason else { return }
        selectReason(reason)
    }
}
