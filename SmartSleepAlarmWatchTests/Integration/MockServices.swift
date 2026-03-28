import Foundation
import Combine
@testable import SmartSleepAlarmWatch

class MockAlarmController: AlarmControllable {
    var isRinging = false
    var silenceCallCount = 0
    var triggerCallCount = 0
    var lastSilencedTime: Date?
    var lastTriggeredAlarm: Alarm?
    
    var onAlarmTriggered: ((Alarm?) -> Void)?
    var onAlarmSilenced: ((Alarm?, Date) -> Void)?
    
    func silenceAlarm() {
        isRinging = false
        silenceCallCount += 1
        lastSilencedTime = Date()
        onAlarmSilenced?(lastTriggeredAlarm, Date())
    }
    
    func triggerAlarm() {
        triggerAlarm(for: nil)
    }
    
    func triggerAlarm(for alarm: Alarm?) {
        isRinging = true
        triggerCallCount += 1
        lastTriggeredAlarm = alarm
        onAlarmTriggered?(alarm)
    }
    
    func isAlarmRinging() -> Bool {
        return isRinging
    }
    
    func reset() {
        isRinging = false
        silenceCallCount = 0
        triggerCallCount = 0
        lastSilencedTime = nil
        lastTriggeredAlarm = nil
    }
}

class MockSensorService: ObservableObject {
    @Published var currentHeartRate: Double?
    @Published var currentAcceleration: (x: Double, y: Double, z: Double)?
    @Published var isMonitoring: Bool = false
    @Published var degradedMode: Bool = false
    
    var onSensorData: ((SensorData) -> Void)?
    var onSensorDegraded: (([SensorType]) -> Void)?
    var onSensorRecovered: ((SensorType) -> Void)?
    
    private var dataGenerationTimer: Timer?
    
    func simulateHeartRate(_ value: Double) {
        currentHeartRate = value
        
        let data = SensorData(
            timestamp: Date(),
            heartRate: value,
            heartRateVariability: nil,
            accelerationX: currentAcceleration?.x,
            accelerationY: currentAcceleration?.y,
            accelerationZ: currentAcceleration?.z,
            rotationRateX: nil,
            rotationRateY: nil,
            rotationRateZ: nil
        )
        onSensorData?(data)
    }
    
    func simulateMotion(x: Double, y: Double, z: Double) {
        currentAcceleration = (x, y, z)
        
        let data = SensorData(
            timestamp: Date(),
            heartRate: currentHeartRate,
            heartRateVariability: nil,
            accelerationX: x,
            accelerationY: y,
            accelerationZ: z,
            rotationRateX: nil,
            rotationRateY: nil,
            rotationRateZ: nil
        )
        onSensorData?(data)
    }
    
    func simulateDegradedMode(_ sensors: [SensorType]) {
        degradedMode = true
        onSensorDegraded?(sensors)
    }
    
    func simulateRecovery(_ sensor: SensorType) {
        onSensorRecovered?(sensor)
    }
    
    func startDataGeneration(baselineHR: Double = 60.0, baselineMotion: Double = 0.1) {
        isMonitoring = true
        currentHeartRate = baselineHR
        currentAcceleration = (baselineMotion, baselineMotion, baselineMotion)
    }
    
    func stopDataGeneration() {
        isMonitoring = false
        dataGenerationTimer?.invalidate()
        dataGenerationTimer = nil
    }
    
    func reset() {
        currentHeartRate = nil
        currentAcceleration = nil
        isMonitoring = false
        degradedMode = false
        stopDataGeneration()
    }
}

class MockGestureDetectionService: ObservableObject {
    @Published var isMonitoring: Bool = false
    @Published var lastDetectedGesture: DetectedGesture?
    @Published var gestureCount: Int = 0
    
    var onGestureDetected: ((DetectedGesture) -> Void)?
    var onSnapDetected: (() -> Void)?
    var onWristFlipDetected: (() -> Void)?
    
    func simulateGesture(_ type: GestureType, confidence: Double = 0.95) {
        let gesture = DetectedGesture(
            type: type,
            timestamp: Date(),
            confidence: confidence,
            motionData: nil
        )
        lastDetectedGesture = gesture
        gestureCount += 1
        onGestureDetected?(gesture)
        
        switch type {
        case .snap:
            onSnapDetected?()
        case .wristFlip:
            onWristFlipDetected?()
        default:
            break
        }
    }
    
    func startMonitoring() {
        isMonitoring = true
    }
    
    func stopMonitoring() {
        isMonitoring = false
    }
    
    func reset() {
        isMonitoring = false
        lastDetectedGesture = nil
        gestureCount = 0
    }
}

class MockAlarmPlayer: ObservableObject {
    @Published var playbackState: AlarmPlaybackState = .idle
    @Published var currentVolume: Float = 0.0
    @Published var isVibrating: Bool = false
    
    var playCallCount = 0
    var stopCallCount = 0
    var pauseCallCount = 0
    var snoozeCallCount = 0
    var lastConfig: AlarmPlaybackConfig?
    
    var onPlaybackStarted: (() -> Void)?
    var onPlaybackStopped: (() -> Void)?
    
    func playAlarm(config: AlarmPlaybackConfig = .default) {
        playCallCount += 1
        lastConfig = config
        playbackState = .playing
        currentVolume = config.volume
        onPlaybackStarted?()
    }
    
    func stopAlarm() {
        stopCallCount += 1
        playbackState = .idle
        currentVolume = 0.0
        isVibrating = false
        onPlaybackStopped?()
    }
    
    func pauseAlarm() {
        pauseCallCount += 1
        playbackState = .paused
    }
    
    func snooze() {
        snoozeCallCount += 1
        playbackState = .snoozed
    }
    
    func isPlaying() -> Bool {
        return playbackState == .playing || playbackState == .fadingIn
    }
    
    func reset() {
        playbackState = .idle
        currentVolume = 0.0
        isVibrating = false
        playCallCount = 0
        stopCallCount = 0
        pauseCallCount = 0
        snoozeCallCount = 0
        lastConfig = nil
    }
}

class TestDataFactory {
    static func createAlarm(
        id: UUID = UUID(),
        time: Date = Date(),
        repeatDays: [Int] = [],
        ringtone: String = "default",
        label: String = "Test Alarm",
        isEnabled: Bool = true,
        isSmartModeEnabled: Bool = false,
        snoozeInterval: Int = 5,
        snoozeGesture: SnoozeGesture = .snap
    ) -> Alarm {
        return Alarm(
            id: id,
            time: time,
            repeatDays: repeatDays,
            ringtone: ringtone,
            label: label,
            isEnabled: isEnabled,
            isSmartModeEnabled: isSmartModeEnabled,
            snoozeInterval: snoozeInterval,
            snoozeGesture: snoozeGesture
        )
    }
    
    static func createAwakeSignal(
        type: AwakeSignalType,
        confidence: Double = 0.8,
        rawValue: Double = 1.0,
        threshold: Double = 0.5
    ) -> AwakeSignal {
        return AwakeSignal(
            timestamp: Date(),
            type: type,
            confidence: confidence,
            rawValue: rawValue,
            threshold: threshold
        )
    }
    
    static func createSensorData(
        heartRate: Double? = nil,
        acceleration: (x: Double, y: Double, z: Double)? = nil
    ) -> SensorData {
        return SensorData(
            timestamp: Date(),
            heartRate: heartRate,
            heartRateVariability: nil,
            accelerationX: acceleration?.x,
            accelerationY: acceleration?.y,
            accelerationZ: acceleration?.z,
            rotationRateX: nil,
            rotationRateY: nil,
            rotationRateZ: nil
        )
    }
    
    static func createMotionSnapshots(count: Int, baseAcceleration: Double = 1.0) -> [MotionSnapshot] {
        return (0..<count).map { i in
            let variation = Double.random(in: -0.5...0.5)
            return MotionSnapshot(
                acceleration: (baseAcceleration + variation, baseAcceleration + variation, baseAcceleration + variation),
                rotation: (0.1, 0.1, 0.1),
                timestamp: Date().addingTimeInterval(Double(i) * 0.05)
            )
        }
    }
}

extension AwakeDetectionState: Equatable {
    public static func == (lhs: AwakeDetectionState, rhs: AwakeDetectionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.monitoring, .monitoring):
            return true
        case (.alarmRinging, .alarmRinging):
            return true
        case (.confirmingAwake, .confirmingAwake):
            return true
        case (.alarmSilenced, .alarmSilenced):
            return true
        case (.antiSleepMonitoring, .antiSleepMonitoring):
            return true
        case (.reAlarmPending(let lReason), .reAlarmPending(let rReason)):
            return lReason == rReason
        default:
            return false
        }
    }
}
