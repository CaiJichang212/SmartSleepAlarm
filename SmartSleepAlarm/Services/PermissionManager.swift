import Foundation
import HealthKit
import UserNotifications
import UIKit

enum PermissionType {
    case healthKit
    case notification
    
    var title: String {
        switch self {
        case .healthKit:
            return "健康数据"
        case .notification:
            return "通知"
        }
    }
    
    var description: String {
        switch self {
        case .healthKit:
            return "访问您的睡眠数据，在最佳睡眠阶段唤醒您"
        case .notification:
            return "发送闹钟提醒和睡眠分析通知"
        }
    }
    
    var icon: String {
        switch self {
        case .healthKit:
            return "heart.fill"
        case .notification:
            return "bell.fill"
        }
    }
}

enum PermissionStatus {
    case notDetermined
    case denied
    case authorized
    case partiallyAuthorized
    
    var isGranted: Bool {
        switch self {
        case .authorized, .partiallyAuthorized:
            return true
        default:
            return false
        }
    }
}

@MainActor
class PermissionManager: ObservableObject {
    
    static let shared = PermissionManager()
    
    private let healthStore = HKHealthStore()
    
    @Published var healthKitStatus: PermissionStatus = .notDetermined
    @Published var notificationStatus: PermissionStatus = .notDetermined
    @Published var hasCompletedOnboarding: Bool = false
    
    private let hasCompletedOnboardingKey = "hasCompletedPermissionOnboarding"
    
    private var healthKitTypesToRead: Set<HKObjectType> {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let heartRateVariabilityType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        
        return [sleepType, heartRateType, heartRateVariabilityType]
    }
    
    private var healthKitTypesToWrite: Set<HKSampleType> {
        let sleepType = HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!
        return [sleepType]
    }
    
    private init() {
        loadOnboardingStatus()
        Task {
            await checkAllPermissions()
        }
    }
    
    private func loadOnboardingStatus() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
    }
    
    func markOnboardingCompleted() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: hasCompletedOnboardingKey)
    }
    
    func checkAllPermissions() async {
        await checkHealthKitPermission()
        await checkNotificationPermission()
    }
    
    func checkHealthKitPermission() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            healthKitStatus = .denied
            return
        }
        
        var allAuthorized = true
        var someAuthorized = false
        
        for type in healthKitTypesToRead {
            let status = healthStore.authorizationStatus(for: type)
            switch status {
            case .sharingAuthorized:
                someAuthorized = true
            case .sharingDenied:
                allAuthorized = false
            case .notDetermined:
                allAuthorized = false
            @unknown default:
                allAuthorized = false
            }
        }
        
        if allAuthorized && someAuthorized {
            healthKitStatus = .authorized
        } else if someAuthorized {
            healthKitStatus = .partiallyAuthorized
        } else if !someAuthorized && !allAuthorized {
            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            if healthStore.authorizationStatus(for: sleepType) == .notDetermined {
                healthKitStatus = .notDetermined
            } else {
                healthKitStatus = .denied
            }
        } else {
            healthKitStatus = .notDetermined
        }
    }
    
    func checkNotificationPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        
        switch settings.authorizationStatus {
        case .authorized:
            notificationStatus = .authorized
        case .denied:
            notificationStatus = .denied
        case .notDetermined:
            notificationStatus = .notDetermined
        case .provisional:
            notificationStatus = .partiallyAuthorized
        case .ephemeral:
            notificationStatus = .partiallyAuthorized
        @unknown default:
            notificationStatus = .notDetermined
        }
    }
    
    func requestHealthKitPermission() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            healthKitStatus = .denied
            return false
        }
        
        do {
            try await healthStore.requestAuthorization(
                toShare: healthKitTypesToWrite,
                read: healthKitTypesToRead
            )
            await checkHealthKitPermission()
            return healthKitStatus.isGranted
        } catch {
            print("HealthKit authorization error: \(error.localizedDescription)")
            healthKitStatus = .denied
            return false
        }
    }
    
    func requestNotificationPermission() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge, .criticalAlert]
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
            
            await checkNotificationPermission()
            return granted
        } catch {
            print("Notification authorization error: \(error.localizedDescription)")
            notificationStatus = .denied
            return false
        }
    }
    
    func requestAllPermissions() async -> (healthKit: Bool, notification: Bool) {
        async let healthKitGranted = requestHealthKitPermission()
        async let notificationGranted = requestNotificationPermission()
        
        let results = await (healthKitGranted, notificationGranted)
        return results
    }
    
    var allPermissionsGranted: Bool {
        return healthKitStatus.isGranted && notificationStatus.isGranted
    }
    
    var shouldShowPermissionReminder: Bool {
        return hasCompletedOnboarding && !allPermissionsGranted
    }
    
    func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    func resetOnboardingForTesting() {
        hasCompletedOnboarding = false
        UserDefaults.standard.removeObject(forKey: hasCompletedOnboardingKey)
    }
}
