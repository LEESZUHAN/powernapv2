// Placeholder for PowerNapViewModel.swift 

import Foundation
import Combine
import SwiftUI // For ObservableObject and @Published
import HealthKit // For HKAuthorizationStatus
import UserNotifications // For UNAuthorizationStatus
import WatchKit // Import WatchKit for WKExtension

@MainActor // ViewModel 通常在主線程操作 UI 和狀態
class PowerNapViewModel: ObservableObject {
    
    // MARK: - Services (依賴注入)
    private let healthKitService: HealthKitService
    private let motionService: MotionService
    private let notificationService: NotificationService
    // 服務的初始化遵循 PowerNapXcodeDebugGuide.md 的最佳實踐
    
    // MARK: - Published Properties (UI 狀態)
    @Published var currentNapState: NapState = .idle
    @Published var healthKitAuthorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    
    // 用於 Combine 綁定
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        // 在 init 內部創建和持有服務實例
        self.healthKitService = HealthKitService()
        self.motionService = MotionService()
        self.notificationService = NotificationService()
        
        print("PowerNapViewModel 初始化完成，服務已創建。")
        
        // 執行其他初始化步驟
        setupBindings() // 設置 Combine 綁定
        checkInitialPermissions() // 檢查初始權限狀態
    }
    
    // MARK: - Setup
    private func setupBindings() {
        print("設置 Combine 綁定...")
        
        // 綁定 NotificationService 的權限狀態
        notificationService.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$notificationAuthorizationStatus)
            // .store(in: &cancellables) // assign(to:) on @Published doesn't need .store

        // 綁定 HealthKitService 的權限狀態
        healthKitService.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$healthKitAuthorizationStatus)
            // .store(in: &cancellables)
            
        // TODO: 綁定 SleepDetectionService 的 SleepState (第二階段)
        // TODO: 綁定其他需要的服務狀態
        print("Combine 綁定設置完成。")
    }
    
    private func checkInitialPermissions() {
        // 服務在初始化時會自行檢查初始狀態 (NotificationService & HealthKitService)
        // 所以這裡不再需要手動觸發
        // healthKitService.checkAuthorizationStatus()
        print("初始權限狀態將通過 Combine 綁定自動更新。")
    }
    
    // MARK: - Permission Handling (將在 WelcomeView 中調用)
    func requestHealthKitPermission(completion: @escaping (Bool, Error?) -> Void) {
        // Pass the completion handler down to the service
        healthKitService.requestAuthorization { granted, error in
            print("ViewModel: HealthKit 權限請求回調，結果: \(granted), 錯誤: \(error?.localizedDescription ?? "無")")
            // Call the completion handler received from the View
            completion(granted, error)
        }
    }
    
    func requestNotificationPermission(completion: @escaping (Bool, Error?) -> Void) {
        // Pass the completion handler down to the service
        notificationService.requestAuthorization { granted, error in
            print("ViewModel: 通知權限請求回調，結果: \(granted), 錯誤: \(error?.localizedDescription ?? "無")")
            // Call the completion handler received from the View
            completion(granted, error)
        }
    }
    
    // MARK: - App Lifecycle / State Management (未來實現)
    func startNap() {
        print("TODO: 實現開始小睡的邏輯")
        // currentNapState = .detecting
        // motionService.startUpdates()
        // healthKitService.startHeartRateQuery()
        // ... 啟動 Extended Runtime Session
    }
    
    func stopNap() {
        print("TODO: 實現停止小睡的邏輯")
        // currentNapState = .finished 或 .idle
        // motionService.stopUpdates()
        // healthKitService.stopHeartRateQuery()
        // ... 停止 Extended Runtime Session
    }
    
    // MARK: - Navigation (用於處理權限拒絕時跳轉設定)
    func openAppSettings() {
        print("嘗試跳轉到系統設定...")
        // Use the recommended URL scheme for opening settings on watchOS
        guard let settingsURL = URL(string: "app-settings:") else {
            print("無法創建設定 URL")
            return
        }
        
        // Use WKExtension to open the system URL
        WKExtension.shared().openSystemURL(settingsURL)
        // Note: openSystemURL doesn't provide a direct success/failure callback like UIApplication.openURL
        // We assume the system handles it if the scheme is correct.
        print("已請求跳轉到設定 URL: \(settingsURL)")
    }
} 