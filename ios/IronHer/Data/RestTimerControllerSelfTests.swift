import Foundation

#if DEBUG
/// Rest timer controller assertions. Run from Developer Settings.
@MainActor
enum RestTimerControllerSelfTests {
    struct Outcome: Sendable {
        var passed: Int
        var failed: Int
        var lines: [String]

        var summary: String {
            "Rest timer tests: \(passed) passed, \(failed) failed\n" + lines.joined(separator: "\n")
        }
    }

    static func runAll() async -> Outcome {
        var passed = 0
        var failed = 0
        var lines: [String] = []

        func check(_ name: String, _ condition: @autoclosure () -> Bool) {
            if condition() {
                passed += 1
                lines.append("✓ \(name)")
            } else {
                failed += 1
                lines.append("✗ \(name)")
            }
        }

        let timer = RestTimerController()
        let exerciseID = UUID()

        // 1. Starts with correct duration
        timer.start(duration: 90, exerciseID: exerciseID, exerciseName: "Hip Thrust")
        check("timer starts with correct duration", timer.remainingSeconds == 90)
        check("timer is running", timer.isRunning)

        // 2. Pause freezes remaining
        let beforePause = timer.remainingSeconds
        timer.pause()
        check("pause freezes running state", timer.isPaused && !timer.isRunning)
        check("pause keeps remaining", timer.remainingSeconds == beforePause)

        // 3. Resume continues
        timer.resume()
        check("resume continues", timer.isRunning && !timer.isPaused)

        // 4. +15 updates end time
        let beforeAdd = timer.remainingSeconds
        timer.add(seconds: 15)
        check("adding 15 seconds updates remaining", timer.remainingSeconds >= beforeAdd + 14)

        // 5. Skip resets
        timer.skip()
        check("skip resets timer", timer.remainingSeconds == 0 && !timer.isRunning && !timer.isPaused)

        // 6. New start cancels previous
        var firstCompleted = 0
        timer.start(duration: 60, exerciseID: exerciseID) {
            firstCompleted += 1
        }
        timer.start(duration: 30, exerciseID: UUID()) {
            // second completion
        }
        check("starting a new timer replaces duration", timer.remainingSeconds == 30)
        timer.skip()
        check("previous completion handler cleared on restart", firstCompleted == 0)

        // 7. Reaches zero once
        var completions = 0
        timer.start(duration: 1, exerciseID: exerciseID) {
            completions += 1
        }
        // Wait for tick loop to finish.
        try? await Task.sleep(for: .milliseconds(1400))
        timer.syncWithCurrentDate()
        check("timer reaches zero once", completions == 1 && timer.remainingSeconds == 0 && timer.didComplete)
        timer.syncWithCurrentDate()
        check("completion does not repeat", completions == 1)

        timer.stop()
        return Outcome(passed: passed, failed: failed, lines: lines)
    }
}
#endif
