// Placeholder for PowerNapViewModel.swift 

import Foundation
import Combine
import SwiftUI // For ObservableObject and @Published
import HealthKit // For HKAuthorizationStatus
import UserNotifications // For UNAuthorizationStatus
import WatchKit // Re-add WatchKit for WKExtension access

// Key for UserDefaults
private let napDurationKey = "selectedNapDuration"
private let userSetAgeGroupRawValueKey = "userSetAgeGroupRawValue"

@MainActor // ViewModel 通常在主線程操作 UI 和狀態
class PowerNapViewModel: ObservableObject {
    
    // MARK: - Services (依賴注入)
    private let healthKitService: HealthKitService
    private let motionService: MotionService
    private let notificationService: NotificationService
    private let sleepDetectionService: SleepDetectionService
    private let extendedRuntimeManager: ExtendedRuntimeManager
    // 服務的初始化遵循 PowerNapXcodeDebugGuide.md 的最佳實踐
    
    // MARK: - Published Properties (UI 狀態)
    @Published var sleepState: SleepState = .awake
    @Published var napState: NapState = .idle
    @Published var healthKitAuthorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var heartRate: Double? = nil
    @Published var restingHeartRate: Double? = nil
    @Published var selectedNapDuration: Int = 15 // Default value
    @Published var timeRemaining: TimeInterval? = nil // 剩餘時間 (秒)
    @Published var isTimerRunning: Bool = false    // 計時器是否運行中
    @Published var isSessionRunning: Bool = false
    @Published var userAgeGroup: AgeGroup = .adult // Default to adult, will try to determine
    
    // 用於 Combine 綁定
    private var cancellables = Set<AnyCancellable>()
    
    // 計時器
    private var countdownTimer: Timer?
    
    // MARK: - Initialization
    init() {
        // 創建服務實例
        self.healthKitService = HealthKitService()
        self.motionService = MotionService()
        self.notificationService = NotificationService()
        self.extendedRuntimeManager = ExtendedRuntimeManager()
        // Initialize SleepDetectionService with a default age group (.adult) first
        self.sleepDetectionService = SleepDetectionService(healthKitService: self.healthKitService,
                                                         motionService: self.motionService,
                                                         initialAgeGroup: .adult) // Pass default

        print("PowerNapViewModel: 基礎服務初始化完成。")

        // Load saved duration from UserDefaults
        self.selectedNapDuration = UserDefaults.standard.integer(forKey: napDurationKey)
        if self.selectedNapDuration == 0 {
            self.selectedNapDuration = 15
            print("未找到儲存的小睡時長，使用預設值 \(self.selectedNapDuration) 分鐘。")
        } else {
            print("已載入儲存的小睡時長: \(self.selectedNapDuration) 分鐘。")
        }

        // Start in idle state
        self.napState = .idle

        // 執行其他初始化步驟
        setupBindings() // 設置 Combine 綁定
        checkInitialPermissions() // Check initial statuses

        // Now that all properties are initialized, determine the actual age group
        print("PowerNapViewModel: 調用 determineUserAgeGroup...")
        determineUserAgeGroup() // Call this *after* all initializations
    }
    
    // MARK: - Setup
    private func setupBindings() {
        print("設置 Combine 綁定...")
        
        // 綁定 NotificationService 的權限狀態
        notificationService.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$notificationAuthorizationStatus)

        // 綁定 HealthKitService 的權限狀態
        healthKitService.$authorizationStatus
            .receive(on: DispatchQueue.main)
            // Use sink to react to status changes (initial status handled in init)
            .sink { [weak self] status in
                guard let self = self else { return }
                let previousStatus = self.healthKitAuthorizationStatus // Store previous status
                self.healthKitAuthorizationStatus = status
                let isNowAuthorized = status == .sharingAuthorized
                let wasPreviouslyAuthorized = previousStatus == .sharingAuthorized

                if isNowAuthorized {
                    print("HealthKit 權限已確認授權...")
                    // Start services if not previously authorized or if they were stopped
                    if !wasPreviouslyAuthorized {
                        self.healthKitService.fetchRestingHeartRate()
                        self.healthKitService.startHeartRateQuery()
                        print("ViewModel: 開始睡眠偵測...")
                        self.sleepDetectionService.startDetection()
                        // Age group determination is now handled in init and updateManualAgeGroup
                        // We *could* re-determine here if permission was just granted,
                        // but determineUserAgeGroup prioritizes manual settings anyway.
                        // Let's assume the init call handled the first determination.
                    }
                } else {
                     // Handle case where permission is revoked or not granted
                     print("HealthKit 權限非授權狀態: \(status.description)，停止服務。")
                     self.healthKitService.stopHeartRateQuery()
                     print("ViewModel: 停止睡眠偵測...")
                     self.sleepDetectionService.stopDetection()
                     self.stopCountdownTimer(reason: "HealthKit 權限變更")
                     // If permission revoked, re-evaluate age group (load manual or default)
                     if let savedRawValue = UserDefaults.standard.string(forKey: userSetAgeGroupRawValueKey),
                        let savedGroup = AgeGroup(rawValue: savedRawValue) {
                         if self.userAgeGroup != savedGroup {
                             self.userAgeGroup = savedGroup
                             print("HealthKit 權限撤銷，使用手動設定的年齡組: \(savedGroup)")
                             self.sleepDetectionService.updateAgeGroup(savedGroup) // Update service
                         }
                     } else {
                         if self.userAgeGroup != .adult {
                             self.userAgeGroup = .adult // Fallback to default
                             print("HealthKit 權限撤銷，且無手動設定，使用預設年齡組: .adult")
                             self.sleepDetectionService.updateAgeGroup(.adult) // Update service
                         }
                     }
                }
            }
            .store(in: &cancellables)
            
        // 綁定 HealthKitService 的心率數據
        healthKitService.$latestHeartRate
            .receive(on: DispatchQueue.main) // 確保在主線程更新 UI
            .assign(to: &$heartRate)

        // 綁定 HealthKitService 的靜息心率數據
        healthKitService.$latestRestingHeartRate
            .receive(on: DispatchQueue.main)
            .assign(to: &$restingHeartRate)
            
        // 綁定 SleepDetectionService 的睡眠狀態
        sleepDetectionService.$currentSleepState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                self.sleepState = state
                
                // Update napState based on sleepState and current napState
                switch self.napState {
                case .detecting:
                    if state == .asleep {
                        print("ViewModel: Sleep detected, changing napState to .napping")
                        self.napState = .napping
                        self.startCountdownTimer() // Start timer *after* changing napState
                    } else if state == .awake || state == .disturbed {
                        // If detecting and user wakes up/moves, stop the nap process
                        print("ViewModel: Sleep detection interrupted (state: \(state)), stopping nap.")
                        self.stopNap()
                    }
                case .napping:
                    if state != .asleep {
                        // If napping and user wakes up/moves, stop the nap
                        print("ViewModel: Nap interrupted (state: \(state)), stopping nap.")
                        self.stopNap()
                    }
                case .idle, .finished, .paused, .error: 
                    // No automatic state changes based on sleepState in these nap states
                    // (Timer completion handles .finished transition)
                    break
                }
            }
            .store(in: &cancellables)
            
        // Bind selectedNapDuration to UserDefaults
        $selectedNapDuration
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main) // Add debounce to avoid rapid writes
            .sink { [weak self] duration in
                guard let self = self else { return }
                UserDefaults.standard.set(duration, forKey: napDurationKey)
                print("已儲存選擇的小睡時長: \(duration) 分鐘。")
                // Optional: Decide if changing duration should stop/restart a running timer
                // if self.isTimerRunning { self.stopCountdownTimer(reason: "時長設定變更"); self.startCountdownTimer() }
            }
            .store(in: &cancellables)
            
        // Bind to session running state from manager
        extendedRuntimeManager.$isSessionRunning
             .receive(on: DispatchQueue.main)
             .assign(to: &$isSessionRunning)

        print("Combine 綁定設置完成。")
    }
    
    private func checkInitialPermissions() {
        // Services check their status in init. 
        // The sink in setupBindings now handles the reaction to the initial HealthKit status.
        print("權限狀態檢查由 Service 初始化觸發，反應邏輯在 setupBindings 中處理。")
    }
    
    // MARK: - Permission Handling (將在 WelcomeView 中調用)
    func requestHealthKitPermission(completion: @escaping (Bool, Error?) -> Void) {
        // Pass the completion handler down to the service
        healthKitService.requestAuthorization { [weak self] granted, error in
            // Ensure execution on MainActor as we might update state
            Task { @MainActor in
                guard let self = self else { 
                    completion(false, error) // Ensure completion is called even if self is nil
                    return
                }
                
                print("ViewModel: HealthKit 權限請求回調，結果: \(granted), 錯誤: \(error?.localizedDescription ?? "無")")
                
                // Check the result of the request itself.
                // If the request was granted (user interacted and didn't cancel/error out),
                // proceed to fetch/start queries. The service's checkAuthorizationStatus 
                // has already updated the published status in the background via Combine.
                if granted {
                     print("HealthKit 權限請求交互完成，嘗試獲取 RHR 並啟動 HR 查詢...")
                    // Assume necessary types were granted if the overall request succeeded.
                    // HealthKitService queries might fail internally if specific read types were denied,
                    // but we initiate them here based on the successful authorization flow.
                    self.healthKitService.fetchRestingHeartRate()
                    self.healthKitService.startHeartRateQuery()
                    // 同時開始睡眠偵測 (如果邏輯是授權後立即開始)
                    print("ViewModel: 開始睡眠偵測...")
                    self.sleepDetectionService.startDetection()
                } else {
                    print("HealthKit 權限請求交互未成功或用戶拒絕/取消。")
                    // Ensure HR query is stopped if it was running
                    self.healthKitService.stopHeartRateQuery()
                    // 如果權限失敗，也停止睡眠偵測
                    print("ViewModel: 停止睡眠偵測...")
                    self.sleepDetectionService.stopDetection()
                    self.stopCountdownTimer(reason: "HealthKit 權限請求失敗") // Also stop timer
                }
                
                // Call the completion handler received from the View
                completion(granted, error)
            }
        }
    }
    
    func requestNotificationPermission(completion: @escaping (Bool, Error?) -> Void) {
        // Pass the completion handler down to the service
        notificationService.requestAuthorization { granted, error in
            // Ensure completion handler runs on MainActor if it updates UI
            Task { @MainActor in
                print("ViewModel: 通知權限請求回調，結果: \(granted), 錯誤: \(error?.localizedDescription ?? "無")")
                // Call the completion handler received from the View
                completion(granted, error)
            }
        }
    }
    
    // MARK: - Countdown Timer Logic
    private func startCountdownTimer() {
        guard !isTimerRunning else {
            print("計時器已在運行中，無需重新啟動。")
            return
        }
        
        guard selectedNapDuration > 0 else {
            print("錯誤：選擇的小睡時長無效 (\(selectedNapDuration) 分鐘)，無法啟動計時器。")
            // Update state on MainActor
            Task { @MainActor in
                sleepState = .error("無效的小睡時長")
            }
            return
        }

        stopCountdownTimer(reason: "啟動新計時器")

        let totalTime = TimeInterval(selectedNapDuration * 60)
        // Update state on MainActor
        Task { @MainActor in
            self.timeRemaining = totalTime
            self.isTimerRunning = true
            print("計時器啟動，總時長: \(totalTime) 秒 (\(selectedNapDuration) 分鐘)。")
        }

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            // Perform updates on the MainActor inside the timer's closure
            Task { @MainActor in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                guard var remaining = self.timeRemaining else {
                    print("錯誤：計時器觸發時 timeRemaining 為 nil。停止計時器。")
                    self.stopCountdownTimer(reason: "內部錯誤 (timeRemaining is nil)") // stopCountdownTimer is @MainActor isolated
                    return
                }

                remaining -= 1
                self.timeRemaining = remaining // @Published property, update on MainActor
                
                if remaining <= 0 {
                    print("計時結束！觸發喚醒。")
                    self.timeRemaining = 0 // Update on MainActor
                    self.stopCountdownTimer(reason: "計時完成") // Call @MainActor func
                    
                    // Trigger wake-up notification (Assuming NotificationService is Sendable or accessed correctly)
                    // If NotificationService itself isn't Sendable or methods aren't actor-isolated,
                    // this might need further attention, but for now, let's assume it's okay or the service handles its own concurrency.
                    // For safety, ensure NotificationService calls are appropriate. Let's call it from MainActor for now.
                    self.notificationService.scheduleWakeUpNotification() 
                    
                    print("ViewModel: Timer finished, setting napState to .finished")
                    self.napState = .finished // Update on MainActor
                    
                    print("ViewModel: 計時結束，停止 Extended Runtime Session。")
                    // Assuming ExtendedRuntimeManager is Sendable or handles its concurrency.
                    // Let's call it from MainActor for safety for now.
                    self.extendedRuntimeManager.stopSession()
                } else {
                    // Optional: Move print inside Task if it depends on UI state
                     print("剩餘時間: \(remaining) 秒") 
                }
            }
        }
    }

    private func stopCountdownTimer(reason: String) {
        // Accessing isTimerRunning, countdownTimer, timeRemaining - needs MainActor
        guard isTimerRunning else { return } 
        print("停止計時器，原因: \(reason)")
        countdownTimer?.invalidate()
        countdownTimer = nil
        isTimerRunning = false
        timeRemaining = nil

        if reason != "計時完成" { 
             print("取消待處理的喚醒通知 (若有)")
             // Assuming NotificationService is okay to call from MainActor
             notificationService.cancelPendingNotifications()
             print("ViewModel: 計時器提前停止，停止 Extended Runtime Session。")
             // Assuming ExtendedRuntimeManager is okay to call from MainActor
             extendedRuntimeManager.stopSession()
        }
    }
    
    // MARK: - App Lifecycle / State Management (未來實現)
    func startNap() {
        print("ViewModel: startNap() called. 開始服務...")
        // Ensure permissions are okay
        guard healthKitAuthorizationStatus == .sharingAuthorized else {
            print("無法開始小睡：HealthKit 權限未授權。")
            // Optionally provide feedback to the user here
            return
        }
        // Reset state just in case (stop previous timer, cancel notifications, set state to detecting)
        stopCountdownTimer(reason: "手動開始新的小睡") // Cancels timer/notifications/session
        sleepState = .detecting // Reset internal sleep detector state
        napState = .detecting   // Set overall nap state
        
        motionService.startUpdates()
        healthKitService.startHeartRateQuery() 
        healthKitService.fetchRestingHeartRate() 
        sleepDetectionService.startDetection()
        
        // Start Extended Runtime Session
        print("ViewModel: 開始 Extended Runtime Session。")
        extendedRuntimeManager.startSession()
    }
    
    func stopNap() {
        print("ViewModel: stopNap() called. 停止服務...")
        motionService.stopUpdates()
        healthKitService.stopHeartRateQuery()
        sleepDetectionService.stopDetection()
        stopCountdownTimer(reason: "手動停止小睡") // Cancels timer/notifications/session
        sleepState = .awake // Reset internal sleep detector state
        napState = .idle    // Reset overall nap state
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
        // WKExtension is available via SwiftUI on watchOS
        WKExtension.shared().openSystemURL(settingsURL)
        // Note: openSystemURL doesn't provide a direct success/failure callback like UIApplication.openURL
        // We assume the system handles it if the scheme is correct.
        print("已請求跳轉到設定 URL: \(settingsURL)")
    }
    
    // MARK: - Age Group Handling
    private func determineUserAgeGroup() {
        print("開始確定使用者年齡組...")
        // This method accesses @MainActor properties like healthKitAuthorizationStatus
        // and potentially updates userAgeGroup (@Published). It should run on MainActor.
        // Since the entire class is @MainActor, this is okay unless called from a non-main context.
        // The call from init() is fine because init runs on the main actor implicitly.
        
        var source: String = "預設值"
        
        // 1. Check UserDefaults for manually set group first
        if let savedRawValue = UserDefaults.standard.string(forKey: userSetAgeGroupRawValueKey),
           let savedGroup = AgeGroup(rawValue: savedRawValue) {
            source = "手動設定"
            print("找到手動設定的年齡組: \(savedGroup)。")
            // Update the published property if different
            if self.userAgeGroup != savedGroup {
                 self.userAgeGroup = savedGroup
            }
            // Update the SleepDetectionService
            sleepDetectionService.updateAgeGroup(savedGroup)
            return // Prioritize manual setting
        }
        
        // 2. If no manual setting, try fetching from HealthKit (only if authorized)
        guard healthKitAuthorizationStatus == .sharingAuthorized else {
            print("HealthKit 未授權，無法獲取出生日期。使用預設年齡組 .adult")
            source = "預設值 (HK 未授權)"
            // Update published property if different from current (which should be .adult initially)
            if self.userAgeGroup != .adult { 
                self.userAgeGroup = .adult
            }
            sleepDetectionService.updateAgeGroup(.adult) // Ensure service uses default
            print("最終確定年齡組: .adult，來源: \(source)")
            return
        }
        
        print("未找到手動設定，嘗試從 HealthKit 獲取出生日期...")
        healthKitService.fetchDateOfBirth { [weak self] birthDate in
            // Ensure UI updates and property access on main thread
            Task { @MainActor in 
                guard let self = self else { return }
                
                var finalGroup: AgeGroup = .adult // Default inside completion
                var completionSource = "預設值 (HK 獲取失敗)"
                
                if let birthDate = birthDate {
                    let calendar = Calendar.current
                    let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
                    if let age = ageComponents.year {
                        finalGroup = AgeGroup.forAge(age)
                        completionSource = "HealthKit 自動偵測"
                        print("根據出生日期計算年齡為 \(age)，確定年齡組為: \(finalGroup)")
                    } else {
                        print("無法從出生日期計算年齡，使用預設年齡組 .adult")
                        completionSource = "預設值 (年齡計算失敗)"
                    }
                } else {
                    print("無法從 HealthKit 獲取出生日期 (可能數據不存在)，使用預設年齡組 .adult")
                }
                
                // Update published property and the service
                if self.userAgeGroup != finalGroup {
                    self.userAgeGroup = finalGroup
                }
                self.sleepDetectionService.updateAgeGroup(finalGroup)
                print("最終確定年齡組: \(finalGroup)，來源: \(completionSource)")
            }
        }
    }
    
    /// Called from SettingsView when user manually changes the age group
    func updateManualAgeGroup(_ newGroup: AgeGroup) {
         // This is called from SwiftUI, so it should be on MainActor already
        print("手動更新年齡組為: \(newGroup)")
        if self.userAgeGroup != newGroup {
             self.userAgeGroup = newGroup
        }
        // Save the manual setting to UserDefaults
        UserDefaults.standard.set(newGroup.rawValue, forKey: userSetAgeGroupRawValueKey)
        print("已將手動設定的年齡組 '\(newGroup.rawValue)' 儲存到 UserDefaults。")
        
        // Update the SleepDetectionService immediately
        sleepDetectionService.updateAgeGroup(newGroup)
    }
} 

// Extension for HKAuthorizationStatus description (Keep or move as needed)
// Added @retroactive based on build warning
extension HKAuthorizationStatus: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .notDetermined: return "未決定"
        case .sharingDenied: return "已拒絕"
        case .sharingAuthorized: return "已授權"
        @unknown default:
            return "未知狀態 (\\(rawValue))"
        }
    }
}

// Extension for UNAuthorizationStatus description (Keep or move as needed)
// Added @retroactive based on build warning
extension UNAuthorizationStatus: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .notDetermined: return "未決定"
        case .denied: return "已拒絕"
        case .authorized: return "已授權"
        case .provisional: return "臨時授權"
        case .ephemeral: return "短暫授權"
        @unknown default:
            return "未知狀態 (\\(rawValue))"
        }
    }
} 