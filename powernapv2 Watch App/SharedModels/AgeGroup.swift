import Foundation

// 遵循 PowerNapXcodeDebugGuide.md 的最佳實踐，定義共享的 AgeGroup
public enum AgeGroup: String, CaseIterable, Codable, Identifiable {
    case teen = "青少年 (10-17歲)"
    case adult = "成人 (18-59歲)"
    case senior = "銀髮族 (60歲以上)"
    
    public var id: String { self.rawValue }
    
    // 根據 HeartRateAlgorithmGuideline.md 的參考值
    // 實際計算邏輯將在後續階段實現
    public var heartRateThresholdPercentage: Double {
        switch self {
        case .teen: return 0.875 // 85-90% 的中間值
        case .adult: return 0.9   // 90%
        case .senior: return 0.935 // 92-95% 的中間值
        }
    }
    
    // 根據 HeartRateAlgorithmGuideline.md 的參考值
    // 實際計算邏輯將在後續階段實現
    public var minDurationForSleepDetection: TimeInterval {
        switch self {
        case .teen: return 120 // 2 分鐘
        case .adult: return 180 // 3 分鐘
        case .senior: return 240 // 4 分鐘
        }
    }
    
    // 根據用戶實際年齡返回對應的 AgeGroup
    // 實際計算邏輯將在後續階段實現 (可能移至 AgeGroupService)
    public static func forAge(_ age: Int) -> AgeGroup {
        switch age {
        case 10...17:
            return .teen
        case 18...59:
            return .adult
        case 60...: // 60歲及以上
            return .senior
        default:
            // 預設情況或年齡範圍外，可以返回成人或拋出錯誤，這裡暫定返回成人
            print("警告：年齡 \(age) 不在預期範圍內，將使用預設成人組別。")
            return .adult
        }
    }
} 