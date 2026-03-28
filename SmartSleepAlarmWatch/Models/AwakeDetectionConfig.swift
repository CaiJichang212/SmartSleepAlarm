import Foundation

struct AwakeDetectionConfig: Codable {
    var heartRateThresholdPercentage: Double
    var motionThresholdStdDev: Double
    var confirmationWindowSeconds: TimeInterval
    var antiSleepMonitorDurationSeconds: TimeInterval
    var alarmSilenceMaxDelaySeconds: TimeInterval
    var reAlarmThreshold: Double
    var reAlarmCooldownSeconds: TimeInterval
    var minHeartRateSamples: Int
    var minMotionSamples: Int
    var baselineHeartRateWindowMinutes: Int
    var motionAnalysisWindowSeconds: TimeInterval
    
    static let `default` = AwakeDetectionConfig(
        heartRateThresholdPercentage: 0.10,
        motionThresholdStdDev: 0.3,
        confirmationWindowSeconds: 3.0,
        antiSleepMonitorDurationSeconds: 300.0,
        alarmSilenceMaxDelaySeconds: 5.0,
        reAlarmThreshold: 0.3,
        reAlarmCooldownSeconds: 30.0,
        minHeartRateSamples: 3,
        minMotionSamples: 5,
        baselineHeartRateWindowMinutes: 5,
        motionAnalysisWindowSeconds: 10.0
    )
    
    static let sensitive = AwakeDetectionConfig(
        heartRateThresholdPercentage: 0.08,
        motionThresholdStdDev: 0.2,
        confirmationWindowSeconds: 2.0,
        antiSleepMonitorDurationSeconds: 300.0,
        alarmSilenceMaxDelaySeconds: 3.0,
        reAlarmThreshold: 0.35,
        reAlarmCooldownSeconds: 20.0,
        minHeartRateSamples: 2,
        minMotionSamples: 3,
        baselineHeartRateWindowMinutes: 3,
        motionAnalysisWindowSeconds: 8.0
    )
    
    static let conservative = AwakeDetectionConfig(
        heartRateThresholdPercentage: 0.15,
        motionThresholdStdDev: 0.4,
        confirmationWindowSeconds: 5.0,
        antiSleepMonitorDurationSeconds: 300.0,
        alarmSilenceMaxDelaySeconds: 5.0,
        reAlarmThreshold: 0.25,
        reAlarmCooldownSeconds: 45.0,
        minHeartRateSamples: 5,
        minMotionSamples: 7,
        baselineHeartRateWindowMinutes: 7,
        motionAnalysisWindowSeconds: 15.0
    )
}

enum AwakeDetectionMode: String, Codable, CaseIterable {
    case `default` = "默认"
    case sensitive = "敏感"
    case conservative = "保守"
    
    var displayName: String {
        rawValue
    }
    
    var config: AwakeDetectionConfig {
        switch self {
        case .default: return .default
        case .sensitive: return .sensitive
        case .conservative: return .conservative
        }
    }
}

struct AwakeSignal: Equatable {
    let timestamp: Date
    let type: AwakeSignalType
    let confidence: Double
    let rawValue: Double
    let threshold: Double
    
    var isSignificant: Bool {
        confidence >= 0.5
    }
}

enum AwakeSignalType: String, Codable {
    case heartRateIncrease = "心率升高"
    case motionActivity = "体动活动"
    case combined = "综合信号"
    
    var displayName: String {
        rawValue
    }
}

enum AwakeDetectionState: Equatable {
    case idle
    case monitoring
    case alarmRinging(startTime: Date)
    case confirmingAwake(signals: [AwakeSignal], startTime: Date)
    case alarmSilenced(silenceTime: Date)
    case antiSleepMonitoring(startTime: Date)
    case reAlarmPending(reason: String)
    
    var displayName: String {
        switch self {
        case .idle: return "空闲"
        case .monitoring: return "监测中"
        case .alarmRinging: return "闹铃响铃中"
        case .confirmingAwake: return "确认清醒中"
        case .alarmSilenced: return "闹铃已静音"
        case .antiSleepMonitoring: return "防再睡监测中"
        case .reAlarmPending(let reason): return "等待重响: \(reason)"
        }
    }
    
    var isAlarmActive: Bool {
        switch self {
        case .alarmRinging, .reAlarmPending: return true
        default: return false
        }
    }
}

struct AwakeDetectionResult: Codable {
    let timestamp: Date
    let isAwake: Bool
    let confidence: Double
    let signals: [AwakeSignal]
    let heartRateValue: Double?
    let motionValue: Double?
    let baselineHeartRate: Double?
    
    var summary: String {
        let signalTypes = signals.map { $0.type.displayName }.joined(separator: ", ")
        return "清醒: \(isAwake ? "是" : "否"), 置信度: \(Int(confidence * 100))%, 信号: [\(signalTypes)]"
    }
}

struct AntiSleepMonitorStatus: Codable {
    let startTime: Date
    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
    var remainingTime: TimeInterval {
        max(0, 300.0 - duration)
    }
    var awakeSignalsCount: Int
    var sleepSignalsCount: Int
    var lastCheckTime: Date?
    var isUserAwake: Bool {
        awakeSignalsCount > sleepSignalsCount
    }
    var progress: Double {
        min(1.0, duration / 300.0)
    }
}
