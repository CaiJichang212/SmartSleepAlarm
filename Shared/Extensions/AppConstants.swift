import Foundation

enum AppConstants {
    static let appGroupIdentifier = "group.com.smartsleep.alarm"
    static let bundleIdentifier = "com.smartsleep.alarm"
    static let watchBundleIdentifier = "com.smartsleep.alarm.watchkitapp"
    
    static let healthKitTypesToRead: Set = [
        "HKCategoryTypeIdentifierSleepAnalysis",
        "HKQuantityTypeIdentifierHeartRate",
        "HKQuantityTypeIdentifierRespiratoryRate",
        "HKQuantityTypeIdentifierBodyTemperature"
    ]
}

extension Notification.Name {
    static let alarmDidTriggerOnWatch = Notification.Name("alarmDidTriggerOnWatch")
    static let alarmDidDismissOnWatch = Notification.Name("alarmDidDismissOnWatch")
    static let alarmDidSnoozeOnWatch = Notification.Name("alarmDidSnoozeOnWatch")
    static let watchConnectivityDidChange = Notification.Name("watchConnectivityDidChange")
}
