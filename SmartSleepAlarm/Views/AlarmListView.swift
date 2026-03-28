import SwiftUI
import SwiftData

struct AlarmListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Alarm.time, order: .forward) private var alarms: [Alarm]
    @State private var showingAddAlarm = false
    @State private var selectedAlarm: Alarm?
    
    var body: some View {
        NavigationStack {
            Group {
                if alarms.isEmpty {
                    emptyStateView
                } else {
                    alarmListView
                }
            }
            .navigationTitle("闹铃")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddAlarm = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
            .sheet(isPresented: $showingAddAlarm) {
                AlarmEditView(alarm: nil) { newAlarm in
                    modelContext.insert(newAlarm)
                }
            }
            .sheet(item: $selectedAlarm) { alarm in
                AlarmEditView(alarm: alarm) { updatedAlarm in
                    alarm.time = updatedAlarm.time
                    alarm.repeatDays = updatedAlarm.repeatDays
                    alarm.label = updatedAlarm.label
                    alarm.ringtone = updatedAlarm.ringtone
                    alarm.isSmartModeEnabled = updatedAlarm.isSmartModeEnabled
                    alarm.snoozeInterval = updatedAlarm.snoozeInterval
                    alarm.snoozeGesture = updatedAlarm.snoozeGesture
                    alarm.updateTimestamp()
                }
            }
        }
    }
    
    private var alarmListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(alarms) { alarm in
                    AlarmCardView(
                        alarm: alarm,
                        onToggle: { isEnabled in
                            alarm.isEnabled = isEnabled
                            alarm.updateTimestamp()
                        },
                        onTap: {
                            selectedAlarm = alarm
                        }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        deleteButton(for: alarm)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .refreshable {
            await Task.yield()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "alarm")
                .font(.system(size: 70))
                .foregroundStyle(.secondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("暂无闹铃")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("点击右上角 + 添加你的第一个闹铃")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func deleteButton(for alarm: Alarm) -> some View {
        Button(role: .destructive) {
            withAnimation {
                modelContext.delete(alarm)
            }
        } label: {
            Label("删除", systemImage: "trash")
        }
    }
}

struct AlarmEditView: View {
    let alarm: Alarm?
    let onSave: (Alarm) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var time: Date
    @State private var label: String
    @State private var repeatDays: [Int]
    @State private var isSmartModeEnabled: Bool
    @State private var ringtone: String
    @State private var snoozeInterval: Int
    @State private var snoozeGesture: SnoozeGesture
    
    private let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    
    init(alarm: Alarm?, onSave: @escaping (Alarm) -> Void) {
        self.alarm = alarm
        self.onSave = onSave
        
        _time = State(initialValue: alarm?.time ?? Date())
        _label = State(initialValue: alarm?.label ?? "")
        _repeatDays = State(initialValue: alarm?.repeatDays ?? [])
        _isSmartModeEnabled = State(initialValue: alarm?.isSmartModeEnabled ?? false)
        _ringtone = State(initialValue: alarm?.ringtone ?? "default")
        _snoozeInterval = State(initialValue: alarm?.snoozeInterval ?? 5)
        _snoozeGesture = State(initialValue: alarm?.snoozeGesture ?? .snap)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("时间") {
                    DatePicker(
                        "",
                        selection: $time,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                }
                
                Section("标签") {
                    TextField("闹铃标签（可选）", text: $label)
                }
                
                Section("重复") {
                    ForEach(0..<7, id: \.self) { index in
                        Button(action: {
                            if repeatDays.contains(index) {
                                repeatDays.removeAll { $0 == index }
                            } else {
                                repeatDays.append(index)
                                repeatDays.sort()
                            }
                        }) {
                            HStack {
                                Text(weekdays[index])
                                    .foregroundStyle(.primary)
                                Spacer()
                                if repeatDays.contains(index) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Toggle("智能模式", isOn: $isSmartModeEnabled)
                    
                    if isSmartModeEnabled {
                        Text("启用智能模式后，闹铃会在设定的睡眠周期结束时自动唤醒你")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("贪睡设置") {
                    Picker("贪睡间隔", selection: $snoozeInterval) {
                        ForEach([1, 3, 5, 10, 15, 20, 30], id: \.self) { minutes in
                            Text("\(minutes) 分钟").tag(minutes)
                        }
                    }
                    
                    Picker("贪睡手势", selection: $snoozeGesture) {
                        ForEach(SnoozeGesture.allCases, id: \.self) { gesture in
                            HStack {
                                Image(systemName: gesture.icon)
                                Text(gesture.displayName)
                            }
                            .tag(gesture)
                        }
                    }
                }
                
                Section("铃声") {
                    Picker("铃声", selection: $ringtone) {
                        ForEach(Array(Alarm.defaultRingtones.keys.sorted()), id: \.self) { key in
                            Text(Alarm.defaultRingtones[key] ?? key).tag(key)
                        }
                    }
                }
            }
            .navigationTitle(alarm == nil ? "新建闹铃" : "编辑闹铃")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        let newAlarm = Alarm(
                            time: time,
                            repeatDays: repeatDays,
                            ringtone: ringtone,
                            label: label,
                            isEnabled: alarm?.isEnabled ?? true,
                            isSmartModeEnabled: isSmartModeEnabled,
                            snoozeInterval: snoozeInterval,
                            snoozeGesture: snoozeGesture
                        )
                        onSave(newAlarm)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Alarm.self, configurations: config)
    
    let alarm1 = Alarm(
        time: Date(),
        repeatDays: [1, 2, 3, 4, 5],
        label: "工作日起床",
        isEnabled: true,
        isSmartModeEnabled: true
    )
    
    container.mainContext.insert(alarm1)
    
    return AlarmListView()
        .modelContainer(container)
}
