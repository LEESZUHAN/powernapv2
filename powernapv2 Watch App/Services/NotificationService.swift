import Foundation
import UserNotifications
import Combine
import WatchKit // For WKHapticType

class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // 用於發布權限狀態
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        // 將自身設置為通知中心的代理，以便處理通知的顯示和交互 (如果需要在 App 運行時處理)
        notificationCenter.delegate = self
        checkAuthorizationStatus() // 在初始化時檢查當前狀態
        print("NotificationService 初始化完成。")
    }
    
    // --- 權限管理 ---
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            print("通知權限請求完成，結果: \(granted)")
            DispatchQueue.main.async {
                self?.checkAuthorizationStatus()
                completion(granted, error)
            }
        }
    }
    
    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                print("檢查通知權限狀態：\(settings.authorizationStatus.rawValue)")
                self?.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    // --- 發送通知 (第三階段實現) ---
    // 移除舊參數，改為立即觸發（帶微小延遲）
    func scheduleWakeUpNotification(soundEnabled: Bool, hapticEnabled: Bool) {
        // 1. Cancel any pending wake-up notifications first
        cancelPendingNotifications()
        
        // 2. Create content
        let content = UNMutableNotificationContent()
        content.title = "PowerNap 完成"
        content.body = "是時候醒來了！"
        // Set sound based on user preference
        content.sound = soundEnabled ? UNNotificationSound.defaultCritical : nil // Use critical for wake-up?
        // Mark as time-sensitive (iOS 15+ / watchOS 8+)
        content.interruptionLevel = .timeSensitive
        
        // 3. Create trigger (immediate)
        // Wake-up happens right after timer finishes, so trigger immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false) // Trigger almost instantly
        
        // 4. Create request
        let requestIdentifier = "PowerNapWakeUp"
        let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)
        
        // 5. Schedule the request
        notificationCenter.add(request) { error in
            if let error = error {
                print("排程喚醒通知失敗: \(error.localizedDescription)")
            } else {
                print("成功排程喚醒通知 (Sound: \(soundEnabled), Haptic: \(hapticEnabled))")
                // Trigger haptic feedback if enabled
                if hapticEnabled {
                    // Consider different haptic types based on intensity setting in the future
                    WKInterfaceDevice.current().play(.success) // Example haptic
                }
            }
        }
    }
    
    func cancelPendingNotifications() {
        let identifier = "PowerNapWakeUp"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
        print("已取消待處理的喚醒通知 (ID: \(identifier))")
    }
    
    // --- UNUserNotificationCenterDelegate 方法 (可選實現) ---
    
    // 當 App 在前景時，決定是否顯示通知
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                willPresent notification: UNNotification, 
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 對於喚醒通知，即使在前台也可能希望顯示 alert 和 sound/badge
        print("將要在前台顯示通知: \(notification.request.identifier)")
        completionHandler([.banner, .sound, .badge]) // 或者根據需求調整
    }
    
    // 處理用戶與通知的交互（例如點擊通知）
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                didReceive response: UNNotificationResponse, 
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        print("用戶與通知交互: \(response.actionIdentifier) for \(response.notification.request.identifier)")
        // 可以在這裡處理不同的 action
        completionHandler()
    }
} 