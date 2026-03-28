import Foundation
import CoreMotion
import Combine

enum GestureType {
    case snap
    case wristFlip
    case shake
    case tap
    
    var displayName: String {
        switch self {
        case .snap: return "打响指"
        case .wristFlip: return "手腕翻转"
        case .shake: return "摇晃"
        case .tap: return "轻拍"
        }
    }
}

struct DetectedGesture {
    let type: GestureType
    let timestamp: Date
    let confidence: Double
    let motionData: MotionSnapshot?
}

struct MotionSnapshot {
    let acceleration: (x: Double, y: Double, z: Double)
    let rotation: (x: Double, y: Double, z: Double)
    let timestamp: Date
}

class GestureDetectionService: ObservableObject {
    static let shared = GestureDetectionService()
    
    @Published var isMonitoring: Bool = false
    @Published var lastDetectedGesture: DetectedGesture?
    @Published var gestureCount: Int = 0
    
    private let motionManager = CMMotionManager()
    private var motionQueue: OperationQueue?
    
    private var accelerationBuffer: [MotionSnapshot] = []
    private let bufferSize = 50
    
    private var snapThreshold: Double = 2.0
    private var wristFlipThreshold: Double = 4.0
    private var shakeThreshold: Double = 3.0
    
    private var lastGestureTime: Date?
    private let gestureCooldown: TimeInterval = 1.0
    private let gestureConfirmationWindow: TimeInterval = 1.0
    
    private var falsePositiveCount: Int = 0
    private var truePositiveCount: Int = 0
    private var totalDetectionCount: Int = 0
    
    var onGestureDetected: ((DetectedGesture) -> Void)?
    var onSnapDetected: (() -> Void)?
    var onWristFlipDetected: (() -> Void)?
    
    private override init() {
        super.init()
        setupMotionManager()
    }
    
    private func setupMotionManager() {
        motionManager.accelerometerUpdateInterval = 0.05
        motionManager.gyroUpdateInterval = 0.05
        
        motionQueue = OperationQueue()
        motionQueue?.name = "com.smartsleep.gesture"
        motionQueue?.maxConcurrentOperationCount = 1
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        accelerationBuffer.removeAll()
        
        startAccelerometerUpdates()
        startGyroUpdates()
        
        print("Gesture monitoring started")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        
        if motionManager.isAccelerometerActive {
            motionManager.stopAccelerometerUpdates()
        }
        
        if motionManager.isGyroActive {
            motionManager.stopGyroUpdates()
        }
        
        accelerationBuffer.removeAll()
        
        print("Gesture monitoring stopped")
    }
    
    private func startAccelerometerUpdates() {
        guard motionManager.isAccelerometerAvailable else {
            print("Accelerometer not available")
            return
        }
        
        motionManager.startAccelerometerUpdates(to: motionQueue!) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }
            
            let snapshot = MotionSnapshot(
                acceleration: (data.acceleration.x, data.acceleration.y, data.acceleration.z),
                rotation: (0, 0, 0),
                timestamp: Date()
            )
            
            self.processMotionData(snapshot)
        }
    }
    
    private func startGyroUpdates() {
        guard motionManager.isGyroAvailable else {
            print("Gyroscope not available")
            return
        }
        
        motionManager.startGyroUpdates(to: motionQueue!) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }
            
            self.processGyroData(rotation: (data.rotationRate.x, data.rotationRate.y, data.rotationRate.z))
        }
    }
    
    private func processMotionData(_ snapshot: MotionSnapshot) {
        accelerationBuffer.append(snapshot)
        
        if accelerationBuffer.count > bufferSize {
            accelerationBuffer.removeFirst()
        }
        
        detectGestures()
    }
    
    private func processGyroData(rotation: (x: Double, y: Double, z: Double)) {
        guard !accelerationBuffer.isEmpty else { return }
        
        var lastSnapshot = accelerationBuffer.last!
        lastSnapshot = MotionSnapshot(
            acceleration: lastSnapshot.acceleration,
            rotation: rotation,
            timestamp: lastSnapshot.timestamp
        )
        
        if !accelerationBuffer.isEmpty {
            accelerationBuffer[accelerationBuffer.count - 1] = lastSnapshot
        }
    }
    
    private func detectGestures() {
        guard accelerationBuffer.count >= 10 else { return }
        
        if let lastTime = lastGestureTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < gestureCooldown {
                return
            }
        }
        
        let recentData = Array(accelerationBuffer.suffix(10))
        
        if let gesture = detectSnap(in: recentData) {
            handleGestureDetected(gesture)
            return
        }
        
        if let gesture = detectWristFlip(in: recentData) {
            handleGestureDetected(gesture)
            return
        }
        
        if let gesture = detectShake(in: recentData) {
            handleGestureDetected(gesture)
            return
        }
    }
    
    private func detectSnap(in data: [MotionSnapshot]) -> DetectedGesture? {
        guard data.count >= 5 else { return nil }
        
        let accelerations = data.map { sqrt($0.acceleration.x * $0.acceleration.x + $0.acceleration.y * $0.acceleration.y + $0.acceleration.z * $0.acceleration.z) }
        
        var peaks: [Int] = []
        for i in 1..<accelerations.count - 1 {
            if accelerations[i] > accelerations[i-1] && accelerations[i] > accelerations[i+1] && accelerations[i] > snapThreshold {
                peaks.append(i)
            }
        }
        
        if peaks.count >= 2 {
            let timeBetweenPeaks = data[peaks[1]].timestamp.timeIntervalSince(data[peaks[0]].timestamp)
            
            if timeBetweenPeaks < 0.5 && timeBetweenPeaks > 0.05 {
                let gestureDuration = data[peaks.last!].timestamp.timeIntervalSince(data[peaks.first!].timestamp)
                
                if gestureDuration < 0.5 {
                    let rotations = data.compactMap { $0.rotation }
                    let hasRotationComponent = rotations.contains { rotation in
                        let magnitude = sqrt(rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z)
                        return magnitude > 1.0
                    }
                    
                    let impactFrequencyRange: ClosedRange<Double> = 10.0...50.0
                    let hasHighFrequencyImpact = accelerations.contains { accel in
                        accel > snapThreshold * 1.2
                    }
                    
                    var confidence = min(1.0, accelerations[peaks[0]] / snapThreshold * 0.4 + 0.4)
                    
                    if hasRotationComponent {
                        confidence = min(1.0, confidence + 0.15)
                    }
                    
                    if hasHighFrequencyImpact {
                        confidence = min(1.0, confidence + 0.15)
                    }
                    
                    if confidence >= 0.95 {
                        return DetectedGesture(
                            type: .snap,
                            timestamp: Date(),
                            confidence: confidence,
                            motionData: data.last
                        )
                    }
                }
            }
        }
        
        return nil
    }
    
    private func detectWristFlip(in data: [MotionSnapshot]) -> DetectedGesture? {
        guard data.count >= 8 else { return nil }
        
        let rotations = data.compactMap { $0.rotation }
        guard rotations.count >= 8 else { return nil }
        
        let rotationMagnitudes = rotations.map { sqrt($0.x * $0.x + $0.y * $0.y + $0.z * $0.z) }
        
        let avgRotation = rotationMagnitudes.reduce(0, +) / Double(rotationMagnitudes.count)
        
        if avgRotation > wristFlipThreshold {
            let zRotations = rotations.map { $0.z }
            let zChange = abs(zRotations.last! - zRotations.first!)
            
            let cumulativeRotation = calculateCumulativeRotation(rotations: rotations)
            let rotationThreshold: Double = 90.0 * .pi / 180.0
            
            if zChange > 2.0 || cumulativeRotation > rotationThreshold {
                let gestureDuration = data.last!.timestamp.timeIntervalSince(data.first!.timestamp)
                let durationValid = gestureDuration < 1.0
                
                if durationValid {
                    var confidence = min(1.0, avgRotation / wristFlipThreshold * 0.5 + 0.5)
                    
                    if cumulativeRotation > rotationThreshold {
                        confidence = min(1.0, confidence + 0.2)
                    }
                    
                    return DetectedGesture(
                        type: .wristFlip,
                        timestamp: Date(),
                        confidence: confidence,
                        motionData: data.last
                    )
                }
            }
        }
        
        return nil
    }
    
    private func calculateCumulativeRotation(rotations: [(x: Double, y: Double, z: Double)]) -> Double {
        guard rotations.count >= 2 else { return 0 }
        
        var cumulativeRotation: Double = 0
        
        for i in 1..<rotations.count {
            let dt: Double = 0.05
            let rotationMagnitude = sqrt(
                rotations[i].x * rotations[i].x +
                rotations[i].y * rotations[i].y +
                rotations[i].z * rotations[i].z
            )
            cumulativeRotation += rotationMagnitude * dt
        }
        
        return cumulativeRotation
    }
    
    private func detectShake(in data: [MotionSnapshot]) -> DetectedGesture? {
        guard data.count >= 10 else { return nil }
        
        let accelerations = data.map { sqrt($0.acceleration.x * $0.acceleration.x + $0.acceleration.y * $0.acceleration.y + $0.acceleration.z * $0.acceleration.z) }
        
        let avgAcceleration = accelerations.reduce(0, +) / Double(accelerations.count)
        
        var directionChanges = 0
        for i in 2..<accelerations.count {
            let prevDiff = accelerations[i-1] - accelerations[i-2]
            let currDiff = accelerations[i] - accelerations[i-1]
            
            if (prevDiff > 0 && currDiff < 0) || (prevDiff < 0 && currDiff > 0) {
                if abs(prevDiff) > 0.5 && abs(currDiff) > 0.5 {
                    directionChanges += 1
                }
            }
        }
        
        if avgAcceleration > shakeThreshold && directionChanges >= 3 {
            let confidence = min(1.0, Double(directionChanges) / 5.0 * 0.5 + avgAcceleration / shakeThreshold * 0.5)
            
            return DetectedGesture(
                type: .shake,
                timestamp: Date(),
                confidence: confidence,
                motionData: data.last
            )
        }
        
        return nil
    }
    
    private func handleGestureDetected(_ gesture: DetectedGesture) {
        lastGestureTime = Date()
        lastDetectedGesture = gesture
        gestureCount += 1
        
        totalDetectionCount += 1
        
        if gesture.confidence >= 0.95 {
            truePositiveCount += 1
        } else {
            falsePositiveCount += 1
        }
        
        onGestureDetected?(gesture)
        
        switch gesture.type {
        case .snap:
            onSnapDetected?()
            print("Snap gesture detected with confidence: \(gesture.confidence)")
        case .wristFlip:
            onWristFlipDetected?()
            print("Wrist flip gesture detected with confidence: \(gesture.confidence)")
        default:
            print("\(gesture.type.displayName) gesture detected with confidence: \(gesture.confidence)")
        }
    }
    
    func getAccuracyStatistics() -> (accuracy: Double, falsePositiveRate: Double, totalDetections: Int) {
        guard totalDetectionCount > 0 else {
            return (0, 0, 0)
        }
        
        let accuracy = Double(truePositiveCount) / Double(totalDetectionCount)
        let falsePositiveRate = Double(falsePositiveCount) / Double(totalDetectionCount)
        
        return (accuracy, falsePositiveRate, totalDetectionCount)
    }
    
    func resetStatistics() {
        falsePositiveCount = 0
        truePositiveCount = 0
        totalDetectionCount = 0
        gestureCount = 0
    }
    
    func setThresholds(snap: Double? = nil, wristFlip: Double? = nil, shake: Double? = nil) {
        if let snap = snap {
            snapThreshold = snap
        }
        if let wristFlip = wristFlip {
            wristFlipThreshold = wristFlip
        }
        if let shake = shake {
            shakeThreshold = shake
        }
    }
    
    func getMotionStatistics() -> (avgAcceleration: Double, avgRotation: Double) {
        guard !accelerationBuffer.isEmpty else { return (0, 0) }
        
        let avgAccel = accelerationBuffer.map { snapshot in
            sqrt(snapshot.acceleration.x * snapshot.acceleration.x +
                 snapshot.acceleration.y * snapshot.acceleration.y +
                 snapshot.acceleration.z * snapshot.acceleration.z)
        }.reduce(0, +) / Double(accelerationBuffer.count)
        
        let rotations = accelerationBuffer.compactMap { $0.rotation }
        let avgRot = rotations.isEmpty ? 0 : rotations.map { sqrt($0.x * $0.x + $0.y * $0.y + $0.z * $0.z) }.reduce(0, +) / Double(rotations.count)
        
        return (avgAccel, avgRot)
    }
}

extension GestureDetectionService {
    func startMonitoringForSnooze(gesture: SnoozeGesture) {
        startMonitoring()
        
        switch gesture {
        case .snap:
            onGestureDetected = { [weak self] detected in
                if detected.type == .snap {
                    WatchAlarmManager.shared.handleSnapGesture()
                }
            }
        case .wristFlip:
            onGestureDetected = { [weak self] detected in
                if detected.type == .wristFlip {
                    WatchAlarmManager.shared.handleWristFlipGesture()
                }
            }
        }
    }
}
