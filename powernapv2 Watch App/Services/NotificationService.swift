import Foundation
import UserNotifications
import Combine

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
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .criticalAlert] // 包含聲音和震動，以及關鍵提醒
        notificationCenter.requestAuthorization(options: options) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.checkAuthorizationStatus() // 請求後更新狀態
                print("通知權限請求完成，結果：\(granted)")
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
    func scheduleWakeUpNotification(duration: TimeInterval, hapticType: String?, soundEnabled: Bool) {
        print("TODO: 實現發送喚醒通知的邏輯")
        // 需要創建 UNMutableNotificationContent 和 UNTimeIntervalNotificationTrigger
    }
    
    func cancelPendingNotifications() {
        print("TODO: 實現取消待處理通知的邏輯")
        // notificationCenter.removeAllPendingNotificationRequests()
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