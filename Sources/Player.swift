import Foundation
import Combine
import AVFoundation
import MediaPlayer
import UIKit

enum NowPlayingMode {
    case volume
    case options
    case scrub
    case favourite
}

enum RepeatMode {
    case off
    case all
    case one
}

final class Player: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var queue: [Track] = []
    @Published var index: Int = 0
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var shuffle: Bool = false
    @Published var artwork: UIImage? = nil

    @Published var mode: NowPlayingMode = .volume
    @Published var volume: Float = 0.5
    @Published var volumeVisible: Bool = false

    @Published var repeatMode: RepeatMode = .off
    @Published var crossfade: Int = 0            // 0, 2 or 4 seconds
    @Published var brightnessActive: Bool = false
    @Published var npTextMode: Int = 0           // 0 title, 1 album, 2 artist

    private var audio: AVAudioPlayer?
    private var nextAudio: AVAudioPlayer?
    private var crossfading = false
    private var crossfadeWork: DispatchWorkItem?
    private var timer: Timer?
    private var volumeHideWork: DispatchWorkItem?

    var current: Track? { queue.indices.contains(index) ? queue[index] : nil }

    override init() {
        super.init()
        configureSession()
        setupRemoteCommands()
        volume = SystemVolume.shared.current
    }

    private func configureSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    // MARK: - Queue control

    func playQueue(_ tracks: [Track], startAt: Int) {
        guard !tracks.isEmpty, tracks.indices.contains(startAt) else { return }
        shuffle = false
        queue = tracks
        index = startAt
        mode = .volume
        volumeVisible = false
        startCurrent()
    }

    func shufflePlay(_ tracks: [Track]) {
        guard !tracks.isEmpty else { return }
        queue = tracks.shuffled()
        index = 0
        shuffle = true
        mode = .volume
        volumeVisible = false
        startCurrent()
    }

    private func startCurrent() {
        cancelCrossfade()
        npTextMode = 0
        guard let track = current else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: track.url)
            player.delegate = self
            player.volume = 1
            player.prepareToPlay()
            audio = player
            duration = player.duration
            currentTime = 0
            player.play()
            isPlaying = true
            startTimer()
            loadArtwork(track)
            updateNowPlayingInfo()
        } catch {
            print("Could not play \(track.url.lastPathComponent): \(error)")
            next()
        }
    }

    func togglePlayPause() {
        guard let player = audio else {
            if current != nil { startCurrent() }
            return
        }
        if player.isPlaying {
            player.pause(); isPlaying = false; stopTimer()
        } else {
            player.play(); isPlaying = true; startTimer()
        }
        updateNowPlayingInfo()
    }

    func next() {
        guard !queue.isEmpty else { return }
        index = shuffle ? Int.random(in: 0..<queue.count) : (index + 1) % queue.count
        startCurrent()
    }

    func previous() {
        guard !queue.isEmpty else { return }
        if currentTime > 3 { startCurrent(); return }
        index = (index - 1 + queue.count) % queue.count
        startCurrent()
    }

    func seek(to time: TimeInterval) {
        guard let player = audio else { return }
        let clamped = min(max(0, time), player.duration)
        player.currentTime = clamped
        currentTime = clamped
        updateNowPlayingInfo()
    }

    func scrub(by delta: TimeInterval) {
        guard let player = audio else { return }
        seek(to: player.currentTime + delta)
    }

    // MARK: - Volume

    func nudgeVolume(_ delta: Float) {
        volume = min(1, max(0, volume + delta))
        SystemVolume.shared.set(volume)
        volumeVisible = true
        volumeHideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.volumeVisible = false }
        volumeHideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    // MARK: - Now Playing modes

    func cycleMode() {
        switch mode {
        case .volume: mode = .options
        case .options: mode = .scrub
        case .scrub: mode = .favourite
        case .favourite: mode = .volume
        }
        volumeVisible = false
        brightnessActive = false
    }

    func cycleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    func toggleShuffle() { shuffle.toggle() }

    func cycleCrossfade() {
        crossfade = crossfade == 0 ? 2 : (crossfade == 2 ? 4 : 0)
    }

    func toggleBrightness() { brightnessActive.toggle() }

    // MARK: - Timer / crossfade

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audio else { return }
            self.currentTime = player.currentTime
            self.checkCrossfade()
        }
    }
    private func stopTimer() { timer?.invalidate(); timer = nil }

    private func checkCrossfade() {
        guard crossfade > 0, !crossfading, repeatMode != .one, let a = audio else { return }
        let remaining = a.duration - a.currentTime
        if remaining <= Double(crossfade) && remaining > 0.15 {
            startCrossfade()
        }
    }

    private func startCrossfade() {
        guard !queue.isEmpty else { return }
        if repeatMode == .off && !shuffle && index + 1 >= queue.count { return }
        let nextIdx = shuffle ? Int.random(in: 0..<queue.count) : (index + 1) % queue.count
        guard queue.indices.contains(nextIdx) else { return }
        guard let np = try? AVAudioPlayer(contentsOf: queue[nextIdx].url) else { return }
        np.delegate = self
        np.volume = 0
        np.prepareToPlay()
        np.play()
        np.setVolume(1, fadeDuration: Double(crossfade))
        audio?.setVolume(0, fadeDuration: Double(crossfade))
        nextAudio = np
        crossfading = true
        let work = DispatchWorkItem { [weak self] in self?.completeCrossfade(nextIndex: nextIdx) }
        crossfadeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(crossfade), execute: work)
    }

    private func completeCrossfade(nextIndex: Int) {
        guard crossfading, let np = nextAudio, queue.indices.contains(nextIndex) else { return }
        audio?.stop()
        audio = np
        nextAudio = nil
        crossfading = false
        index = nextIndex
        np.volume = 1
        duration = np.duration
        currentTime = np.currentTime
        isPlaying = true
        loadArtwork(queue[nextIndex])
        updateNowPlayingInfo()
    }

    private func cancelCrossfade() {
        crossfadeWork?.cancel()
        crossfadeWork = nil
        nextAudio?.stop()
        nextAudio = nil
        crossfading = false
        audio?.volume = 1
    }

    private func advanceAtEnd() {
        guard !queue.isEmpty else { return }
        if shuffle {
            index = Int.random(in: 0..<queue.count); startCurrent(); return
        }
        if index + 1 < queue.count {
            index += 1; startCurrent()
        } else if repeatMode == .all {
            index = 0; startCurrent()
        } else {
            isPlaying = false; stopTimer(); updateNowPlayingInfo()
        }
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if crossfading { return }
        guard player == audio else { return }
        if repeatMode == .one { startCurrent(); return }
        advanceAtEnd()
    }

    // MARK: - Artwork

    private func loadArtwork(_ track: Track) {
        artwork = nil
        let url = track.url
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVURLAsset(url: url)
            var image: UIImage? = nil
            for item in asset.commonMetadata where item.commonKey == .commonKeyArtwork {
                if let data = item.dataValue, let img = UIImage(data: data) { image = img }
            }
            DispatchQueue.main.async {
                if self.current?.url == url {
                    self.artwork = image
                    self.updateNowPlayingInfo()
                }
            }
        }
    }

    // MARK: - Lock screen

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in self?.resume(); return .success }
        center.pauseCommand.addTarget { [weak self] _ in self?.pausePlayback(); return .success }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }
        center.nextTrackCommand.addTarget { [weak self] _ in self?.next(); return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in self?.previous(); return .success }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent { self?.seek(to: event.positionTime) }
            return .success
        }
    }

    private func resume() {
        guard let player = audio else { return }
        player.play(); isPlaying = true; startTimer(); updateNowPlayingInfo()
    }
    private func pausePlayback() {
        guard let player = audio else { return }
        player.pause(); isPlaying = false; stopTimer(); updateNowPlayingInfo()
    }

    private func updateNowPlayingInfo() {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = current?.title ?? ""
        info[MPMediaItemPropertyArtist] = current?.artist ?? ""
        info[MPMediaItemPropertyAlbumTitle] = current?.album ?? ""
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        if let art = artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: art.size) { _ in art }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
