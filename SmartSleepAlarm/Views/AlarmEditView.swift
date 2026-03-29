import SwiftUI
import SwiftData

struct AlarmEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var time: Date
    @State private var repeatDays: Set<Int>
    @State private var selectedRingtone: String
    @State private var label: String
    @State private var isSmartModeEnabled: Bool
    @State private var snoozeInterval: Int
    @State private var snoozeGesture: SnoozeGesture
    
    private let alarm: Alarm?
    private let onSave: ((Alarm) -> Void)?
    
    private let weekDays = [
        (index: 0, name: "周日"),
        (index: 1, name: "周一"),
        (index: 2, name: "周二"),
        (index: 3, name: "周三"),
        (index: 4, name: "周四"),
        (index: 5, name: "周五"),
        (index: 6, name: "周六")
    ]
    
    init(alarm: Alarm? = nil, onSave: ((Alarm) -> Void)? = nil) {
        self.alarm = alarm
        self.onSave = onSave
        
        _time = State(initialValue: alarm?.time ?? Date())
        _repeatDays = State(initialValue: Set(alarm?.repeatDays ?? []))
        _selectedRingtone = State(initialValue: alarm?.ringtone ?? "default")
        _label = State(initialValue: alarm?.label ?? "")
        _isSmartModeEnabled = State(initialValue: alarm?.isSmartModeEnabled ?? false)
        _snoozeInterval = State(initialValue: alarm?.snoozeInterval ?? 5)
        _snoozeGesture = State(initialValue: alarm?.snoozeGesture ?? .snap)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                timeSection
                repeatSection
                ringtoneSection
                labelSection
                smartModeSection
                snoozeSection
            }
            .navigationTitle(alarm == nil ? "新建闹铃" : "编辑闹铃")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveAlarm()
                    }
                }
            }
        }
    }
    
    private var timeSection: some View {
        Section("时间") {
            DatePicker(
                "闹铃时间",
                selection: $time,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
        }
    }
    
    private var repeatSection: some View {
        Section("重复") {
            ForEach(weekDays, id: \.index) { day in
                HStack {
                    Text(day.name)
                    Spacer()
                    if repeatDays.contains(day.index) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleDay(day.index)
                }
            }
            
            HStack {
                Text("重复周期")
                Spacer()
                Text(repeatDescription)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var repeatDescription: String {
        if repeatDays.isEmpty {
            return "永不"
        } else if repeatDays.count == 7 {
            return "每天"
        } else if repeatDays == [1, 2, 3, 4, 5] {
            return "工作日"
        } else if repeatDays == [0, 6] {
            return "周末"
        } else {
            let dayNames = ["日", "一", "二", "三", "四", "五", "六"]
            return repeatDays.sorted().map { "周\(dayNames[$0])" }.joined(separator: "、")
        }
    }
    
    private var ringtoneSection: some View {
        Section("铃声") {
            Picker("选择铃声", selection: $selectedRingtone) {
                ForEach(Ringtone.systemRingtones) { ringtone in
                    Text(ringtone.name)
                        .tag(ringtone.id)
                }
            }
            .pickerStyle(.navigationLink)
            
            HStack {
                Text("当前铃声")
                Spacer()
                Text(Ringtone.name(for: selectedRingtone))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var labelSection: some View {
        Section("标签") {
            TextField("闹铃标签（可选）", text: $label)
                .textInputAutocapitalization(.sentences)
        }
    }
    
    private var smartModeSection: some View {
        Section {
            Toggle("智能模式", isOn: $isSmartModeEnabled)
            
            if isSmartModeEnabled {
                Text("智能模式将在最佳唤醒时间响起闹铃，帮助您更轻松地醒来")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } footer: {
            Text("智能模式会根据您的睡眠周期，在设定的闹铃时间前 30 分钟内的最佳时机唤醒您")
        }
    }
    
    private var snoozeSection: some View {
        Section("贪睡设置") {
            Stepper(
                "贪睡间隔: \(snoozeInterval) 分钟",
                value: $snoozeInterval,
                in: 1...30
            )
            
            Picker("贪睡手势", selection: $snoozeGesture) {
                ForEach(SnoozeGesture.allCases, id: \.self) { gesture in
                    HStack {
                        Image(systemName: gesture.icon)
                        Text(gesture.displayName)
                    }
                    .tag(gesture)
                }
            }
            
            HStack {
                Text("当前间隔")
                Spacer()
                Text("\(snoozeInterval) 分钟")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func toggleDay(_ index: Int) {
        withAnimation {
            if repeatDays.contains(index) {
                repeatDays.remove(index)
            } else {
                repeatDays.insert(index)
            }
        }
    }
    
    private func saveAlarm() {
        let alarmToSave: Alarm
        
        if let existingAlarm = alarm {
            existingAlarm.time = time
            existingAlarm.repeatDays = Array(repeatDays).sorted()
            existingAlarm.ringtone = selectedRingtone
            existingAlarm.label = label
            existingAlarm.isSmartModeEnabled = isSmartModeEnabled
            existingAlarm.snoozeInterval = snoozeInterval
            existingAlarm.snoozeGesture = snoozeGesture
            existingAlarm.updateTimestamp()
            alarmToSave = existingAlarm
        } else {
            let newAlarm = Alarm(
                time: time,
                repeatDays: Array(repeatDays).sorted(),
                ringtone: selectedRingtone,
                label: label,
                isSmartModeEnabled: isSmartModeEnabled,
                snoozeInterval: snoozeInterval,
                snoozeGesture: snoozeGesture
            )
            modelContext.insert(newAlarm)
            alarmToSave = newAlarm
        }
        
        do {
            try modelContext.save()
            onSave?(alarmToSave)
            dismiss()
        } catch {
            print("保存闹铃失败: \(error.localizedDescription)")
        }
    }
}

#Preview("新建闹铃") {
    AlarmEditView()
        .modelContainer(for: Alarm.self, inMemory: true)
}

#Preview("编辑闹铃") {
    let alarm = Alarm(
        time: Date(),
        repeatDays: [1, 2, 3, 4, 5],
        ringtone: "gentle_wake",
        label: "工作日闹铃",
        isSmartModeEnabled: true,
        snoozeInterval: 10
    )
    AlarmEditView(alarm: alarm)
        .modelContainer(for: Alarm.self, inMemory: true)
}
