import Foundation

/// Deterministic movement suggestions. No network and no generated exercise lists.
enum MovementRecommendationEngine {
    static func suggest(
        profile: CompanionProfile,
        checkIn: MovementCheckIn,
        workouts: [SavedStrengthOption],
        savedVideos: [SavedVideoOption] = []
    ) -> [MovementSuggestion] {
        let strength = strengthOption(workouts.first, minutes: checkIn.minutes, setting: checkIn.setting)
        let walkOK = checkIn.setting != .gym
        let barrier = profile.primaryBarrier

        var chosen: [MovementSuggestion]
        switch barrier {
        case .notEnoughTime:
            chosen = shortOnly(walkOK: walkOK, minutes: checkIn.minutes)
        case .difficultyStarting:
            chosen = [oneSmallStep(walkOK: walkOK, strength: strength, minutes: checkIn.minutes)]
        case .unpredictableSchedule:
            chosen = flexibleOptions(walkOK: walkOK, strength: strength, minutes: checkIn.minutes)
        case .cantGetToGym:
            chosen = withoutGym(
                setting: checkIn.setting,
                walkOK: walkOK,
                strength: strength,
                minutes: checkIn.minutes,
                prefersStrength: profile.formats.contains(.strength)
            )
        case .guilt:
            chosen = [supportive(walkOK: walkOK, strength: strength, minutes: checkIn.minutes)]
        case .returningAfterBreak:
            chosen = [returning(walkOK: walkOK, strength: strength, minutes: checkIn.minutes, energy: checkIn.energy)]
        case .lowEnergy:
            chosen = [lowEnergyStep(walkOK: walkOK, strength: strength, minutes: checkIn.minutes)]
        case nil:
            chosen = preferred(
                profile: profile,
                walkOK: walkOK,
                strength: strength,
                minutes: checkIn.minutes,
                energy: checkIn.energy
            )
        }

        if chosen.isEmpty {
            chosen = [nothingReady(minutes: checkIn.minutes, setting: checkIn.setting)]
        }

        if barrier != .difficultyStarting, profile.formats.contains(.videos) {
            chosen.append(videoSuggestion(videos: savedVideos, minutes: checkIn.minutes))
        } else if chosen.allSatisfy({ !$0.isActionable && $0.kind != .walk }), profile.formats.contains(.videos) {
            chosen.append(videoSuggestion(videos: savedVideos, minutes: checkIn.minutes))
        }

        chosen.append(contentsOf: selfDirected(profile: profile, minutes: checkIn.minutes))
        return chosen
    }

    /// A full saved workout is offered only when the setting can use it and the visit is long enough
    /// that we are not pretending the workout itself lasts 2 or 5 minutes.
    private static func strengthOption(
        _ workout: SavedStrengthOption?,
        minutes: MovementMinutes,
        setting: MovementSetting
    ) -> SavedStrengthOption? {
        guard let workout else { return nil }
        guard minutes.rawValue >= 10 else { return nil }
        guard setting != .outdoors else { return nil }
        return workout
    }

    private static func shortOnly(
        walkOK: Bool,
        minutes: MovementMinutes
    ) -> [MovementSuggestion] {
        if walkOK {
            return [walk(
                minutes: minutes,
                reason: minutes.rawValue <= 10
                    ? "A short walk might fit the time you have."
                    : "A walk might fit the \(minutes.rawValue) minutes you have."
            )]
        }
        return [nothingReady(
            minutes: minutes,
            setting: .gym,
            detail: "A saved workout is not suggested here, because trenira can't promise it will fit in \(minutes.rawValue) minutes."
        )]
    }

    private static func oneSmallStep(
        walkOK: Bool,
        strength: SavedStrengthOption?,
        minutes: MovementMinutes
    ) -> MovementSuggestion {
        if walkOK {
            return walk(
                minutes: minutes,
                reason: "Getting started can be the hard part. One small step is enough."
            )
        }
        if let strength {
            return savedWorkout(
                strength,
                minutes: minutes,
                reason: "Getting started can be the hard part. Open this one workout and stop whenever you want."
            )
        }
        return nothingReady(minutes: minutes, setting: .gym)
    }

    private static func flexibleOptions(
        walkOK: Bool,
        strength: SavedStrengthOption?,
        minutes: MovementMinutes
    ) -> [MovementSuggestion] {
        var options: [MovementSuggestion] = []
        if walkOK {
            options.append(walk(
                minutes: minutes,
                reason: "Your day can change. Either option counts, and you can switch."
            ))
        }
        if let strength {
            options.append(savedWorkout(
                strength,
                minutes: minutes,
                reason: "Your day can change. This saved workout is an alternative, not an obligation."
            ))
        }
        return options
    }

    private static func withoutGym(
        setting: MovementSetting,
        walkOK: Bool,
        strength: SavedStrengthOption?,
        minutes: MovementMinutes,
        prefersStrength: Bool
    ) -> [MovementSuggestion] {
        if setting == .gym, let strength {
            return [savedWorkout(
                strength,
                minutes: minutes,
                reason: "You are already at the gym, so your saved workout is available."
            )]
        }
        var options: [MovementSuggestion] = []
        if walkOK {
            options.append(walk(
                minutes: minutes,
                reason: "Getting to a gym is the barrier, so this stays at \(setting.title.lowercased())."
            ))
        }
        if setting == .home, prefersStrength, let strength {
            options.append(savedWorkout(
                strength,
                minutes: minutes,
                reason: "Your saved workout can stay at home. Stop whenever you need to."
            ))
        }
        return options
    }

    private static func supportive(
        walkOK: Bool,
        strength: SavedStrengthOption?,
        minutes: MovementMinutes
    ) -> MovementSuggestion {
        let reason = "This time is yours. A little movement is still movement."
        if walkOK {
            return walk(minutes: minutes, reason: reason)
        }
        if let strength {
            return savedWorkout(strength, minutes: minutes, reason: reason)
        }
        return nothingReady(minutes: minutes, setting: .gym, detail: reason)
    }

    private static func returning(
        walkOK: Bool,
        strength: SavedStrengthOption?,
        minutes: MovementMinutes,
        energy: MovementEnergy
    ) -> MovementSuggestion {
        let reason = "Welcome back. There's nothing to catch up on."
        if walkOK {
            return walk(minutes: minutes, reason: reason)
        }
        if let strength, minutes == .twenty, energy == .high {
            return savedWorkout(strength, minutes: minutes, reason: reason)
        }
        return nothingReady(
            minutes: minutes,
            setting: .gym,
            detail: "\(reason) A full saved workout is not the suggestion for this visit."
        )
    }

    private static func lowEnergyStep(
        walkOK: Bool,
        strength: SavedStrengthOption?,
        minutes: MovementMinutes
    ) -> MovementSuggestion {
        let reason = "Low energy still leaves room for a little movement."
        if walkOK {
            return walk(minutes: minutes, reason: reason)
        }
        if let strength {
            return savedWorkout(strength, minutes: minutes, reason: reason)
        }
        return nothingReady(minutes: minutes, setting: .gym, detail: reason)
    }

    private static func preferred(
        profile: CompanionProfile,
        walkOK: Bool,
        strength: SavedStrengthOption?,
        minutes: MovementMinutes,
        energy: MovementEnergy
    ) -> [MovementSuggestion] {
        let wantsStrength = profile.goal == .feelStronger || profile.formats.contains(.strength)
        let lowEnergy = energy == .low
        var options: [MovementSuggestion] = []

        if wantsStrength, !lowEnergy, let strength {
            options.append(savedWorkout(
                strength,
                minutes: minutes,
                reason: profile.goal == .feelStronger
                    ? "Building strength is your aim, and you have a saved workout you can start."
                    : "Strength training is one of the ways you like to move, and this workout can be started."
            ))
        }
        if walkOK {
            let reason: String
            if profile.formats == [.yoga] {
                reason = "You can record yoga yourself. A walk is here if you want to move without one."
            } else if profile.formats.contains(.notSure) || profile.formats.isEmpty {
                reason = "You don't have to decide on a style today. A walk might fit the time you have."
            } else if minutes.rawValue <= 10 {
                reason = "A short walk might fit the time you have."
            } else {
                reason = "A walk might fit the time and place you chose."
            }
            options.append(walk(minutes: minutes, reason: reason))
        }
        if wantsStrength, lowEnergy, let strength {
            options.append(savedWorkout(
                strength,
                minutes: minutes,
                reason: "Your energy is low, so the walk comes first. The saved workout is there only if you want it."
            ))
        }
        return options
    }

    private static func walk(minutes: MovementMinutes, reason: String) -> MovementSuggestion {
        MovementSuggestion(
            id: "walk",
            kind: .walk,
            title: "A \(minutes.rawValue)-minute walk",
            detail: "About \(minutes.rawValue) minutes, then stop whenever you need to.",
            reason: reason,
            isActionable: true,
            workoutId: nil
        )
    }

    private static func savedWorkout(
        _ workout: SavedStrengthOption,
        minutes: MovementMinutes,
        reason: String
    ) -> MovementSuggestion {
        MovementSuggestion(
            id: "strength-\(workout.id.uuidString)",
            kind: .strengthWorkout,
            title: workout.name,
            detail: "This is your saved workout. trenira can't promise it lasts \(minutes.rawValue) minutes, so stop whenever you need to.",
            reason: reason,
            isActionable: true,
            workoutId: workout.id
        )
    }

    private static func videoSuggestion(videos: [SavedVideoOption], minutes: MovementMinutes) -> MovementSuggestion {
        let fitting = videos.filter { video in
            guard let duration = video.durationMinutes else { return true }
            return duration <= minutes.rawValue
        }
        if let known = fitting.first(where: { $0.durationMinutes != nil }) {
            return MovementSuggestion(
                id: "video-\(known.id.uuidString)",
                kind: .video,
                title: known.title,
                detail: "You saved this as \(known.durationMinutes ?? 0) minutes. It opens outside trenira, and opening it does not mark it done.",
                reason: "This saved video is within the \(minutes.rawValue) minutes you chose.",
                isActionable: true,
                workoutId: nil,
                videoId: known.id
            )
        }
        if let unknown = fitting.first {
            return MovementSuggestion(
                id: "video-\(unknown.id.uuidString)",
                kind: .video,
                title: unknown.title,
                detail: "Its length isn't saved, so trenira won't claim it fits in \(minutes.rawValue) minutes. It opens outside trenira.",
                reason: "You saved this video.",
                isActionable: true,
                workoutId: nil,
                videoId: unknown.id
            )
        }
        if videos.isEmpty {
            return MovementSuggestion(
                id: "video",
                kind: .video,
                title: "Workout video",
                detail: "No video is saved yet, so trenira won't open one or guess how long it is.",
                reason: "Videos are one of the ways you like to move.",
                isActionable: false,
                workoutId: nil
            )
        }
        return MovementSuggestion(
            id: "video",
            kind: .video,
            title: "Workout video",
            detail: "Your saved videos are longer than the \(minutes.rawValue) minutes you have, so none is suggested for this visit.",
            reason: "The time you chose is the limit.",
            isActionable: false,
            workoutId: nil
        )
    }

    /// Preferred categories that are recorded by the person. These do not replace the first suggestion.
    private static func selfDirected(profile: CompanionProfile, minutes: MovementMinutes) -> [MovementSuggestion] {
        let formats = profile.formats.filter { format in
            switch format {
            case .yoga, .dancing, .withBaby, .other: true
            case .strength, .walking, .videos, .notSure: false
            }
        }
        var seen: [MovementFormat] = []
        return formats.compactMap { format in
            guard !seen.contains(format) else { return nil }
            seen.append(format)
            let shorter = minutes.rawValue > 2 ? max(2, minutes.rawValue / 2) : 2
            let detail: String
            if format == .withBaby {
                detail = "About \(minutes.rawValue) minutes, or \(shorter). Move with your baby nearby. trenira does not suggest lifting, carrying, or using your baby as part of the exercise."
            } else {
                detail = "\(format.summary) About \(minutes.rawValue) minutes, or \(shorter) if that fits better."
            }
            return MovementSuggestion(
                id: "self-\(format.rawValue)",
                kind: .selfDirected,
                title: format.title,
                detail: detail,
                reason: "This is one of the ways you like to move. Only what you record is saved.",
                isActionable: true,
                format: format
            )
        }
    }

    private static func nothingReady(
        minutes: MovementMinutes,
        setting: MovementSetting,
        detail: String? = nil
    ) -> MovementSuggestion {
        MovementSuggestion(
            id: "none",
            kind: .unavailable,
            title: "Nothing ready to start",
            detail: detail ?? "No saved workout fits \(setting.title.lowercased()) in \(minutes.rawValue) minutes. You can add one in Your strength workouts, or choose another place.",
            reason: "trenira only suggests something it can actually offer.",
            isActionable: false,
            workoutId: nil
        )
    }
}
