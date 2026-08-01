import AudioToolbox
import Foundation
import Observation
import UIKit

/// Countdown timer for one duration-based set (Farmer’s Carry, plank, holds, timed carries).
/// End-date based so remaining time stays accurate across navigation and brief backgrounding.
@Observable
@MainActor
final class DurationSetTimerController {
    struct Key: Hashable {
        let entryId: UUID
        let setIndex: Int
    }

    private(set) var remainingSeconds: Int = 0
    private(set) var targetSeconds: Int = 0
    private(set) var isRunning = false
    private(set) var isPaused = false
    private(set) var didComplete = false
    private(set) var activeKey: Key?

    private var endDate: Date?
    private var pausedRemaining: TimeInterval = 0
    private var tickTask: Task<Void, Never>?
    private var completionHandler: ((Key, Int) -> Void)?

    func isTracking(_ key: Key) -> Bool {
        activeKey == key
    }

    /// Elapsed seconds for the active countdown (target − remaining).
    var elapsedSeconds: Int {
        max(0, targetSeconds - remainingSeconds)
    }

    func displayedRemaining(for key: Key, fallbackTarget: Int) -> Int {
        if activeKey == key {
            return remainingSeconds
        }
        return max(0, fallbackTarget)
    }

    func start(target: Int, key: Key, onComplete: ((Key, Int) -> Void)? = nil) {
        if activeKey != key {
            hardReset()
        }
        cancelTick()
        didComplete = false
        completionHandler = onComplete
        activeKey = key
        targetSeconds = max(1, target)
        remainingSeconds = targetSeconds
        pausedRemaining = 0
        isPaused = false
        endDate = Date().addingTimeInterval(TimeInterval(targetSeconds))
        isRunning = true
        startTick()
    }

    /// Marks the timed effort finished early, reporting elapsed duration as actual.
    func finishEarly() {
        guard activeKey != nil, !didComplete else { return }
        let actual = max(0, elapsedSeconds)
        cancelTick()
        didComplete = true
        remainingSeconds = 0
        isRunning = false
        isPaused = false
        endDate = nil
        pausedRemaining = 0
        let key = activeKey
        let handler = completionHandler
        completionHandler = nil
        if let key {
            handler?(key, actual > 0 ? actual : targetSeconds)
        }
    }

    func pause() {
        guard isRunning, let endDate else { return }
        pausedRemaining = max(0, endDate.timeIntervalSinceNow)
        remainingSeconds = max(0, Int(ceil(pausedRemaining)))
        isPaused = true
        isRunning = false
        self.endDate = nil
        cancelTick()
    }

    func resume() {
        guard isPaused, let key = activeKey else { return }
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
        _ = key
    }

    func reset(to target: Int) {
        cancelTick()
        endDate = nil
        pausedRemaining = 0
        targetSeconds = max(1, target)
        remainingSeconds = targetSeconds
        isRunning = false
        isPaused = false
        didComplete = false
        // Keep activeKey so the same set can restart.
    }

    func clear() {
        hardReset()
    }

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

    private func hardReset() {
        cancelTick()
        endDate = nil
        pausedRemaining = 0
        remainingSeconds = 0
        targetSeconds = 0
        isRunning = false
        isPaused = false
        didComplete = false
        activeKey = nil
        completionHandler = nil
    }

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
        let key = activeKey
        let actual = targetSeconds
        let handler = completionHandler
        completionHandler = nil
        if let key {
            handler?(key, actual)
        }
    }
}

enum DurationTimerFeedback {
    static func playCompletion(soundEnabled: Bool, hapticsEnabled: Bool) {
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        if soundEnabled {
            AudioServicesPlaySystemSound(1057)
        }
    }
}
