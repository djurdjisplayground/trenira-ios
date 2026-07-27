import Foundation
import Observation

/// Single rest countdown for an active workout. Uses an end date for background accuracy.
@Observable
@MainActor
final class RestTimerController {
    private(set) var remainingSeconds: Int = 0
    private(set) var isRunning = false
    private(set) var isPaused = false
    private(set) var activeExerciseID: UUID?
    private(set) var activeExerciseName: String?
    private(set) var didComplete = false

    private var endDate: Date?
    private var pausedRemaining: TimeInterval = 0
    private var tickTask: Task<Void, Never>?
    private var completionHandler: (() -> Void)?

    var isActive: Bool {
        isRunning || isPaused || remainingSeconds > 0
    }

    func start(
        duration: TimeInterval,
        exerciseID: UUID,
        exerciseName: String? = nil,
        onComplete: (() -> Void)? = nil
    ) {
        cancelTick()
        didComplete = false
        completionHandler = onComplete
        activeExerciseID = exerciseID
        activeExerciseName = exerciseName
        isPaused = false
        let seconds = max(1, Int(duration.rounded()))
        remainingSeconds = seconds
        endDate = Date().addingTimeInterval(TimeInterval(seconds))
        isRunning = true
        startTick()
    }

    func pause() {
        guard isRunning, !isPaused, let endDate else { return }
        pausedRemaining = max(0, endDate.timeIntervalSinceNow)
        remainingSeconds = max(0, Int(ceil(pausedRemaining)))
        isPaused = true
        isRunning = false
        self.endDate = nil
        cancelTick()
    }

    func resume() {
        guard isPaused else { return }
        let seconds = max(0, pausedRemaining)
        guard seconds > 0 else {
            finish()
            return
        }
        remainingSeconds = max(1, Int(ceil(seconds)))
        endDate = Date().addingTimeInterval(seconds)
        isPaused = false
        isRunning = true
        startTick()
    }

    func add(seconds: Int) {
        let extra = max(0, seconds)
        guard extra > 0 else { return }

        if isPaused {
            pausedRemaining += TimeInterval(extra)
            remainingSeconds = max(0, Int(ceil(pausedRemaining)))
            return
        }

        guard let endDate else {
            remainingSeconds += extra
            return
        }
        let newEnd = endDate.addingTimeInterval(TimeInterval(extra))
        self.endDate = newEnd
        remainingSeconds = max(0, Int(ceil(newEnd.timeIntervalSinceNow)))
        if !isRunning, remainingSeconds > 0 {
            isRunning = true
            startTick()
        }
    }

    func skip() {
        stop()
    }

    func stop() {
        cancelTick()
        endDate = nil
        pausedRemaining = 0
        remainingSeconds = 0
        isRunning = false
        isPaused = false
        activeExerciseID = nil
        activeExerciseName = nil
        didComplete = false
        completionHandler = nil
    }

    /// Recalculate from the end date when returning to foreground.
    func syncWithCurrentDate() {
        guard !isPaused else { return }
        guard let endDate else { return }
        let remaining = endDate.timeIntervalSinceNow
        if remaining <= 0 {
            finish()
        } else {
            remainingSeconds = max(0, Int(ceil(remaining)))
        }
    }

    // MARK: - Private

    private func startTick() {
        cancelTick()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, !Task.isCancelled else { return }
                self.syncWithCurrentDate()
                if !self.isRunning { return }
            }
        }
    }

    private func cancelTick() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func finish() {
        guard !didComplete else { return }
        cancelTick()
        didComplete = true
        remainingSeconds = 0
        isRunning = false
        isPaused = false
        endDate = nil
        pausedRemaining = 0
        let handler = completionHandler
        completionHandler = nil
        handler?()
    }
}
