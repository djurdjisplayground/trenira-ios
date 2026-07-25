import Foundation

/// Abstraction for authenticated workout backup / cross-device sync.
/// UI and stores depend on this protocol — not on a specific backend.
protocol RemoteUserDataStore: Sendable {
    var isConfigured: Bool { get }
    func fetchSnapshot(ownerId: String) async throws -> UserDataSnapshot?
    func uploadSnapshot(_ snapshot: UserDataSnapshot) async throws
}

/// Default until CloudKit / Firebase (or similar) is wired.
/// Keeps a device-local "remote mirror" for retry queues and same-device restore after sign-out.
/// Does **not** provide cross-device restore until a real backend is configured.
final class LocalMirrorRemoteUserDataStore: RemoteUserDataStore, @unchecked Sendable {
    private let folderName = "RemoteUserDataMirror"
    private let lock = NSLock()
    private var pendingUploads: [String: UserDataSnapshot] = [:]

    var isConfigured: Bool { true }

    func fetchSnapshot(ownerId: String) async throws -> UserDataSnapshot? {
        lock.lock()
        let pending = pendingUploads[ownerId]
        lock.unlock()
        if let pending { return pending }
        return try loadFromDisk(ownerId: ownerId)
    }

    func uploadSnapshot(_ snapshot: UserDataSnapshot) async throws {
        lock.lock()
        pendingUploads[snapshot.ownerId] = snapshot
        lock.unlock()
        try persistToDisk(snapshot)
        lock.lock()
        pendingUploads[snapshot.ownerId] = nil
        lock.unlock()
    }

    private func loadFromDisk(ownerId: String) throws -> UserDataSnapshot? {
        let url = try fileURL(for: ownerId)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(UserDataSnapshot.self, from: data)
    }

    private func persistToDisk(_ snapshot: UserDataSnapshot) throws {
        let url = try fileURL(for: snapshot.ownerId)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: [.atomic])
    }

    private func fileURL(for ownerId: String) throws -> URL {
        let safe = ownerId
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return root
            .appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent("\(safe).json", isDirectory: false)
    }
}

/// Placeholder that refuses to overwrite local data; used when documenting unconfigured cloud backends.
struct UnconfiguredRemoteUserDataStore: RemoteUserDataStore {
    var isConfigured: Bool { false }

    func fetchSnapshot(ownerId: String) async throws -> UserDataSnapshot? {
        nil
    }

    func uploadSnapshot(_ snapshot: UserDataSnapshot) async throws {
        throw RemoteUserDataError.notConfigured
    }
}

enum RemoteUserDataError: LocalizedError {
    case notConfigured
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Cloud backup is not configured yet."
        case .uploadFailed(let message):
            message
        }
    }
}
