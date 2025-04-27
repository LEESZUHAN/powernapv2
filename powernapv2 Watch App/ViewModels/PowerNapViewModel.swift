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
private let thresholdAdjustmentKey = "thresholdAdjustmentPercentageOffset" // New key
// New keys for AppStorage
private let soundEnabledKey = "isWakeUpSoundEnabled"
private let hapticEnabledKey = "isWakeUpHapticEnabled"

@MainActor // ViewModel 通常在主線程操作 UI 和狀態
class PowerNapViewModel: ObservableObject {
    
    // MARK: - Services (依賴注入)
    private let healthKitService: HealthKitService
    private let motionService: MotionService
    private let notificationService: NotificationService
    /*private*/ let sleepDetectionService: SleepDetectionService // Made internal for debug access
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
    @Published var motionLevel: Double? = nil
    // New property for threshold adjustment (percentage offset, e.g., -0.05 to +0.05)
    @Published var thresholdAdjustmentPercentageOffset: Double = 0.0 
    // New properties for sound/haptic toggles, using AppStorage
    @AppStorage(soundEnabledKey) var isWakeUpSoundEnabled: Bool = true
    @AppStorage(hapticEnabledKey) var isWakeUpHapticEnabled: Bool = true
    
    // 用於 Combine 綁定
    private var cancellables = Set<AnyCancellable>()
    
    // 計時器
    private var countdownTimer: Timer?
    
    // Computed property for DebugView
    var debugSleepThresholdInfo: String {
        guard let rhr = restingHeartRate else {
            return "閾值: N/A (無 RHR)"
        }
        // Pass adjustment factor to calculation for debug display
        let threshold = sleepDetectionService.calculateHeartRateThreshold(rhr: rhr, adjustmentOffset: thresholdAdjustmentPercentageOffset)
        let basePercentage = userAgeGroup.heartRateThresholdPercentage
        let finalPercentage = basePercentage + thresholdAdjustmentPercentageOffset
        return String(format: "閾值: %.1f (%.1f%% of RHR %.1f)", threshold, finalPercentage * 100, rhr)
    }
    
    // Computed property for CountdownView
    var timeRemainingFormatted: String {
        let totalSeconds = Int(timeRemaining ?? 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Initialization
    init() {
        // Initialize basic services first
        self.healthKitService = HealthKitService()
        self.motionService = MotionService()
        self.notificationService = NotificationService()
        self.extendedRuntimeManager = ExtendedRuntimeManager()

        // Load threshold adjustment from UserDefaults *before* initializing dependent service
        let savedAdjustment = UserDefaults.standard.double(forKey: thresholdAdjustmentKey)
        self.thresholdAdjustmentPercentageOffset = savedAdjustment 
        
        // Now initialize sleepDetectionService using the loaded adjustment
        self.sleepDetectionService = SleepDetectionService(
            healthKitService: self.healthKitService,
            motionService: self.motionService,
            initialAgeGroup: .adult, // Start with default age group
            initialAdjustmentOffset: savedAdjustment // Use the local variable
        )

        print("PowerNapViewModel initialized with threshold adjustment: \(self.thresholdAdjustmentPercentageOffset)")
        
        // Load other UserDefaults values
        let savedDuration = UserDefaults.standard.integer(forKey: napDurationKey)
        self.selectedNapDuration = (savedDuration == 0) ? 15 : savedDuration
        self.napState = .idle

        // Setup bindings and initial checks
        setupBindings()
        checkInitialPermissions()
        determineUserAgeGroup() // Determines age group and updates sleepDetectionService later
        
        print("ViewModel Init complete.")
    }
    
    // MARK: - Setup
    private func setupBindings() {
        print("Setting up Combine bindings...")
        
        notificationService.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$notificationAuthorizationStatus)

        healthKitService.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                let previousStatus = self.healthKitAuthorizationStatus
                self.healthKitAuthorizationStatus = status
                let isNowAuthorized = status == .sharingAuthorized
                let wasPreviouslyAuthorized = previousStatus == .sharingAuthorized

                if isNowAuthorized && !wasPreviouslyAuthorized {
                    print("HealthKit permission granted. Fetching RHR and starting HR query.")
                    self.healthKitService.fetchRestingHeartRate()
                    self.healthKitService.startHeartRateQuery()
                    self.sleepDetectionService.startDetection()
                } else if !isNowAuthorized {
                    print("HealthKit permission not authorized (\(status.description)). Stopping services.")
                    self.healthKitService.stopHeartRateQuery()
                    self.sleepDetectionService.stopDetection()
                    self.stopCountdownTimer(reason: "HealthKit permission change")
                    if let savedRawValue = UserDefaults.standard.string(forKey: userSetAgeGroupRawValueKey),
                       let savedGroup = AgeGroup(rawValue: savedRawValue),
                       self.userAgeGroup != savedGroup {
                        self.userAgeGroup = savedGroup
                        self.sleepDetectionService.updateAgeGroup(savedGroup)
                    } else if UserDefaults.standard.string(forKey: userSetAgeGroupRawValueKey) == nil,
                              self.userAgeGroup != .adult {
                        self.userAgeGroup = .adult
                        self.sleepDetectionService.updateAgeGroup(.adult)
                    }
                }
            }
            .store(in: &cancellables)
            
        healthKitService.$latestHeartRate
            .receive(on: DispatchQueue.main)
            .assign(to: &$heartRate)

        healthKitService.$latestRestingHeartRate
            .receive(on: DispatchQueue.main)
            .assign(to: &$restingHeartRate)
            
        sleepDetectionService.$currentSleepState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                self.sleepState = state
                
                switch self.napState {
                case .detecting:
                    if state == .asleep {
                        self.napState = .napping
                        self.startCountdownTimer()
                    } else if state == .awake || state == .disturbed {
                        self.stopNap()
                    }
                case .napping:
                    if state != .asleep {
                        self.stopNap()
                    }
                case .idle, .finished, .paused, .error: 
                    break
                }
            }
            .store(in: &cancellables)
            
        $selectedNapDuration
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] duration in
                guard let self = self else { return }
                UserDefaults.standard.set(duration, forKey: napDurationKey)
                print("Saved nap duration: \(duration)")
            }
            .store(in: &cancellables)
            
        extendedRuntimeManager.$isSessionRunning
             .receive(on: DispatchQueue.main)
             .assign(to: &$isSessionRunning)

        $userAgeGroup
            .sink { [weak self] newGroup in
                self?.sleepDetectionService.updateAgeGroup(newGroup)
            }
            .store(in: &cancellables)
            
        // New binding for threshold adjustment
        $thresholdAdjustmentPercentageOffset
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main) // Debounce to avoid rapid saving
            .sink { [weak self] offset in
                guard let self = self else { return }
                UserDefaults.standard.set(offset, forKey: thresholdAdjustmentKey)
                self.sleepDetectionService.updateAdjustmentOffset(offset) // Notify service
                print("Saved threshold adjustment offset: \(offset)")
            }
            .store(in: &cancellables)

        print("Combine bindings setup complete.")
    }
    
    private func checkInitialPermissions() {
        print("權限狀態檢查由 Service 初始化觸發，反應邏輯在 setupBindings 中處理。")
    }
    
    // MARK: - Permission Handling (將在 WelcomeView 中調用)
    func requestHealthKitPermission(completion: @escaping (Bool, Error?) -> Void) {
        healthKitService.requestAuthorization { [weak self] granted, error in
            Task { @MainActor in
                guard let self = self else { 
                    completion(false, error)
                    return
                }
                
                print("ViewModel: HealthKit 權限請求回調，結果: \(granted), 錯誤: \(error?.localizedDescription ?? "無")")
                
                if granted {
                     print("HealthKit 權限請求交互完成，嘗試獲取 RHR 並啟動 HR 查詢...")
                    self.healthKitService.fetchRestingHeartRate()
                    self.healthKitService.startHeartRateQuery()
                    print("ViewModel: 開始睡眠偵測...")
                    self.sleepDetectionService.startDetection()
                } else {
                    print("HealthKit 權限請求交互未成功或用戶拒絕/取消。")
                    self.healthKitService.stopHeartRateQuery()
                    print("ViewModel: 停止睡眠偵測...")
                    self.sleepDetectionService.stopDetection()
                    self.stopCountdownTimer(reason: "HealthKit 權限請求失敗")
                }
                
                completion(granted, error)
            }
        }
    }
    
    func requestNotificationPermission(completion: @escaping (Bool, Error?) -> Void) {
        notificationService.requestAuthorization { granted, error in
            Task { @MainActor in
                print("ViewModel: 通知權限請求回調，結果: \(granted), 錯誤: \(error?.localizedDescription ?? "無")")
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
            Task { @MainActor in
                sleepState = .error("無效的小睡時長")
            }
            return
        }

        stopCountdownTimer(reason: "啟動新計時器")

        let totalTime = TimeInterval(selectedNapDuration * 60)
        Task { @MainActor in
            self.timeRemaining = totalTime
            self.isTimerRunning = true
            print("計時器啟動，總時長: \(totalTime) 秒 (\(selectedNapDuration) 分鐘)。")
        }

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                guard var remaining = self.timeRemaining else {
                    print("錯誤：計時器觸發時 timeRemaining 為 nil。停止計時器。")
                    self.stopCountdownTimer(reason: "內部錯誤 (timeRemaining is nil)")
                    return
                }

                remaining -= 1
                self.timeRemaining = remaining
                
                if remaining <= 0 {
                    print("計時結束！觸發喚醒。")
                    self.timeRemaining = 0
                    self.stopCountdownTimer(reason: "計時完成")
                    
                    self.scheduleWakeUpNotification() 
                    
                    print("ViewModel: Timer finished, setting napState to .finished")
                    self.napState = .finished
                    
                    print("ViewModel: 計時結束，停止 Extended Runtime Session。")
                    self.extendedRuntimeManager.stopSession()
                } else {
                     print("剩餘時間: \(remaining) 秒") 
                }
            }
        }
    }

    private func stopCountdownTimer(reason: String) {
        guard isTimerRunning else { return } 
        print("停止計時器，原因: \(reason)")
        countdownTimer?.invalidate()
        countdownTimer = nil
        isTimerRunning = false
        timeRemaining = nil

        if reason != "計時完成" { 
             print("取消待處理的喚醒通知 (若有)")
             notificationService.cancelPendingNotifications()
             print("ViewModel: 計時器提前停止，停止 Extended Runtime Session。")
             extendedRuntimeManager.stopSession()
             // Also stop the workout session if stopped early
             print("ViewModel: 計時器提前停止，停止 Workout Session。")
             healthKitService.stopWorkoutSession()
        }
    }
    
    // MARK: - App Lifecycle / State Management (未來實現)
    func startNap(duration: TimeInterval) {
        print("ViewModel: startNap() called. Starting services...")
        guard healthKitAuthorizationStatus == .sharingAuthorized else {
            print("Cannot start nap: HealthKit permission not authorized.")
            napState = .error("HealthKit 權限未授權")
            return
        }
        stopCountdownTimer(reason: "Starting new nap manually")
        
        print("ViewModel: Starting Workout Session.")
        healthKitService.startWorkoutSession() 
        
        // Start other services immediately
        sleepState = .detecting
        napState = .detecting
        motionService.startUpdates()
        healthKitService.startHeartRateQuery()
        healthKitService.fetchRestingHeartRate()
        sleepDetectionService.startDetection()
        
        // Introduce a small delay before starting the extended runtime session
        Task {
            // Delay for e.g., 0.5 seconds
            try? await Task.sleep(nanoseconds: 500_000_000) 
            // Ensure we are still in the detecting state before starting runtime
            guard self.napState == .detecting else { 
                print("ViewModel: Nap cancelled before extended runtime could start.")
                return
            }
            print("ViewModel: Starting Extended Runtime Session after delay.")
            // Start the extended runtime session on the MainActor
            await MainActor.run {
                 extendedRuntimeManager.startSession()
            }
        }
    }
    
    func stopNap() {
        print("ViewModel: stopNap() called. Stopping services...")
        // Stop HKWorkoutSession first or concurrently
        print("ViewModel: Stopping Workout Session.")
        healthKitService.stopWorkoutSession()
        
        motionService.stopUpdates()
        healthKitService.stopHeartRateQuery()
        sleepDetectionService.stopDetection()
        stopCountdownTimer(reason: "Nap stopped manually") // This also stops runtime session
        sleepState = .awake
        napState = .idle
        // Runtime session is stopped within stopCountdownTimer
    }
    
    // MARK: - Navigation (用於處理權限拒絕時跳轉設定)
    func openAppSettings() {
        print("嘗試跳轉到系統設定...")
        guard let settingsURL = URL(string: "app-settings:") else {
            print("無法創建設定 URL")
            return
        }
        
        WKExtension.shared().openSystemURL(settingsURL)
        print("已請求跳轉到設定 URL: \(settingsURL)")
    }
    
    // MARK: - Age Group Handling
    private func determineUserAgeGroup() {
        print("開始確定使用者年齡組...")
        
        var source: String = "預設值"
        
        if let savedRawValue = UserDefaults.standard.string(forKey: userSetAgeGroupRawValueKey),
           let savedGroup = AgeGroup(rawValue: savedRawValue) {
            source = "手動設定"
            print("找到手動設定的年齡組: \(savedGroup)。")
            if self.userAgeGroup != savedGroup {
                 self.userAgeGroup = savedGroup
            }
            sleepDetectionService.updateAgeGroup(savedGroup)
            return
        }
        
        guard healthKitAuthorizationStatus == .sharingAuthorized else {
            print("HealthKit 未授權，無法獲取出生日期。使用預設年齡組 .adult")
            source = "預設值 (HK 未授權)"
            if self.userAgeGroup != .adult { 
                self.userAgeGroup = .adult
            }
            sleepDetectionService.updateAgeGroup(.adult)
            print("最終確定年齡組: .adult，來源: \(source)")
            return
        }
        
        print("未找到手動設定，嘗試從 HealthKit 獲取出生日期...")
        healthKitService.fetchDateOfBirth { [weak self] birthDate in
            Task { @MainActor in 
                guard let self = self else { return }
                
                var finalGroup: AgeGroup = .adult
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
        print("手動更新年齡組為: \(newGroup)")
        if self.userAgeGroup != newGroup {
             self.userAgeGroup = newGroup
        }
        UserDefaults.standard.set(newGroup.rawValue, forKey: userSetAgeGroupRawValueKey)
        print("已將手動設定的年齡組 '\(newGroup.rawValue)' 儲存到 UserDefaults。")
        
        sleepDetectionService.updateAgeGroup(newGroup)
    }

    // MARK: - Nap Lifecycle
    func completeNapEarly() {
        print("ViewModel: completeNapEarly() called. Finishing nap manually...")
        // Stop HKWorkoutSession
        print("ViewModel: Stopping Workout Session.")
        healthKitService.stopWorkoutSession()
        
        stopCountdownTimer(reason: "Nap completed early manually") // This also stops runtime session
        sleepState = .awake
        napState = .finished
        motionService.stopUpdates()
        healthKitService.stopHeartRateQuery()
        sleepDetectionService.stopDetection() 
        // stopCountdownTimer already stops the runtime session
    }

    // MARK: - Helper Methods
    private func handleSleepStateChange(_ newState: SleepState) {
        print("Helper: Sleep state changed to: \(newState)")
        // Logic moved to the sink block in setupBindings
    }

    // New function to update threshold adjustment from Settings view
    func updateThresholdAdjustment(_ newOffset: Double) {
        // Apply clamping if necessary (e.g., limit to -0.05 to +0.05)
        let clampedOffset = max(-0.05, min(0.05, newOffset))
        if self.thresholdAdjustmentPercentageOffset != clampedOffset {
            self.thresholdAdjustmentPercentageOffset = clampedOffset
            // The change will be automatically saved and propagated via the $thresholdAdjustmentPercentageOffset sink binding
            print("ViewModel: Updated threshold offset to \(clampedOffset)")
        }
    }

    // Update scheduleWakeUpNotification to respect toggles
    private func scheduleWakeUpNotification() {
        notificationService.scheduleWakeUpNotification(
            soundEnabled: isWakeUpSoundEnabled, 
            hapticEnabled: isWakeUpHapticEnabled
        )
    }

    // New function for feedback (placeholder)
    func sendFeedback() {
        print("TODO: Implement feedback mechanism (e.g., open mail composer if possible on watchOS, or show instructions).")
        // Note: Opening mailto: links is generally not supported directly on watchOS.
        // Might need a companion app interaction or a server-side solution.
    }
} 

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