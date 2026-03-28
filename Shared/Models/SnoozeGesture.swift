import Foundation

enum SnoozeGesture: String, Codable, CaseIterable {
    case snap = "打响指"
    case wristFlip = "手腕翻转"
    
    var displayName: String {
        rawValue
    }
    
    var icon: String {
        switch self {
        case .snap: return "hand.tap"
        case .wristFlip: return "hand.raised"
        }
    }
    
    var instruction: String {
        switch self {
        case .snap: return "打响指以贪睡"
        case .wristFlip: return "翻转手腕以贪睡"
        }
    }
}
