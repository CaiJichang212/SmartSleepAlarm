import SwiftUI
import SwiftData

struct AlarmCardView: View {
    let alarm: Alarm
    let onToggle: (Bool) -> Void
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(formattedTime)
                            .font(.system(size: 42, weight: .light, design: .rounded))
                            .foregroundStyle(alarm.isEnabled ? .primary : .secondary)
                        
                        if alarm.isSmartModeEnabled {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 16))
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    if !alarm.label.isEmpty {
                        Text(alarm.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        Text(alarm.repeatDaysDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if alarm.isSmartModeEnabled {
                            HStack(spacing: 2) {
                                Image(systemName: "moon.zzz")
                                    .font(.caption2)
                                Text("智能")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                    
                    if alarm.isEnabled, let timeUntil = alarm.timeUntilFire {
                        Text(timeUntil)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { alarm.isEnabled },
                    set: { onToggle($0) }
                ))
                .labelsHidden()
                .tint(.green)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(alarm.isEnabled ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: alarm.time)
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
    
    let alarm2 = Alarm(
        time: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
        repeatDays: [],
        label: "午休提醒",
        isEnabled: false,
        isSmartModeEnabled: false
    )
    
    return VStack(spacing: 16) {
        AlarmCardView(alarm: alarm1, onToggle: { _ in }, onTap: {})
        AlarmCardView(alarm: alarm2, onToggle: { _ in }, onTap: {})
    }
    .padding()
    .modelContainer(container)
}
