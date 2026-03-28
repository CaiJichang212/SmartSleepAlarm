import SwiftUI

struct PermissionOnboardingView: View {
    
    @StateObject private var permissionManager = PermissionManager.shared
    @State private var isRequestingPermissions = false
    @State private var showSettingsAlert = false
    @State private var currentPermissionIndex = 0
    
    let onComplete: () -> Void
    
    private var permissions: [PermissionType] {
        [.healthKit, .notification]
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        headerView
                        
                        permissionCardsView
                        
                        actionButtonsView
                        
                        Spacer(minLength: 20)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("需要权限", isPresented: $showSettingsAlert) {
                Button("取消", role: .cancel) { }
                Button("前往设置") {
                    permissionManager.openSystemSettings()
                }
            } message: {
                Text("某些权限被拒绝，请在系统设置中开启以获得完整功能体验")
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 70))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, 40)
            
            Text("欢迎使用 SmartSleep Alarm")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("为了提供最佳的智能闹钟体验，我们需要以下权限")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }
    
    private var permissionCardsView: some View {
        VStack(spacing: 16) {
            ForEach(permissions.indices, id: \.self) { index in
                PermissionCardView(
                    permissionType: permissions[index],
                    status: statusForPermission(permissions[index]),
                    onRequestPermission: {
                        Task {
                            await requestPermission(permissions[index])
                        }
                    }
                )
            }
        }
        .padding(.horizontal)
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 16) {
            if permissionManager.allPermissionsGranted {
                Button(action: {
                    permissionManager.markOnboardingCompleted()
                    onComplete()
                }) {
                    Text("开始使用")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(15)
                }
                .padding(.horizontal)
            } else if isRequestingPermissions {
                ProgressView("正在请求权限...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .foregroundColor(.white)
            } else {
                Button(action: {
                    Task {
                        await requestAllPermissions()
                    }
                }) {
                    Text("授权所有权限")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(15)
                }
                .padding(.horizontal)
                
                Button(action: {
                    permissionManager.markOnboardingCompleted()
                    onComplete()
                }) {
                    Text("稍后设置")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.top, 20)
    }
    
    private func statusForPermission(_ type: PermissionType) -> PermissionStatus {
        switch type {
        case .healthKit:
            return permissionManager.healthKitStatus
        case .notification:
            return permissionManager.notificationStatus
        }
    }
    
    private func requestPermission(_ type: PermissionType) async {
        isRequestingPermissions = true
        
        switch type {
        case .healthKit:
            let granted = await permissionManager.requestHealthKitPermission()
            if !granted && permissionManager.healthKitStatus == .denied {
                showSettingsAlert = true
            }
        case .notification:
            let granted = await permissionManager.requestNotificationPermission()
            if !granted && permissionManager.notificationStatus == .denied {
                showSettingsAlert = true
            }
        }
        
        isRequestingPermissions = false
    }
    
    private func requestAllPermissions() async {
        isRequestingPermissions = true
        
        let results = await permissionManager.requestAllPermissions()
        
        if !results.healthKit && permissionManager.healthKitStatus == .denied {
            showSettingsAlert = true
        }
        
        if !results.notification && permissionManager.notificationStatus == .denied {
            showSettingsAlert = true
        }
        
        isRequestingPermissions = false
    }
}

struct PermissionCardView: View {
    
    let permissionType: PermissionType
    let status: PermissionStatus
    let onRequestPermission: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusBackgroundColor)
                    .frame(width: 50, height: 50)
                
                Image(systemName: permissionType.icon)
                    .font(.title2)
                    .foregroundColor(statusIconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(permissionType.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    statusBadge
                }
                
                Text(permissionType.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            
            if status == .notDetermined {
                Button(action: onRequestPermission) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }
    
    private var statusBackgroundColor: Color {
        switch status {
        case .authorized:
            return .green.opacity(0.2)
        case .denied:
            return .red.opacity(0.2)
        case .partiallyAuthorized:
            return .orange.opacity(0.2)
        case .notDetermined:
            return .gray.opacity(0.2)
        }
    }
    
    private var statusIconColor: Color {
        switch status {
        case .authorized:
            return .green
        case .denied:
            return .red
        case .partiallyAuthorized:
            return .orange
        case .notDetermined:
            return .gray
        }
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .authorized:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text("已授权")
            }
            .font(.caption)
            .foregroundColor(.green)
        case .denied:
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                Text("已拒绝")
            }
            .font(.caption)
            .foregroundColor(.red)
        case .partiallyAuthorized:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("部分授权")
            }
            .font(.caption)
            .foregroundColor(.orange)
        case .notDetermined:
            HStack(spacing: 4) {
                Image(systemName: "questionmark.circle")
                Text("未设置")
            }
            .font(.caption)
            .foregroundColor(.gray)
        }
    }
}

struct PermissionReminderView: View {
    
    @StateObject private var permissionManager = PermissionManager.shared
    @State private var showSettingsAlert = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text("部分功能受限")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            Text("某些权限未授权，可能影响应用的完整功能")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            HStack(spacing: 12) {
                if !permissionManager.healthKitStatus.isGranted {
                    permissionChip(type: .healthKit)
                }
                
                if !permissionManager.notificationStatus.isGranted {
                    permissionChip(type: .notification)
                }
            }
            
            Button(action: {
                showSettingsAlert = true
            }) {
                Text("前往设置")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .alert("权限设置", isPresented: $showSettingsAlert) {
            Button("取消", role: .cancel) { }
            Button("前往设置") {
                permissionManager.openSystemSettings()
            }
        } message: {
            Text("请在系统设置中开启所需权限")
        }
    }
    
    private func permissionChip(type: PermissionType) -> some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.caption)
            Text(type.title)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.2))
        .cornerRadius(8)
        .foregroundColor(.orange)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview("Permission Onboarding") {
    PermissionOnboardingView(onComplete: {})
}

#Preview("Permission Reminder") {
    ZStack {
        Color.black.ignoresSafeArea()
        PermissionReminderView()
    }
}
