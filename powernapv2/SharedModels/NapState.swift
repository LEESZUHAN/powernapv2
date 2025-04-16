import Foundation

/// 表示 App 的主要狀態
enum NapState {
    case idle // 閒置，等待開始
    case detecting // 正在監測，等待入睡
    case napping // 已入睡，正在倒數計時
    case paused // 已暫停 (未來可能加入)
    case finished // 小睡完成
    case error(String) // 發生錯誤
}

/// 表示睡眠偵測的內部狀態 (第二階段會用到)
enum SleepState {
    case awake // 清醒
    case potentialSleep // 可能入睡 (心率或活動條件之一滿足)
    case asleep // 確認入睡 (兩條件都滿足且持續達標)
    case disturbed // 睡眠被干擾 (例如突然的大幅活動)
} 