import Foundation

enum SleepState: Equatable {
    case awake
    case detecting
    // case potentialSleep // Optional
    case asleep
    case disturbed
    case finished // Added state
    case error(String)

    // Conformance to CustomStringConvertible
    var description: String {
        switch self {
        case .awake: return "清醒"
        case .detecting: return "偵測中"
        case .asleep: return "睡眠中"
        case .disturbed: return "被干擾"
        case .finished: return "完成"
        case .error(let message): return "錯誤: \(message)"
        }
    }
} 