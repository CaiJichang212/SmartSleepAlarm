import Foundation
import WatchKit
import AVFoundation
import Combine

enum AlarmSoundType {
    case system
    case custom
}

enum AlarmPlaybackState {
    case idle
    case playing
    case paused
    case fadingIn
    case snoozed
    
    var displayName: String {
        switch self {
        case .idle: return "空闲"
        case .playing: return "播放中"
        case .paused: return "已暂停"
        case .fadingIn: return "渐强中"
        case .snoozed: return "贪睡中"
        }
    }
}

struct AlarmPlaybackConfig {
    var soundId: String
    var volume: Float
    var vibrationEnabled: Bool
    var fadeInEnabled: Bool
    var fadeInDuration: TimeInterval
    var repeatCount: Int
    var repeatInterval: TimeInterval
    
    static let `default` = AlarmPlaybackConfig(
        soundId: "default",
        volume: 0.8,
        vibrationEnabled: true,
        fadeInEnabled: true,
        fadeInDuration: 30.0,
        repeatCount: 3,
        repeatInterval: 5.0
    )
}

class AlarmPlayer: NSObject, ObservableObject {
    static let shared = AlarmPlayer()
    
    @Published var playbackState: AlarmPlaybackState = .idle
    @Published var currentVolume: Float = 0.0
    @Published var isVibrating: Bool = false
    @Published var currentSoundId: String?
    
    private var audioPlayer: AVAudioPlayer?
    private var fadeInTimer: Timer?
    private var vibrationTimer: Timer?
    private var repeatTimer: Timer?
    private var currentConfig: AlarmPlaybackConfig?
    private var currentRepeatCount: Int = 0
    
    private let device = WKInterfaceDevice.current()
    private var cancellables = Set<AnyCancellable>()
    
    var onPlaybackStarted: (() -> Void)?
    var onPlaybackStopped: (() -> Void)?
    var onFadeInComplete: (() -> Void)?
    var onRepeatCycle: ((Int) -> Void)?
    
    private override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func playAlarm(config: AlarmPlaybackConfig = .default) {
        stopAlarm()
        
        currentConfig = config
        currentSoundId = config.soundId
        currentRepeatCount = 0
        
        if config.fadeInEnabled {
            startFadeInPlayback(config: config)
        } else {
            startImmediatePlayback(config: config)
        }
        
        if config.vibrationEnabled {
            startVibration()
        }
        
        onPlaybackStarted?()
    }
    
    private func startImmediatePlayback(config: AlarmPlaybackConfig) {
        currentVolume = config.volume
        playbackState = .playing
        
        playSound(soundId: config.soundId, volume: config.volume)
        
        scheduleRepetition(config: config)
    }
    
    private func startFadeInPlayback(config: AlarmPlaybackConfig) {
        playbackState = .fadingIn
        currentVolume = 0.0
        
        playSound(soundId: config.soundId, volume: 0.0)
        
        let fadeSteps = Int(config.fadeInDuration / 0.5)
        let volumeStep = config.volume / Float(fadeSteps)
        var currentStep = 0
        
        fadeInTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentStep += 1
            self.currentVolume = min(config.volume, volumeStep * Float(currentStep))
            self.audioPlayer?.volume = self.currentVolume
            
            if currentStep >= fadeSteps {
                timer.invalidate()
                self.fadeInTimer = nil
                self.playbackState = .playing
                self.currentVolume = config.volume
                self.onFadeInComplete?()
                self.scheduleRepetition(config: config)
            }
        }
        
        RunLoop.current.add(fadeInTimer!, forMode: .default)
    }
    
    private func playSound(soundId: String, volume: Float) {
        if let customUrl = getCustomSoundUrl(for: soundId) {
            playCustomSound(url: customUrl, volume: volume)
        } else {
            playSystemSound(soundId: soundId, volume: volume)
        }
    }
    
    private func playSystemSound(soundId: String, volume: Float) {
        let systemSoundId = mapToSystemSoundId(soundId)
        
        device.play(.init(rawValue: systemSoundId))
        
        playbackState = .playing
    }
    
    private func playCustomSound(url: URL, volume: Float) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.volume = volume
            audioPlayer?.numberOfLoops = 0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            playbackState = .playing
        } catch {
            print("Failed to play custom sound: \(error)")
            playSystemSound(soundId: "default", volume: volume)
        }
    }
    
    private func getCustomSoundUrl(for soundId: String) -> URL? {
        let customSounds: [String: String] = [
            "gentle_wake": "gentle_wake.caf",
            "morning_breeze": "morning_breeze.caf",
            "sunrise": "sunrise.caf",
            "birds_chirping": "birds_chirping.caf",
            "ocean_waves": "ocean_waves.caf",
            "forest_stream": "forest_stream.caf",
            "classic_alarm": "classic_alarm.caf",
            "digital_beep": "digital_beep.caf",
            "piano_melody": "piano_melody.caf",
            "guitar_strum": "guitar_strum.caf",
            "wind_chimes": "wind_chimes.caf",
            "temple_bell": "temple_bell.caf",
            "crystal_clear": "crystal_clear.caf",
            "soft_chime": "soft_chime.caf"
        ]
        
        guard let fileName = customSounds[soundId] else { return nil }
        
        if let bundleUrl = Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".caf", with: ""), withExtension: "caf") {
            return bundleUrl
        }
        
        return nil
    }
    
    private func mapToSystemSoundId(_ soundId: String) -> UInt32 {
        switch soundId {
        case "default":
            return 1005
        case "classic_alarm":
            return 1004
        case "digital_beep":
            return 1003
        default:
            return 1005
        }
    }
    
    private func scheduleRepetition(config: AlarmPlaybackConfig) {
        guard config.repeatCount > 0 else { return }
        
        repeatTimer = Timer.scheduledTimer(withTimeInterval: config.repeatInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.currentRepeatCount += 1
            
            if self.currentRepeatCount >= config.repeatCount {
                timer.invalidate()
                self.repeatTimer = nil
                return
            }
            
            self.playSound(soundId: config.soundId, volume: self.currentVolume)
            self.onRepeatCycle?(self.currentRepeatCount)
        }
        
        RunLoop.current.add(repeatTimer!, forMode: .default)
    }
    
    private func startVibration() {
        isVibrating = true
        
        vibrationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.performVibrationPattern()
        }
        
        RunLoop.current.add(vibrationTimer!, forMode: .default)
        
        performVibrationPattern()
    }
    
    private func performVibrationPattern() {
        guard isVibrating else { return }
        
        device.play(.notification)
    }
    
    func stopAlarm() {
        audioPlayer?.stop()
        audioPlayer = nil
        
        fadeInTimer?.invalidate()
        fadeInTimer = nil
        
        vibrationTimer?.invalidate()
        vibrationTimer = nil
        
        repeatTimer?.invalidate()
        repeatTimer = nil
        
        isVibrating = false
        currentVolume = 0.0
        currentSoundId = nil
        currentConfig = nil
        currentRepeatCount = 0
        playbackState = .idle
        
        onPlaybackStopped?()
    }
    
    func pauseAlarm() {
        audioPlayer?.pause()
        
        vibrationTimer?.invalidate()
        vibrationTimer = nil
        isVibrating = false
        
        repeatTimer?.invalidate()
        repeatTimer = nil
        
        playbackState = .paused
    }
    
    func resumeAlarm() {
        guard let config = currentConfig else { return }
        
        audioPlayer?.play()
        
        if config.vibrationEnabled {
            startVibration()
        }
        
        scheduleRepetition(config: config)
        
        playbackState = .playing
    }
    
    func setVolume(_ volume: Float) {
        currentVolume = volume
        audioPlayer?.volume = volume
    }
    
    func snooze() {
        pauseAlarm()
        playbackState = .snoozed
    }
    
    func isPlaying() -> Bool {
        return playbackState == .playing || playbackState == .fadingIn
    }
    
    func getCurrentPlaybackTime() -> TimeInterval {
        return audioPlayer?.currentTime ?? 0
    }
    
    func getPlaybackDuration() -> TimeInterval {
        return audioPlayer?.duration ?? 0
    }
    
    func playPreview(soundId: String) {
        stopAlarm()
        
        currentSoundId = soundId
        currentVolume = 0.5
        
        playSound(soundId: soundId, volume: 0.5)
        
        device.play(.notification)
    }
    
    func stopPreview() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackState = .idle
    }
}

extension AlarmPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if playbackState == .playing && currentConfig?.repeatCount == 0 {
            playbackState = .idle
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio player decode error: \(error?.localizedDescription ?? "unknown")")
        playbackState = .idle
    }
}

extension AlarmPlayer {
    func playOptimalWakeAlarm() {
        let config = AlarmPlaybackConfig(
            soundId: "gentle_wake",
            volume: 0.6,
            vibrationEnabled: true,
            fadeInEnabled: true,
            fadeInDuration: 20.0,
            repeatCount: 2,
            repeatInterval: 8.0
        )
        
        playAlarm(config: config)
    }
    
    func playStandardAlarm(soundId: String = "default") {
        let config = AlarmPlaybackConfig(
            soundId: soundId,
            volume: 0.8,
            vibrationEnabled: true,
            fadeInEnabled: false,
            fadeInDuration: 0,
            repeatCount: 5,
            repeatInterval: 5.0
        )
        
        playAlarm(config: config)
    }
    
    func playSnoozeAlarm(soundId: String = "default") {
        let config = AlarmPlaybackConfig(
            soundId: soundId,
            volume: 1.0,
            vibrationEnabled: true,
            fadeInEnabled: false,
            fadeInDuration: 0,
            repeatCount: 10,
            repeatInterval: 3.0
        )
        
        playAlarm(config: config)
    }
}
