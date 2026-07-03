import Foundation
import Combine
import AVFoundation
import MediaPlayer
import UIKit

final class Player: NSObject, ObservableObject, AVAudioPlayerDelegate {

    // Library
    @Published var tracks: [Track] = []

    // Playback state
    @Published var currentIndex: Int? = nil
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var shuffle: Bool = false

    // Now-playing display (updated from file metadata)
    @Published var nowPlayingTitle: String = ""
    @Published var nowPlayingArtist: String = ""
    @Published var nowPlayingArtwork: UIImage? = nil

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    private let audioExtensions: Set<String> = [
        "mp3", "m4a", "aac", "alac", "wav", "aif", "aiff", "caf", "m4b", "flac"
    ]

    var currentTrack: Track? {
        guard let i = currentIndex, tracks.indices.contains(i) else { return nil }
        return tracks[i]
    }

    override init() {
        super.init()
        configureAudioSession()
        setupRemoteCommands()
        loadLibrary()
    }

    // MARK: - Audio session

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    // MARK: - Library scan

    func loadLibrary() {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        var found: [Track] = []
        if let enumerator = fm.enumerator(at: docs, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator {
                if audioExtensions.contains(url.pathExtension.lowercased()) {
                    found.append(Track(url: url))
                }
            }
        }
        found.sort {
            $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
        }
        DispatchQueue.main.async {
            self.tracks = found
        }
    }

    // MARK: - Playback

    func play(at index: Int) {
        guard tracks.indices.contains(index) else { return }
        currentIndex = index
        let track = tracks[index]
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: track.url)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()
            audioPlayer = newPlayer
            duration = newPlayer.duration
            currentTime = 0
            newPlayer.play()
            isPlaying = true
            startTimer()
            loadMetadata(for: track)
            updateNowPlayingInfo()
        } catch {
            print("Could not play \(track.url.lastPathComponent): \(error)")
        }
    }

    func togglePlayPause() {
        guard let player = audioPlayer else {
            if let i = currentIndex {
                play(at: i)
            } else if !tracks.isEmpty {
                play(at: 0)
            }
            return
        }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopTimer()
        } else {
            player.play()
            isPlaying = true
            startTimer()
        }
        updateNowPlayingInfo()
    }

    func next() {
        guard !tracks.isEmpty else { return }
        let n: Int
        if shuffle {
            n = Int.random(in: 0..<tracks.count)
        } else if let i = currentIndex {
            n = (i + 1) % tracks.count
        } else {
            n = 0
        }
        play(at: n)
    }

    func previous() {
        guard !tracks.isEmpty else { return }
        // If more than 3 seconds in, restart the current track instead.
        if currentTime > 3, let i = currentIndex {
            play(at: i)
            return
        }
        let p: Int
        if let i = currentIndex {
            p = (i - 1 + tracks.count) % tracks.count
        } else {
            p = 0
        }
        play(at: p)
    }

    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        let clamped = min(max(0, time), player.duration)
        player.currentTime = clamped
        currentTime = clamped
        updateNowPlayingInfo()
    }

    func scrub(by delta: TimeInterval) {
        guard let player = audioPlayer else { return }
        seek(to: player.currentTime + delta)
    }

    // MARK: - Timer for progress updates

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        next()
    }

    // MARK: - Metadata

    private func loadMetadata(for track: Track) {
        // Immediate fallback so the screen is never blank.
        nowPlayingTitle = track.displayTitle
        nowPlayingArtist = ""
        nowPlayingArtwork = nil

        let url = track.url
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVURLAsset(url: url)
            var title: String?
            var artist: String?
            var artwork: UIImage?

            for item in asset.commonMetadata {
                guard let key = item.commonKey else { continue }
                switch key {
                case .commonKeyTitle:
                    title = item.stringValue
                case .commonKeyArtist:
                    artist = item.stringValue
                case .commonKeyArtwork:
                    if let data = item.dataValue, let image = UIImage(data: data) {
                        artwork = image
                    }
                default:
                    break
                }
            }

            DispatchQueue.main.async {
                // Only apply if this is still the track that's playing.
                guard self.currentTrack?.url == url else { return }
                if let title = title, !title.isEmpty {
                    self.nowPlayingTitle = title
                }
                if let artist = artist, !artist.isEmpty {
                    self.nowPlayingArtist = artist
                }
                self.nowPlayingArtwork = artwork
                self.updateNowPlayingInfo()
            }
        }
    }

    // MARK: - Lock screen / Control Center

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pausePlayback()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: event.positionTime)
            }
            return .success
        }
    }

    private func resume() {
        guard let player = audioPlayer else { return }
        player.play()
        isPlaying = true
        startTimer()
        updateNowPlayingInfo()
    }

    private func pausePlayback() {
        guard let player = audioPlayer else { return }
        player.pause()
        isPlaying = false
        stopTimer()
        updateNowPlayingInfo()
    }

    private func updateNowPlayingInfo() {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = nowPlayingTitle
        info[MPMediaItemPropertyArtist] = nowPlayingArtist
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        if let artwork = nowPlayingArtwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in
                artwork
            }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
