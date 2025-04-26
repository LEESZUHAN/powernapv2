import Foundation

/// 表示 App 的主要狀態
enum NapState: Equatable {
    case idle // 閒置，等待開始
    case detecting // 正在監測，等待入睡
    case napping // 已入睡，正在倒數計時
    case paused // 已暫停 (未來可能加入)
    case finished // 小睡完成
    case error(String) // 發生錯誤
}

/// 表示睡眠偵測的內部狀態
enum SleepState: Equatable {
    case awake         // 清醒
    case detecting     // 監測中，尚未滿足入睡條件
    case asleep        // 已入睡
    case disturbed     // 睡眠被打斷 (例如大幅度移動)
    case finished      // 小睡完成 (計時結束)
    case error(String) // 發生錯誤
} 