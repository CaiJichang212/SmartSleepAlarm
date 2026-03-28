import SwiftUI

struct WatchContentView: View {
    @StateObject private var monitorManager = SleepMonitorManager.shared
    @StateObject private var sensorService = SensorService.shared
    @StateObject private var alarmManager = WatchAlarmManager.shared
    @StateObject private var alarmPlayer = AlarmPlayer.shared
    @StateObject private var gestureService = GestureDetectionService.shared
    
    @State private var showingAlarmSheet = false
    @State private var showingSnoozeConfirmation = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    alarmStatusCard
                    
                    if alarmManager.alarmState.isAlarmActive {
                        alarmControls
                    } else {
                        monitoringControls
                    }
                    
                    sensorStatusView
                }
                .padding()
            }
            .navigationTitle("SmartSleep")
            .sheet(isPresented: $showingAlarmSheet) {
                AlarmActiveSheet(
                    alarmManager: alarmManager,
                    alarmPlayer: alarmPlayer,
                    onDismiss: { dismissAlarm() },
                    onSnooze: { snoozeAlarm() }
                )
            }
        }
        .onAppear {
            setupAlarmCallbacks()
            setupGestureCallbacks()
        }
        .onChange(of: alarmManager.alarmState) { _, newState in
            handleAlarmStateChange(newState)
        }
    }
    
    private var alarmStatusCard: some View {
        VStack(spacing: 8) {
            Image(systemName: alarmStatusIcon)
                .imageScale(.large)
                .foregroundStyle(alarmStatusColor)
                .font(.system(size: 32))
            
            Text(alarmManager.alarmState.displayName)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            if let alarm = alarmManager.currentAlarm {
                Text(alarm.formattedTime)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                if !alarm.label.isEmpty {
                    Text(alarm.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if alarmPlayer.isPlaying() {
                VStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("音量: \(Int(alarmPlayer.currentVolume * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            if case .snoozed(_, _, let count) = alarmManager.alarmState {
                Text("贪睡次数: \(count)/\(alarmManager.maxSnoozeCount)")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var alarmControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button(action: dismissAlarm) {
                    VStack {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                        Text("关闭")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
                if alarmManager.canSnooze() {
                    Button(action: snoozeAlarm) {
                        VStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.title)
                            Text("贪睡")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
            }
            
            if let gesture = alarmManager.currentAlarm?.snoozeGesture {
                Text(gesture.instruction)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var monitoringControls: some View {
        HStack(spacing: 12) {
            Button(action: startMonitoring) {
                Image(systemName: "play.fill")
                    .font(.title2)
            }
            .buttonStyle(.borderedProminent)
            .disabled(monitorManager.monitorState.isMonitoring)
            
            Button(action: stopMonitoring) {
                Image(systemName: "stop.fill")
                    .font(.title2)
            }
            .buttonStyle(.bordered)
            .disabled(!monitorManager.monitorState.isMonitoring)
            
            Button(action: testAlarm) {
                Image(systemName: "bell.fill")
                    .font(.title2)
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var sensorStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("传感器状态")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ForEach(SensorType.allCases, id: \.self) { type in
                HStack {
                    Image(systemName: sensorIcon(for: type))
                        .foregroundStyle(sensorColor(for: type))
                    
                    Text(type.displayName)
                        .font(.caption2)
                    
                    Spacer()
                    
                    Circle()
                        .fill(sensorColor(for: type))
                        .frame(width: 8, height: 8)
                }
            }
            
            if gestureService.isMonitoring {
                Divider()
                
                HStack {
                    Image(systemName: "hand.tap")
                        .foregroundStyle(.blue)
                    
                    Text("手势监测中")
                        .font(.caption2)
                    
                    Spacer()
                    
                    Text("\(gestureService.gestureCount) 次检测")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var alarmStatusIcon: String {
        switch alarmManager.alarmState {
        case .idle: return "moon.zzz"
        case .scheduled: return "clock"
        case .triggered: return "bell.badge.fill"
        case .snoozed: return "clock.arrow.circlepath"
        case .dismissed: return "bell.slash"
        }
    }
    
    private var alarmStatusColor: Color {
        switch alarmManager.alarmState {
        case .idle: return .gray
        case .scheduled: return .blue
        case .triggered: return .red
        case .snoozed: return .orange
        case .dismissed: return .green
        }
    }
    
    private func sensorIcon(for type: SensorType) -> String {
        switch type {
        case .heartRate: return "heart.fill"
        case .heartRateVariability: return "waveform"
        case .accelerometer: return "move.3d"
        case .gyroscope: return "rotate.3d"
        }
    }
    
    private func sensorColor(for type: SensorType) -> Color {
        guard let status = sensorService.sensorStatuses[type] else {
            return .gray
        }
        
        if status.isDataStale {
            return .orange
        }
        
        switch status.availability {
        case .available: return .green
        case .degraded: return .orange
        case .notAvailable: return .red
        case .permissionDenied: return .red
        }
    }
    
    private func setupAlarmCallbacks() {
        alarmManager.onAlarmTriggered = { info in
            print("Alarm triggered callback: \(info)")
            showingAlarmSheet = true
            
            if let gesture = alarmManager.currentAlarm?.snoozeGesture {
                gestureService.startMonitoringForSnooze(gesture: gesture)
            }
        }
        
        alarmManager.onAlarmDismissed = { _ in
            showingAlarmSheet = false
            gestureService.stopMonitoring()
        }
        
        alarmManager.onWakefulnessDetected = {
            print("Wakefulness detected during alarm")
        }
    }
    
    private func setupGestureCallbacks() {
        gestureService.onSnapDetected = {
            print("Snap gesture detected - triggering snooze")
        }
        
        gestureService.onWristFlipDetected = {
            print("Wrist flip gesture detected - triggering snooze")
        }
    }
    
    private func handleAlarmStateChange(_ state: AlarmState) {
        switch state {
        case .triggered:
            showingAlarmSheet = true
        case .idle, .dismissed:
            showingAlarmSheet = false
            gestureService.stopMonitoring()
        default:
            break
        }
    }
    
    private func startMonitoring() {
        let testAlarmTime = Date().addingTimeInterval(30 * 60)
        monitorManager.scheduleMonitoring(for: testAlarmTime)
        
        let testAlarm = Alarm(
            time: testAlarmTime,
            ringtone: "default",
            label: "测试闹铃",
            isSmartModeEnabled: true,
            snoozeInterval: 1
        )
        alarmManager.scheduleAlarm(testAlarm)
    }
    
    private func stopMonitoring() {
        monitorManager.stopMonitoring()
        alarmManager.reset()
    }
    
    private func testAlarm() {
        alarmManager.triggerTestAlarm()
    }
    
    private func dismissAlarm() {
        alarmManager.dismissAlarm()
        showingAlarmSheet = false
    }
    
    private func snoozeAlarm() {
        if alarmManager.canSnooze() {
            alarmManager.snoozeAlarm()
        }
    }
}

struct AlarmActiveSheet: View {
    @ObservedObject var alarmManager: WatchAlarmManager
    @ObservedObject var alarmPlayer: AlarmPlayer
    
    let onDismiss: () -> Void
    let onSnooze: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
                .symbolEffect(.pulse)
            
            Text("闹铃中")
                .font(.title2)
                .fontWeight(.bold)
            
            if let alarm = alarmManager.currentAlarm {
                Text(alarm.formattedTime)
                    .font(.title)
                    .fontWeight(.semibold)
                
                if !alarm.label.isEmpty {
                    Text(alarm.label)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let info = alarmManager.lastTriggerInfo, info.isSmartWake {
                Label("智能唤醒", systemImage: "brain.head.profile")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            VStack(spacing: 12) {
                Button(action: onDismiss) {
                    Label("关闭闹铃", systemImage: "xmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
                if alarmManager.canSnooze() {
                    Button(action: onSnooze) {
                        VStack {
                            Label("贪睡", systemImage: "clock.arrow.circlepath")
                                .font(.subheadline)
                            Text("剩余 \(alarmManager.getRemainingSnoozeCount()) 次")
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
            }
            
            if let gesture = alarmManager.currentAlarm?.snoozeGesture {
                VStack(spacing: 4) {
                    Image(systemName: gesture.icon)
                        .font(.title3)
                        .foregroundStyle(.blue)
                    
                    Text(gesture.instruction)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
    }
}

extension SensorType: CaseIterable {
    static var allCases: [SensorType] {
        return [.heartRate, .heartRateVariability, .accelerometer, .gyroscope]
    }
}

#Preview {
    WatchContentView()
}

#Preview("Alarm Active") {
    let alarmManager = WatchAlarmManager.shared
    let testAlarm = Alarm(time: Date(), ringtone: "default", label: "测试闹铃")
    alarmManager.scheduleAlarm(testAlarm)
    
    return WatchContentView()
}
