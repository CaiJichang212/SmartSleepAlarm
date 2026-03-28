import SwiftUI

@main
struct SmartSleepAlarmApp: App {
    
    @StateObject private var permissionManager = PermissionManager.shared
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    
    var body: some Scene {
        WindowGroup {
            if permissionManager.hasCompletedOnboarding {
                ContentView()
                    .environmentObject(permissionManager)
                    .environmentObject(watchConnectivity)
            } else {
                PermissionOnboardingView(onComplete: {
                    permissionManager.markOnboardingCompleted()
                })
            }
        }
    }
}
