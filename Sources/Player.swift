import Foundation
import Combine
import AVFoundation
import MediaPlayer
import UIKit

enum NowPlayingMode {
    case volume
    case scrub
    case favourite
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

    private var audio: AVAudioPlayer?
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
        guard let track = current else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: track.url)
            player.delegate = self
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

    // MARK: - Now Playing mode

    func cycleMode() {
        switch mode {
        case .volume: mode = .scrub
        case .scrub: mode = .favourite
        case .favourite: mode = .volume
        }
        volumeVisible = false
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audio else { return }
            self.currentTime = player.currentTime
        }
    }
    private func stopTimer() { timer?.invalidate(); timer = nil }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        next()
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
