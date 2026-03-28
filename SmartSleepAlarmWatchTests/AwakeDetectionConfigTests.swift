import XCTest
@testable import SmartSleepAlarmWatch

final class AwakeDetectionConfigTests: XCTestCase {
    
    func testDefaultConfig() {
        let config = AwakeDetectionConfig.default
        
        XCTAssertEqual(config.heartRateThresholdPercentage, 0.10)
        XCTAssertEqual(config.motionThresholdStdDev, 0.3)
        XCTAssertEqual(config.confirmationWindowSeconds, 3.0)
        XCTAssertEqual(config.antiSleepMonitorDurationSeconds, 300.0)
        XCTAssertEqual(config.alarmSilenceMaxDelaySeconds, 5.0)
        XCTAssertEqual(config.reAlarmThreshold, 0.3)
        XCTAssertEqual(config.reAlarmCooldownSeconds, 30.0)
        XCTAssertEqual(config.minHeartRateSamples, 3)
        XCTAssertEqual(config.minMotionSamples, 5)
        XCTAssertEqual(config.baselineHeartRateWindowMinutes, 5)
        XCTAssertEqual(config.motionAnalysisWindowSeconds, 10.0)
    }
    
    func testSensitiveConfig() {
        let config = AwakeDetectionConfig.sensitive
        
        XCTAssertEqual(config.heartRateThresholdPercentage, 0.08)
        XCTAssertEqual(config.motionThresholdStdDev, 0.2)
        XCTAssertEqual(config.confirmationWindowSeconds, 2.0)
        XCTAssertEqual(config.minHeartRateSamples, 2)
        XCTAssertEqual(config.minMotionSamples, 3)
    }
    
    func testConservativeConfig() {
        let config = AwakeDetectionConfig.conservative
        
        XCTAssertEqual(config.heartRateThresholdPercentage, 0.15)
        XCTAssertEqual(config.motionThresholdStdDev, 0.4)
        XCTAssertEqual(config.confirmationWindowSeconds, 5.0)
        XCTAssertEqual(config.minHeartRateSamples, 5)
        XCTAssertEqual(config.minMotionSamples, 7)
    }
    
    func testConfigCodable() {
        let original = AwakeDetectionConfig(
            heartRateThresholdPercentage: 0.12,
            motionThresholdStdDev: 0.35,
            confirmationWindowSeconds: 4.0,
            antiSleepMonitorDurationSeconds: 400.0,
            alarmSilenceMaxDelaySeconds: 6.0,
            reAlarmThreshold: 0.25,
            reAlarmCooldownSeconds: 35.0,
            minHeartRateSamples: 4,
            minMotionSamples: 6,
            baselineHeartRateWindowMinutes: 6,
            motionAnalysisWindowSeconds: 12.0
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(AwakeDetectionConfig.self, from: data)
            
            XCTAssertEqual(decoded.heartRateThresholdPercentage, original.heartRateThresholdPercentage)
            XCTAssertEqual(decoded.motionThresholdStdDev, original.motionThresholdStdDev)
            XCTAssertEqual(decoded.confirmationWindowSeconds, original.confirmationWindowSeconds)
            XCTAssertEqual(decoded.minHeartRateSamples, original.minHeartRateSamples)
        } catch {
            XCTFail("Coding failed: \(error)")
        }
    }
}

final class AwakeDetectionModeTests: XCTestCase {
    
    func testAllCases() {
        XCTAssertEqual(AwakeDetectionMode.allCases.count, 3)
        XCTAssertEqual(AwakeDetectionMode.default.displayName, "默认")
        XCTAssertEqual(AwakeDetectionMode.sensitive.displayName, "敏感")
        XCTAssertEqual(AwakeDetectionMode.conservative.displayName, "保守")
    }
    
    func testModeConfigMapping() {
        let defaultConfig = AwakeDetectionMode.default.config
        XCTAssertEqual(defaultConfig.heartRateThresholdPercentage, AwakeDetectionConfig.default.heartRateThresholdPercentage)
        
        let sensitiveConfig = AwakeDetectionMode.sensitive.config
        XCTAssertEqual(sensitiveConfig.heartRateThresholdPercentage, AwakeDetectionConfig.sensitive.heartRateThresholdPercentage)
        
        let conservativeConfig = AwakeDetectionMode.conservative.config
        XCTAssertEqual(conservativeConfig.heartRateThresholdPercentage, AwakeDetectionConfig.conservative.heartRateThresholdPercentage)
    }
    
    func testModeCodable() {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for mode in AwakeDetectionMode.allCases {
            do {
                let data = try encoder.encode(mode)
                let decoded = try decoder.decode(AwakeDetectionMode.self, from: data)
                XCTAssertEqual(decoded, mode)
            } catch {
                XCTFail("Coding failed for \(mode): \(error)")
            }
        }
    }
}

final class AwakeSignalTests: XCTestCase {
    
    func testAwakeSignalCreation() {
        let signal = AwakeSignal(
            timestamp: Date(),
            type: .heartRateIncrease,
            confidence: 0.8,
            rawValue: 75.0,
            threshold: 70.0
        )
        
        XCTAssertEqual(signal.type, .heartRateIncrease)
        XCTAssertEqual(signal.confidence, 0.8, accuracy: 0.001)
        XCTAssertEqual(signal.rawValue, 75.0, accuracy: 0.001)
        XCTAssertEqual(signal.threshold, 70.0, accuracy: 0.001)
    }
    
    func testAwakeSignalSignificance() {
        let significantSignal = AwakeSignal(
            timestamp: Date(),
            type: .heartRateIncrease,
            confidence: 0.6,
            rawValue: 75.0,
            threshold: 70.0
        )
        XCTAssertTrue(significantSignal.isSignificant)
        
        let insignificantSignal = AwakeSignal(
            timestamp: Date(),
            type: .heartRateIncrease,
            confidence: 0.4,
            rawValue: 72.0,
            threshold: 70.0
        )
        XCTAssertFalse(insignificantSignal.isSignificant)
    }
    
    func testAwakeSignalSignificanceBoundary() {
        let boundarySignal = AwakeSignal(
            timestamp: Date(),
            type: .motionActivity,
            confidence: 0.5,
            rawValue: 0.3,
            threshold: 0.3
        )
        XCTAssertTrue(boundarySignal.isSignificant)
    }
    
    func testAwakeSignalEquatable() {
        let signal1 = AwakeSignal(
            timestamp: Date(),
            type: .heartRateIncrease,
            confidence: 0.8,
            rawValue: 75.0,
            threshold: 70.0
        )
        
        let signal2 = AwakeSignal(
            timestamp: signal1.timestamp,
            type: .heartRateIncrease,
            confidence: 0.8,
            rawValue: 75.0,
            threshold: 70.0
        )
        
        XCTAssertEqual(signal1, signal2)
    }
}

final class AwakeSignalTypeTests: XCTestCase {
    
    func testAllCases() {
        XCTAssertEqual(AwakeSignalType.allCases.count, 3)
        XCTAssertEqual(AwakeSignalType.heartRateIncrease.displayName, "心率升高")
        XCTAssertEqual(AwakeSignalType.motionActivity.displayName, "体动活动")
        XCTAssertEqual(AwakeSignalType.combined.displayName, "综合信号")
    }
    
    func testCodable() {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for type in AwakeSignalType.allCases {
            do {
                let data = try encoder.encode(type)
                let decoded = try decoder.decode(AwakeSignalType.self, from: data)
                XCTAssertEqual(decoded, type)
            } catch {
                XCTFail("Coding failed for \(type): \(error)")
            }
        }
    }
}

final class AwakeDetectionStateTests: XCTestCase {
    
    func testIdleState() {
        let state: AwakeDetectionState = .idle
        XCTAssertEqual(state.displayName, "空闲")
        XCTAssertFalse(state.isAlarmActive)
    }
    
    func testMonitoringState() {
        let state: AwakeDetectionState = .monitoring
        XCTAssertEqual(state.displayName, "监测中")
        XCTAssertFalse(state.isAlarmActive)
    }
    
    func testAlarmRingingState() {
        let startTime = Date()
        let state: AwakeDetectionState = .alarmRinging(startTime: startTime)
        XCTAssertEqual(state.displayName, "闹铃响铃中")
        XCTAssertTrue(state.isAlarmActive)
    }
    
    func testConfirmingAwakeState() {
        let signals: [AwakeSignal] = []
        let startTime = Date()
        let state: AwakeDetectionState = .confirmingAwake(signals: signals, startTime: startTime)
        XCTAssertEqual(state.displayName, "确认清醒中")
        XCTAssertFalse(state.isAlarmActive)
    }
    
    func testAlarmSilencedState() {
        let silenceTime = Date()
        let state: AwakeDetectionState = .alarmSilenced(silenceTime: silenceTime)
        XCTAssertEqual(state.displayName, "闹铃已静音")
        XCTAssertFalse(state.isAlarmActive)
    }
    
    func testAntiSleepMonitoringState() {
        let startTime = Date()
        let state: AwakeDetectionState = .antiSleepMonitoring(startTime: startTime)
        XCTAssertEqual(state.displayName, "防再睡监测中")
        XCTAssertFalse(state.isAlarmActive)
    }
    
    func testReAlarmPendingState() {
        let state: AwakeDetectionState = .reAlarmPending(reason: "检测到再次入睡")
        XCTAssertTrue(state.displayName.contains("等待重响"))
        XCTAssertTrue(state.isAlarmActive)
    }
    
    func testStateEquatable() {
        let state1: AwakeDetectionState = .idle
        let state2: AwakeDetectionState = .idle
        XCTAssertEqual(state1, state2)
        
        let state3: AwakeDetectionState = .monitoring
        XCTAssertNotEqual(state1, state3)
    }
}

final class AwakeDetectionResultTests: XCTestCase {
    
    func testResultCreation() {
        let signal = AwakeSignal(
            timestamp: Date(),
            type: .heartRateIncrease,
            confidence: 0.8,
            rawValue: 75.0,
            threshold: 70.0
        )
        
        let result = AwakeDetectionResult(
            timestamp: Date(),
            isAwake: true,
            confidence: 0.85,
            signals: [signal],
            heartRateValue: 75.0,
            motionValue: 0.35,
            baselineHeartRate: 65.0
        )
        
        XCTAssertTrue(result.isAwake)
        XCTAssertEqual(result.confidence, 0.85, accuracy: 0.001)
        XCTAssertEqual(result.signals.count, 1)
        XCTAssertEqual(result.heartRateValue, 75.0)
        XCTAssertEqual(result.motionValue, 0.35)
        XCTAssertEqual(result.baselineHeartRate, 65.0)
    }
    
    func testResultSummary() {
        let signal1 = AwakeSignal(
            timestamp: Date(),
            type: .heartRateIncrease,
            confidence: 0.8,
            rawValue: 75.0,
            threshold: 70.0
        )
        let signal2 = AwakeSignal(
            timestamp: Date(),
            type: .motionActivity,
            confidence: 0.7,
            rawValue: 0.35,
            threshold: 0.3
        )
        
        let result = AwakeDetectionResult(
            timestamp: Date(),
            isAwake: true,
            confidence: 0.85,
            signals: [signal1, signal2],
            heartRateValue: 75.0,
            motionValue: 0.35,
            baselineHeartRate: 65.0
        )
        
        let summary = result.summary
        XCTAssertTrue(summary.contains("清醒: 是"))
        XCTAssertTrue(summary.contains("置信度"))
        XCTAssertTrue(summary.contains("心率升高"))
        XCTAssertTrue(summary.contains("体动活动"))
    }
    
    func testResultCodable() {
        let signal = AwakeSignal(
            timestamp: Date(),
            type: .heartRateIncrease,
            confidence: 0.8,
            rawValue: 75.0,
            threshold: 70.0
        )
        
        let original = AwakeDetectionResult(
            timestamp: Date(),
            isAwake: true,
            confidence: 0.85,
            signals: [signal],
            heartRateValue: 75.0,
            motionValue: 0.35,
            baselineHeartRate: 65.0
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(AwakeDetectionResult.self, from: data)
            
            XCTAssertEqual(decoded.isAwake, original.isAwake)
            XCTAssertEqual(decoded.confidence, original.confidence, accuracy: 0.001)
            XCTAssertEqual(decoded.signals.count, original.signals.count)
            XCTAssertEqual(decoded.heartRateValue, original.heartRateValue)
        } catch {
            XCTFail("Coding failed: \(error)")
        }
    }
}

final class AntiSleepMonitorStatusTests: XCTestCase {
    
    func testStatusCreation() {
        let startTime = Date()
        let status = AntiSleepMonitorStatus(
            startTime: startTime,
            awakeSignalsCount: 5,
            sleepSignalsCount: 2,
            lastCheckTime: Date()
        )
        
        XCTAssertEqual(status.awakeSignalsCount, 5)
        XCTAssertEqual(status.sleepSignalsCount, 2)
        XCTAssertNotNil(status.lastCheckTime)
    }
    
    func testIsUserAwake() {
        let awakeStatus = AntiSleepMonitorStatus(
            startTime: Date(),
            awakeSignalsCount: 5,
            sleepSignalsCount: 2,
            lastCheckTime: nil
        )
        XCTAssertTrue(awakeStatus.isUserAwake)
        
        let asleepStatus = AntiSleepMonitorStatus(
            startTime: Date(),
            awakeSignalsCount: 2,
            sleepSignalsCount: 5,
            lastCheckTime: nil
        )
        XCTAssertFalse(asleepStatus.isUserAwake)
    }
    
    func testProgress() {
        let startTime = Date().addingTimeInterval(-150)
        let status = AntiSleepMonitorStatus(
            startTime: startTime,
            awakeSignalsCount: 3,
            sleepSignalsCount: 1,
            lastCheckTime: nil
        )
        
        let progress = status.progress
        XCTAssertGreaterThan(progress, 0)
        XCTAssertLessThan(progress, 1)
    }
    
    func testDuration() {
        let startTime = Date().addingTimeInterval(-100)
        let status = AntiSleepMonitorStatus(
            startTime: startTime,
            awakeSignalsCount: 3,
            sleepSignalsCount: 1,
            lastCheckTime: nil
        )
        
        let duration = status.duration
        XCTAssertGreaterThan(duration, 99)
        XCTAssertLessThan(duration, 101)
    }
    
    func testRemainingTime() {
        let startTime = Date().addingTimeInterval(-200)
        let status = AntiSleepMonitorStatus(
            startTime: startTime,
            awakeSignalsCount: 3,
            sleepSignalsCount: 1,
            lastCheckTime: nil
        )
        
        let remaining = status.remainingTime
        XCTAssertGreaterThan(remaining, 95)
        XCTAssertLessThan(remaining, 105)
    }
    
    func testCodable() {
        let original = AntiSleepMonitorStatus(
            startTime: Date(),
            awakeSignalsCount: 5,
            sleepSignalsCount: 3,
            lastCheckTime: Date()
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(AntiSleepMonitorStatus.self, from: data)
            
            XCTAssertEqual(decoded.awakeSignalsCount, original.awakeSignalsCount)
            XCTAssertEqual(decoded.sleepSignalsCount, original.sleepSignalsCount)
        } catch {
            XCTFail("Coding failed: \(error)")
        }
    }
}
