import Foundation

struct Ringtone: Identifiable, Hashable {
    let id: String
    let name: String
    let fileName: String?
    
    init(id: String, name: String, fileName: String? = nil) {
        self.id = id
        self.name = name
        self.fileName = fileName
    }
}

extension Ringtone {
    static let systemRingtones: [Ringtone] = [
        Ringtone(id: "default", name: "默认铃声"),
        Ringtone(id: "gentle_wake", name: "轻柔唤醒"),
        Ringtone(id: "morning_breeze", name: "晨风"),
        Ringtone(id: "sunrise", name: "日出"),
        Ringtone(id: "birds_chirping", name: "鸟鸣"),
        Ringtone(id: "ocean_waves", name: "海浪"),
        Ringtone(id: "forest_stream", name: "林间溪流"),
        Ringtone(id: "classic_alarm", name: "经典闹铃"),
        Ringtone(id: "digital_beep", name: "电子蜂鸣"),
        Ringtone(id: "piano_melody", name: "钢琴旋律"),
        Ringtone(id: "guitar_strum", name: "吉他弹奏"),
        Ringtone(id: "wind_chimes", name: "风铃"),
        Ringtone(id: "temple_bell", name: "寺庙钟声"),
        Ringtone(id: "crystal_clear", name: "清脆水晶"),
        Ringtone(id: "soft_chime", name: "柔和铃声")
    ]
    
    static func name(for id: String) -> String {
        systemRingtones.first { $0.id == id }?.name ?? "默认铃声"
    }
}
