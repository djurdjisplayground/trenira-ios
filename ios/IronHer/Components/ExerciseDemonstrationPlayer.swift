import AVFoundation
import SwiftUI
import UIKit

/// Exercise demonstration stage for Exercise Details / Library.
///
/// Plays a silent looping **bundled licensed** clip when one exists for the
/// stable exercise ID. Otherwise renders nothing — no AI animation,
/// placeholder, or substitute movement.
struct ExerciseDemonstrationView: View {
    let exercise: Exercise

    var body: some View {
        if exercise.demonstration.demonstrationAvailable {
            BundledExerciseDemonstrationPlayer(demonstration: exercise.demonstration)
        }
    }
}

/// Silent looping player for approved bundled real-human clips.
/// Auto-plays on appear; tap to pause / resume. No chrome, no audio.
struct BundledExerciseDemonstrationPlayer: View {
    let demonstration: ExerciseDemonstration

    @State private var player: AVPlayer?
    @State private var isPlaying = true
    @State private var endObserver: NSObjectProtocol?
    @State private var showPauseHint = false

    private var videoURL: URL? {
        ExerciseVisuals.resolvedDemonstrationURL(for: demonstration)
    }

    var body: some View {
        ZStack {
            IronHerTheme.cardBackground

            if let player {
                SilentLoopingVideoView(player: player)
            } else {
                ProgressView()
                    .tint(IronHerTheme.secondaryText)
            }

            Image(systemName: isPlaying ? "pause.circle" : "play.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(IronHerTheme.primaryText.opacity(showPauseHint || !isPlaying ? 0.75 : 0))
                .animation(.easeOut(duration: 0.2), value: showPauseHint || !isPlaying)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous)
                .stroke(IronHerTheme.separator.opacity(0.45), lineWidth: 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
        .onTapGesture(perform: togglePlayback)
        .accessibilityLabel(isPlaying ? "Pause demonstration" : "Play demonstration")
        .accessibilityAddTraits(.isButton)
        .onAppear(perform: attachPlayerIfNeeded)
        .onDisappear(perform: tearDown)
    }

    private func attachPlayerIfNeeded() {
        guard player == nil, let url = videoURL else { return }

        // Reuse a warm player when the same asset was viewed recently.
        if let cached = ExerciseDemonstrationPlaybackCache.shared.player(for: url) {
            player = cached
            cached.isMuted = true
            cached.seek(to: .zero)
            cached.play()
            isPlaying = true
            observeLoop(for: cached.currentItem)
            return
        }

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.isMuted = true
        newPlayer.actionAtItemEnd = .none
        observeLoop(for: item)

        ExerciseDemonstrationPlaybackCache.shared.store(newPlayer, for: url)
        player = newPlayer
        newPlayer.play()
        isPlaying = true
    }

    private func observeLoop(for item: AVPlayerItem?) {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        guard let item else { return }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }
    }

    private func togglePlayback() {
        guard let player else {
            attachPlayerIfNeeded()
            return
        }
        if isPlaying {
            player.pause()
            isPlaying = false
            showPauseHint = true
        } else {
            player.play()
            isPlaying = true
            showPauseHint = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                showPauseHint = false
            }
        }
    }

    private func tearDown() {
        player?.pause()
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        // Keep the AVPlayer in cache for revisit; drop the local reference.
        player = nil
    }
}

typealias ExerciseDemonstrationPlayer = BundledExerciseDemonstrationPlayer

/// Small in-memory cache so reopening Details does not rebuffer the same clip.
private final class ExerciseDemonstrationPlaybackCache {
    static let shared = ExerciseDemonstrationPlaybackCache()

    private let lock = NSLock()
    private var players: [URL: AVPlayer] = [:]
    private var order: [URL] = []
    private let capacity = 8

    func player(for url: URL) -> AVPlayer? {
        lock.lock()
        defer { lock.unlock() }
        guard let player = players[url] else { return nil }
        touch(url)
        return player
    }

    func store(_ player: AVPlayer, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        players[url] = player
        touch(url)
        while order.count > capacity {
            let evicted = order.removeFirst()
            players.removeValue(forKey: evicted)
        }
    }

    private func touch(_ url: URL) {
        order.removeAll { $0 == url }
        order.append(url)
    }
}

private struct SilentLoopingVideoView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class PlayerContainerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
