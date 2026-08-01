import Foundation

#if DEBUG
/// DEBUG-only export of the live UserDefaults workout payload before risky migrations.
enum LocalPersistenceBackup {
    private static let keys = [
        "savedWorkouts",
        "weightHistory",
        "workoutWeeklyCompletions",
        "workoutPerformanceLogs",
        "customExercises",
        "exerciseProgressionStates",
        "progressionConfigurations",
        "globalExerciseProgress",
        "userSettings"
    ]

    @discardableResult
    static func exportToDocuments(label: String = "pre-migration") throws -> URL {
        var payload: [String: Data] = [:]
        for key in keys {
            if let data = UserDefaults.standard.data(forKey: key) {
                payload[key] = data
            }
        }

        let envelope: [String: Any] = [
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "label": label,
            "keysPresent": Array(payload.keys).sorted()
        ]

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = docs.appendingPathComponent("treniraDebugBackups", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let url = folder.appendingPathComponent("\(label)-\(stamp).json")

        // Store raw Data blobs as base64 so the backup is self-contained JSON.
        var encodedBlobs: [String: String] = [:]
        for (key, data) in payload {
            encodedBlobs[key] = data.base64EncodedString()
        }

        let body: [String: Any] = [
            "meta": envelope,
            "blobs": encodedBlobs
        ]
        let data = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])
        try ProtectedFileWriter.writeAtomically(data, to: url)
        return url
    }
}
#endif
