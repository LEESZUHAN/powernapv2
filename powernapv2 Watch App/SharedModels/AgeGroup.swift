import Foundation

// 遵循 PowerNapXcodeDebugGuide.md 的最佳實踐，定義共享的 AgeGroup
// 確保訪問控制允許其他文件訪問 (internal 或 public)
public enum AgeGroup: String, CaseIterable, Codable, Identifiable {
    case teen = "青少年 (10-17歲)"
    case adult = "成人 (18-59歲)"
    case senior = "銀髮族 (60歲以上)"
    
    public var id: String { self.rawValue }
    
    // MARK: - Algorithmic Parameters
    
    /// Based on HeartRateAlgorithmGuideline.md & SleepDetectionGuideline.md
    public var heartRateThresholdPercentage: Double {
        switch self {
        case .teen: return 0.875 // Midpoint of 85-90%
        case .adult: return 0.90  // 90%
        case .senior: return 0.935 // Midpoint of 92-95%
        }
    }
    
    /// Based on SleepDetectionGuideline.md (sleepConfirmationTime)
    public var minDurationForSleepDetection: TimeInterval {
        switch self {
        case .teen: return 120 // 2 minutes
        case .adult: return 180 // 3 minutes
        case .senior: return 240 // 4 minutes
        }
    }
    
    // MARK: - Static Methods
    
    /// Determines the AgeGroup based on the provided age.
    /// Note: Returns .adult if age is outside the defined ranges (e.g., < 10).
    public static func forAge(_ age: Int) -> AgeGroup {
        switch age {
        case 10...17: return .teen
        case 18...59: return .adult
        case 60...: return .senior
        default:
            print("Warning: Age \(age) is outside defined ranges. Defaulting to Adult.")
            return .adult // Default case
        }
    }
} 