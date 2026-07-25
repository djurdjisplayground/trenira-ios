import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Resolves exercise visuals only when a matching asset exists in the app bundle.
enum ExerciseVisuals {
    static func resolvedImageAsset(for exercise: Exercise) -> String? {
        guard let name = exercise.imageAssetName else { return nil }
        return assetExists(named: name) ? name : nil
    }

    static func resolvedAnimationAsset(for exercise: Exercise) -> String? {
        guard let name = exercise.animationAssetName else { return nil }
        return assetExists(named: name) ? name : nil
    }

    private static func assetExists(named name: String) -> Bool {
        #if canImport(UIKit)
        return UIImage(named: name) != nil
        #else
        return false
        #endif
    }
}
