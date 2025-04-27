import Foundation

/// 表示 App 的主要狀態
enum NapState: Equatable, CustomStringConvertible {
    case idle         // App is ready, waiting for user to start
    case detecting    // Services running, trying to detect sleep onset
    case napping      // Sleep detected, countdown timer is running
    case paused       // Countdown timer paused (optional feature)
    case finished     // Nap completed normally (timer finished)
    case error(String) // An error occurred, store the message
    
    // CustomStringConvertible conformance
    var description: String {
        switch self {
        case .idle: return "待機"
        case .detecting: return "偵測中"
        case .napping: return "小睡中"
        case .paused: return "已暫停"
        case .finished: return "已完成"
        case .error(let message): return "錯誤: \(message)" // Display the specific error
        }
    }

    // Manually implement Equatable because of the associated value in .error
    static func == (lhs: NapState, rhs: NapState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.detecting, .detecting),
             (.napping, .napping),
             (.paused, .paused),
             (.finished, .finished):
            return true
        case (.error(let lMsg), .error(let rMsg)):
            return lMsg == rMsg // Compare associated values for error
        default:
            return false // All other combinations are not equal
        }
    }
}