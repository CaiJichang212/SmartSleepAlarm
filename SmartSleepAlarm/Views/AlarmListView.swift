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
                AlarmEditView()
            }
            .sheet(item: $selectedAlarm) { alarm in
                AlarmEditView(alarm: alarm)
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
