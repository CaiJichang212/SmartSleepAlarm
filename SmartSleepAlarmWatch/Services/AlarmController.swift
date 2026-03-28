import Foundation
import AVFoundation
import WatchKit

class AlarmController: NSObject, AlarmControllable {
    static let shared = AlarmController()
    
    @Published var isRinging: Bool = false
    @Published var currentAlarm: Alarm?
    @Published var ringStartTime: Date?
    
    private var audioPlayer: AVAudioPlayer?
    private var hapticTimer: Timer?
    private var ringtoneTimer: Timer?
    
    private let hapticInterval: TimeInterval = 0.5
    private let maxRingDuration: TimeInterval = 60.0
    
    var onAlarmTriggered: ((Alarm) -> Void)?
    var onAlarmSilenced: ((Alarm?, Date) -> Void)?
    var onMaxDurationReached: ((Alarm) -> Void)?
    
    private override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func triggerAlarm() {
        triggerAlarm(for: nil)
    }
    
    func triggerAlarm(for alarm: Alarm?) {
        guard !isRinging else {
            print("Alarm already ringing")
            return
        }
        
        currentAlarm = alarm
        isRinging = true
        ringStartTime = Date()
        
        startRingtone()
        startHapticFeedback()
        startMaxDurationTimer()
        
        WKInterfaceDevice.current().play(.notification)
        
        if let alarm = alarm {
            onAlarmTriggered?(alarm)
            print("Alarm triggered for: \(alarm.formattedTime)")
        } else {
            print("Alarm triggered (no specific alarm)")
        }
    }
    
    func silenceAlarm() {
        guard isRinging else { return }
        
        let silencedTime = Date()
        
        stopRingtone()
        stopHapticFeedback()
        stopMaxDurationTimer()
        
        isRinging = false
        
        let silencedAlarm = currentAlarm
        currentAlarm = nil
        
        if let startTime = ringStartTime {
            let duration = silencedTime.timeIntervalSince(startTime)
            print("Alarm silenced after \(String(format: "%.1f", duration)) seconds")
        }
        
        ringStartTime = nil
        
        onAlarmSilenced?(silencedAlarm, silencedTime)
    }
    
    func isAlarmRinging() -> Bool {
        return isRinging
    }
    
    private func startRingtone() {
        guard let soundURL = Bundle.main.url(forResource: "alarm_sound", withExtension: "wav") else {
            print("Ringtone file not found, using system sound")
            playSystemSound()
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 0.8
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Failed to play ringtone: \(error)")
            playSystemSound()
        }
    }
    
    private func playSystemSound() {
        ringtoneTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            WKInterfaceDevice.current().play(.notification)
        }
    }
    
    private func stopRingtone() {
        audioPlayer?.stop()
        audioPlayer = nil
        
        ringtoneTimer?.invalidate()
        ringtoneTimer = nil
    }
    
    private func startHapticFeedback() {
        hapticTimer = Timer.scheduledTimer(withTimeInterval: hapticInterval, repeats: true) { _ in
            WKInterfaceDevice.current().play(.click)
        }
        
        RunLoop.current.add(hapticTimer!, forMode: .default)
    }
    
    private func stopHapticFeedback() {
        hapticTimer?.invalidate()
        hapticTimer = nil
    }
    
    private func startMaxDurationTimer() {
        Timer.scheduledTimer(withTimeInterval: maxRingDuration, repeats: false) { [weak self] _ in
            self?.handleMaxDurationReached()
        }
    }
    
    private func stopMaxDurationTimer() {
    }
    
    private func handleMaxDurationReached() {
        guard isRinging, let alarm = currentAlarm else { return }
        
        print("Max ring duration reached")
        silenceAlarm()
        onMaxDurationReached?(alarm)
    }
    
    func snoozeAlarm(duration: TimeInterval = 300) {
        guard isRinging else { return }
        
        silenceAlarm()
        
        print("Alarm snoozed for \(Int(duration)) seconds")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.triggerAlarm(for: self?.currentAlarm)
        }
    }
    
    func getRingDuration() -> TimeInterval? {
        guard let startTime = ringStartTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }
    
    func setVolume(_ volume: Float) {
        audioPlayer?.volume = min(1.0, max(0.0, volume))
    }
}

extension AlarmController {
    func playPreviewRingtone() {
        guard !isRinging else { return }
        
        if let soundURL = Bundle.main.url(forResource: "alarm_sound", withExtension: "wav") {
            do {
                let previewPlayer = try AVAudioPlayer(contentsOf: soundURL)
                previewPlayer.numberOfLoops = 0
                previewPlayer.volume = 0.5
                previewPlayer.prepareToPlay()
                previewPlayer.play()
            } catch {
                print("Failed to play preview: \(error)")
            }
        }
    }
}
