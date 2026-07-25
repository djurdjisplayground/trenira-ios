import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Resolves exercise visuals only when a matching asset exists in the app bundle.
enum ExerciseVisuals {
    /// Cache asset lookups — `UIImage(named:)` is expensive and was being called
    /// hundreds of times while building the Add Exercise list.
    private static let cacheLock = NSLock()
    private static var existenceCache: [String: Bool] = [:]
    private static var urlCache: [String: URL?] = [:]

    static func resolvedImageAsset(for exercise: Exercise) -> String? {
        if let name = exercise.imageAssetName, assetExists(named: name) {
            return name
        }
        if let thumb = exercise.demonstration.thumbnailAsset, assetExists(named: thumb) {
            return thumb
        }
        return nil
    }

    static func resolvedAnimationAsset(for exercise: Exercise) -> String? {
        guard let name = exercise.animationAssetName else { return nil }
        return assetExists(named: name) ? name : nil
    }

    /// Local video for a demonstration — checked whenever an asset name is declared.
    /// Missing files return nil so the procedural fallback can play instead.
    static func resolvedDemonstrationURL(for demonstration: ExerciseDemonstration) -> URL? {
        guard let name = demonstration.demonstrationAsset else { return nil }
        return bundledMediaURL(named: name)
    }

    static func resolvedDemonstrationImageAsset(for demonstration: ExerciseDemonstration) -> String? {
        guard let name = demonstration.demonstrationAsset else { return nil }
        return assetExists(named: name) ? name : nil
    }

    static func resolvedThumbnailAsset(for demonstration: ExerciseDemonstration) -> String? {
        guard let name = demonstration.thumbnailAsset else { return nil }
        return assetExists(named: name) ? name : nil
    }

    private static func bundledMediaURL(named name: String) -> URL? {
        cacheLock.lock()
        if let cached = urlCache[name] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let extensions = ["mp4", "mov", "m4v"]
        var found: URL?
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Demonstrations") {
                found = url
                break
            }
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                found = url
                break
            }
        }

        cacheLock.lock()
        urlCache[name] = found
        cacheLock.unlock()
        return found
    }

    private static func assetExists(named name: String) -> Bool {
        cacheLock.lock()
        if let cached = existenceCache[name] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        #if canImport(UIKit)
        let exists = UIImage(named: name) != nil
        #else
        let exists = false
        #endif

        cacheLock.lock()
        existenceCache[name] = exists
        cacheLock.unlock()
        return exists
    }
}
