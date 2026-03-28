import Foundation
import HealthKit
import CoreMotion
import Combine

struct SensorData {
    let timestamp: Date
    let heartRate: Double?
    let heartRateVariability: Double?
    let accelerationX: Double?
    let accelerationY: Double?
    let accelerationZ: Double?
    let rotationRateX: Double?
    let rotationRateY: Double?
    let rotationRateZ: Double?
    
    var hasHeartRate: Bool { heartRate != nil }
    var hasMotion: Bool { accelerationX != nil && accelerationY != nil && accelerationZ != nil }
    
    var accelerationMagnitude: Double? {
        guard let x = accelerationX, let y = accelerationY, let z = accelerationZ else { return nil }
        return sqrt(x * x + y * y + z * z)
    }
}

enum SensorType {
    case heartRate
    case heartRateVariability
    case accelerometer
    case gyroscope
    
    var displayName: String {
        switch self {
        case .heartRate: return "心率"
        case .heartRateVariability: return "心率变异性"
        case .accelerometer: return "加速度计"
        case .gyroscope: return "陀螺仪"
        }
    }
}

enum SensorAvailability {
    case available
    case notAvailable
    case degraded
    case permissionDenied
    
    var isUsable: Bool {
        switch self {
        case .available, .degraded: return true
        default: return false
        }
    }
}

struct SensorStatus {
    let type: SensorType
    let availability: SensorAvailability
    let lastDataTime: Date?
    let consecutiveMisses: Int
    
    var isDataStale: Bool {
        guard let lastTime = lastDataTime else { return true }
        return Date().timeIntervalSince(lastTime) > 30
    }
}

class SensorService: ObservableObject {
    static let shared = SensorService()
    
    @Published var isMonitoring: Bool = false
    @Published var currentHeartRate: Double?
    @Published var currentAcceleration: (x: Double, y: Double, z: Double)?
    @Published var sensorStatuses: [SensorType: SensorStatus] = [:]
    @Published var degradedMode: Bool = false
    
    private let healthStore = HKHealthStore()
    private let motionManager = CMMotionManager()
    
    private var heartRateQuery: HKQuery?
    private var heartRateQueryAnchor: HKQueryAnchor?
    
    private let dataQueue = DispatchQueue(label: "com.smartsleep.sensordata", qos: .utility)
    private var dataBuffer: [SensorData] = []
    private let maxBufferSize = 1000
    
    private var consecutiveHeartRateMisses = 0
    private var consecutiveMotionMisses = 0
    private let maxConsecutiveMisses = 5
    
    private var dataCollectionTimer: Timer?
    private let collectionInterval: TimeInterval = 5.0
    
    var onSensorData: ((SensorData) -> Void)?
    var onSensorDegraded: (([SensorType]) -> Void)?
    var onSensorRecovered: ((SensorType) -> Void)?
    
    private override init() {
        super.init()
        setupMotionManager()
        initializeSensorStatuses()
    }
    
    private func setupMotionManager() {
        motionManager.accelerometerUpdateInterval = 1.0
        motionManager.gyroUpdateInterval = 1.0
    }
    
    private func initializeSensorStatuses() {
        sensorStatuses = [
            .heartRate: SensorStatus(type: .heartRate, availability: .notAvailable, lastDataTime: nil, consecutiveMisses: 0),
            .heartRateVariability: SensorStatus(type: .heartRateVariability, availability: .notAvailable, lastDataTime: nil, consecutiveMisses: 0),
            .accelerometer: SensorStatus(type: .accelerometer, availability: .notAvailable, lastDataTime: nil, consecutiveMisses: 0),
            .gyroscope: SensorStatus(type: .gyroscope, availability: .notAvailable, lastDataTime: nil, consecutiveMisses: 0)
        ]
    }
    
    func checkAvailability() -> [SensorType: SensorAvailability] {
        var availabilities: [SensorType: SensorAvailability] = [:]
        
        let heartRateAvailable = HKHealthStore.isHealthDataAvailable() &&
        HKQuantityType.quantityType(forIdentifier: .heartRate) != nil
        
        availabilities[.heartRate] = heartRateAvailable ? .available : .notAvailable
        availabilities[.heartRateVariability] = heartRateAvailable ? .available : .notAvailable
        availabilities[.accelerometer] = motionManager.isAccelerometerAvailable ? .available : .notAvailable
        availabilities[.gyroscope] = motionManager.isGyroAvailable ? .available : .notAvailable
        
        return availabilities
    }
    
    func requestPermissions() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit not available")
            return false
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            return true
        } catch {
            print("HealthKit authorization failed: \(error)")
            return false
        }
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        degradedMode = false
        consecutiveHeartRateMisses = 0
        consecutiveMotionMisses = 0
        
        startHeartRateMonitoring()
        startMotionMonitoring()
        startDataCollectionTimer()
        
        print("Sensor monitoring started")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        
        stopHeartRateMonitoring()
        stopMotionMonitoring()
        stopDataCollectionTimer()
        
        dataBuffer.removeAll()
        print("Sensor monitoring stopped")
    }
    
    private func startHeartRateMonitoring() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate)
        
        let query = HKObserverQuery(sampleType: heartRateType, predicate: predicate) { [weak self] _, completionHandler, error in
            if let error = error {
                print("Heart rate observer error: \(error)")
                self?.handleSensorError(.heartRate, error: error)
            } else {
                self?.fetchLatestHeartRate()
            }
            completionHandler()
        }
        
        healthStore.execute(query)
        heartRateQuery = query
        
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { success, error in
            if let error = error {
                print("Background delivery setup failed: \(error)")
            } else {
                print("Background heart rate delivery enabled: \(success)")
            }
        }
        
        fetchLatestHeartRate()
    }
    
    private func stopHeartRateMonitoring() {
        if let query = heartRateQuery {
            healthStore.stop(query)
        }
        
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            healthStore.disableBackgroundDelivery(for: heartRateType) { _, _ in }
        }
    }
    
    private func fetchLatestHeartRate() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Heart rate fetch error: \(error)")
                    self?.handleSensorMiss(.heartRate)
                    return
                }
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    self?.handleSensorMiss(.heartRate)
                    return
                }
                
                let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
                let heartRate = sample.quantity.doubleValue(for: heartRateUnit)
                
                self?.currentHeartRate = heartRate
                self?.handleSensorSuccess(.heartRate)
                
                self?.fetchHeartRateVariability()
            }
        }
        
        healthStore.execute(query)
    }
    
    private func fetchHeartRateVariability() {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: hrvType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    let hrv = sample.quantity.doubleValue(for: .secondUnit(with: .milli))
                    self?.handleSensorSuccess(.heartRateVariability)
                    print("HRV: \(hrv) ms")
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    private func startMotionMonitoring() {
        let motionQueue = OperationQueue()
        motionQueue.name = "com.smartsleep.motion"
        
        if motionManager.isAccelerometerAvailable {
            motionManager.startAccelerometerUpdates(to: motionQueue) { [weak self] data, error in
                if let error = error {
                    print("Accelerometer error: \(error)")
                    self?.handleSensorError(.accelerometer, error: error)
                    return
                }
                
                guard let data = data else {
                    self?.handleSensorMiss(.accelerometer)
                    return
                }
                
                DispatchQueue.main.async {
                    self?.currentAcceleration = (data.acceleration.x, data.acceleration.y, data.acceleration.z)
                    self?.handleSensorSuccess(.accelerometer)
                }
            }
        }
        
        if motionManager.isGyroAvailable {
            motionManager.startGyroUpdates(to: motionQueue) { [weak self] data, error in
                if let error = error {
                    print("Gyroscope error: \(error)")
                    self?.handleSensorError(.gyroscope, error: error)
                    return
                }
                
                guard let data = data else {
                    self?.handleSensorMiss(.gyroscope)
                    return
                }
                
                DispatchQueue.main.async {
                    self?.handleSensorSuccess(.gyroscope)
                }
            }
        }
    }
    
    private func stopMotionMonitoring() {
        if motionManager.isAccelerometerActive {
            motionManager.stopAccelerometerUpdates()
        }
        if motionManager.isGyroActive {
            motionManager.stopGyroUpdates()
        }
    }
    
    private func startDataCollectionTimer() {
        dataCollectionTimer = Timer.scheduledTimer(withTimeInterval: collectionInterval, repeats: true) { [weak self] _ in
            self?.collectSensorData()
        }
        
        RunLoop.current.add(dataCollectionTimer!, forMode: .default)
    }
    
    private func stopDataCollectionTimer() {
        dataCollectionTimer?.invalidate()
        dataCollectionTimer = nil
    }
    
    private func collectSensorData() {
        let sensorData = SensorData(
            timestamp: Date(),
            heartRate: currentHeartRate,
            heartRateVariability: nil,
            accelerationX: currentAcceleration?.x,
            accelerationY: currentAcceleration?.y,
            accelerationZ: currentAcceleration?.z,
            rotationRateX: nil,
            rotationRateY: nil,
            rotationRateZ: nil
        )
        
        dataBuffer.append(sensorData)
        
        if dataBuffer.count > maxBufferSize {
            dataBuffer.removeFirst(dataBuffer.count - maxBufferSize)
        }
        
        onSensorData?(sensorData)
        
        checkDegradedMode()
    }
    
    private func handleSensorSuccess(_ type: SensorType) {
        consecutiveHeartRateMisses = type == .heartRate ? 0 : consecutiveHeartRateMisses
        consecutiveMotionMisses = (type == .accelerometer || type == .gyroscope) ? 0 : consecutiveMotionMisses
        
        sensorStatuses[type] = SensorStatus(
            type: type,
            availability: .available,
            lastDataTime: Date(),
            consecutiveMisses: 0
        )
        
        if degradedMode {
            onSensorRecovered?(type)
        }
    }
    
    private func handleSensorMiss(_ type: SensorType) {
        switch type {
        case .heartRate:
            consecutiveHeartRateMisses += 1
        case .accelerometer, .gyroscope:
            consecutiveMotionMisses += 1
        default:
            break
        }
        
        let currentMisses: Int
        switch type {
        case .heartRate:
            currentMisses = consecutiveHeartRateMisses
        case .accelerometer, .gyroscope:
            currentMisses = consecutiveMotionMisses
        default:
            currentMisses = 0
        }
        
        sensorStatuses[type] = SensorStatus(
            type: type,
            availability: currentMisses >= maxConsecutiveMisses ? .degraded : .available,
            lastDataTime: nil,
            consecutiveMisses: currentMisses
        )
    }
    
    private func handleSensorError(_ type: SensorType, error: Error) {
        sensorStatuses[type] = SensorStatus(
            type: type,
            availability: .notAvailable,
            lastDataTime: nil,
            consecutiveMisses: maxConsecutiveMisses
        )
        
        checkDegradedMode()
    }
    
    private func checkDegradedMode() {
        var degradedSensors: [SensorType] = []
        
        for (type, status) in sensorStatuses {
            if !status.isDataStale && status.availability.isUsable {
                continue
            }
            
            if status.consecutiveMisses >= maxConsecutiveMisses || status.isDataStale {
                degradedSensors.append(type)
            }
        }
        
        let wasDegraded = degradedMode
        degradedMode = !degradedSensors.isEmpty
        
        if degradedMode && !wasDegraded {
            onSensorDegraded?(degradedSensors)
            print("Entering degraded mode. Affected sensors: \(degradedSensors.map { $0.displayName })")
        }
    }
    
    func getRecentData(count: Int = 100) -> [SensorData] {
        return Array(dataBuffer.suffix(count))
    }
    
    func getAverageHeartRate(forLast minutes: Int = 5) -> Double? {
        let cutoff = Date().addingTimeInterval(-TimeInterval(minutes * 60))
        let recentData = dataBuffer.filter { $0.timestamp >= cutoff }
        
        let heartRates = recentData.compactMap { $0.heartRate }
        guard !heartRates.isEmpty else { return nil }
        
        return heartRates.reduce(0, +) / Double(heartRates.count)
    }
    
    func getMotionActivityLevel(forLast minutes: Int = 5) -> Double? {
        let cutoff = Date().addingTimeInterval(-TimeInterval(minutes * 60))
        let recentData = dataBuffer.filter { $0.timestamp >= cutoff }
        
        let magnitudes = recentData.compactMap { $0.accelerationMagnitude }
        guard !magnitudes.isEmpty else { return nil }
        
        return magnitudes.reduce(0, +) / Double(magnitudes.count)
    }
    
    func getDegradedSensorTypes() -> [SensorType] {
        return sensorStatuses.filter { !$0.value.availability.isUsable || $0.value.isDataStale }.map { $0.key }
    }
    
    func getAvailableSensorCount() -> Int {
        return sensorStatuses.filter { $0.value.availability == .available && !$0.value.isDataStale }.count
    }
}
