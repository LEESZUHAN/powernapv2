import Foundation
import Combine
import HealthKit // Add import for HK Objects
import CoreMotion // Add import for Motion detection

// MARK: - Sleep State Enum
// enum SleepState: Equatable {
//     case awake         // 清醒
//     case detecting     // 監測中，尚未滿足入睡條件
//     case potentialSleep // 條件部分滿足，觀察中（可選，初期可不用）
//     case asleep        // 已入睡
//     case disturbed     // 睡眠被打斷 (例如大幅度移動)
//     case finished      // 小睡完成 (計時結束)
//     case error(String) // 發生錯誤
// }

// MARK: - Sleep Detection Service
class SleepDetectionService: ObservableObject {

    // MARK: - Dependencies
    private let healthKitService: HealthKitService
    private let motionService: MotionService
    private var currentAgeGroup: AgeGroup // <-- Add property to hold age group
    private var currentAdjustmentOffset: Double // New property for adjustment

    // MARK: - Published Properties
    @Published var currentSleepState: SleepState = .awake

    // MARK: - Internal State & Timers
    private var heartRateData: [Double] = [] // Store recent HR samples if needed for averaging/stability
    private var latestRHR: Double? = nil
    private var isCurrentlyStill: Bool = true

    // Timers or state tracking for meeting duration requirements
    private var lowHRStartTime: Date?

    // Constants (Now driven by AgeGroup)
    // private let requiredLowHRDuration: TimeInterval = 180 // Removed, use currentAgeGroup

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(healthKitService: HealthKitService, motionService: MotionService, initialAgeGroup: AgeGroup, initialAdjustmentOffset: Double) {
        self.healthKitService = healthKitService
        self.motionService = motionService
        self.currentAgeGroup = initialAgeGroup // Set initial age group
        self.currentAdjustmentOffset = initialAdjustmentOffset // Set initial offset
        print("SleepDetectionService 初始化完成，初始年齡組: \(initialAgeGroup), 初始調整: \(initialAdjustmentOffset)")
        setupBindings()
    }

    // MARK: - Combine Subscriptions
    private func setupBindings() {
        print("SleepDetectionService: 設置綁定...")

        // Subscribe to Resting Heart Rate
        healthKitService.$latestRestingHeartRate
            .receive(on: DispatchQueue.main) // Process on main thread for simplicity for now
            .sink { [weak self] rhr in
                guard let self = self, let restingHR = rhr else { return }
                print("SleepDetectionService: 收到 RHR 更新: \(restingHR)")
                self.latestRHR = restingHR
                self.evaluateSleepState() // Re-evaluate on RHR change
            }
            .store(in: &cancellables)

        // Subscribe to Heart Rate
        healthKitService.$latestHeartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hr in
                guard let self = self, let heartRate = hr else { return }
                 print("SleepDetectionService: 收到 HR 更新: \(heartRate)")
                // Optional: Store recent samples if needed
                // self.heartRateData.append(heartRate)
                // self.heartRateData = Array(self.heartRateData.suffix(WINDOW_SIZE))
                self.evaluateSleepState() // Re-evaluate on HR change
            }
            .store(in: &cancellables)

        // Subscribe to Stillness Status
        motionService.$isStill
            .receive(on: DispatchQueue.main)
            .sink { [weak self] still in
                guard let self = self else { return }
                print("SleepDetectionService: 收到 isStill 更新: \(still)")
                self.isCurrentlyStill = still
                 if !still {
                    // If movement detected, reset sleep detection timers/state immediately
                    self.resetTimersAndState(to: .awake, reason: "Movement detected")
                 }
                self.evaluateSleepState() // Re-evaluate on stillness change
            }
            .store(in: &cancellables)

        print("SleepDetectionService: 綁定設置完成")
    }

    // MARK: - Core Logic
    private func evaluateSleepState() {
        // Step 1: Ensure we have at least the current heart rate.
        guard let currentHR = healthKitService.latestHeartRate else {
            // Log if state changes, reset only if not already awake.
            if currentSleepState != .awake {
                print("SleepDetectionService: [Guard Fail] Missing HR data. Resetting to Awake.")
                resetTimersAndState(to: .awake, reason: "Missing HR data")
            }
            return
        }
        
        // Step 2: Get RHR if available.
        let currentRHR = self.latestRHR 

        // Step 3: Determine if conditions are met (Requires RHR).
        var conditionsMet = false
        var calculatedThreshold: Double? = nil // For logging
        if let rhr = currentRHR {
            let threshold = calculateHeartRateThreshold(rhr: rhr, adjustmentOffset: currentAdjustmentOffset)
            calculatedThreshold = threshold
            conditionsMet = currentHR < threshold && isCurrentlyStill
            // print("Evaluating with RHR: \(rhr), Threshold: \(threshold), Conditions Met: \(conditionsMet)")
        } else {
            // RHR not available yet, conditions cannot be met.
            conditionsMet = false 
            // print("Waiting for RHR...")
        }
        
        // Step 4: State transition logic.
        let requiredDuration = currentAgeGroup.minDurationForSleepDetection

        switch currentSleepState {
            
        case .awake, .detecting, .disturbed:
            if conditionsMet {
                // Conditions met (HR, RHR, Still) - Start or continue timer.
                if lowHRStartTime == nil {
                    print("SleepDetectionService: [State: \(currentSleepState)] Conditions met (HR < \(calculatedThreshold ?? -1)) & Still. Starting timer.")
                    lowHRStartTime = Date()
                    if currentSleepState != .detecting { // Transition to detecting if not already there.
                        currentSleepState = .detecting
                    }
                } else {
                    // Timer running, check duration.
                    if let startTime = lowHRStartTime, Date().timeIntervalSince(startTime) >= requiredDuration {
                        print("SleepDetectionService: [State: Detecting] Duration met (>= \(requiredDuration)s). Transitioning to Asleep.")
                        currentSleepState = .asleep
                        lowHRStartTime = nil // Reset timer after transition.
                    } else {
                        // Duration not met yet, remain in detecting state.
                        // print("SleepDetectionService: [State: Detecting] Conditions met, duration not yet met.")
                    }
                }
            } else {
                // Conditions NOT met (HR too high, moved, OR RHR missing).
                if lowHRStartTime != nil {
                    // Timer was running, but conditions failed.
                    print("SleepDetectionService: [State: Detecting] Conditions no longer met (HR >= \(calculatedThreshold ?? -1) or Moved or RHR missing). Resetting timer and state to Awake.")
                    resetTimersAndState(to: .awake, reason: "Conditions failed while timer running")
                } else if currentSleepState == .detecting {
                    // Was detecting, but conditions failed before timer started OR RHR is still missing.
                    if currentRHR == nil {
                        // Do nothing, just wait for RHR.
                        // print("SleepDetectionService: [State: Detecting] Still waiting for RHR.")
                    } else {
                        // RHR is present, but HR high or moved.
                        print("SleepDetectionService: [State: Detecting] Conditions failed (HR >= \(calculatedThreshold ?? -1) or Moved). Resetting to Awake.")
                        resetTimersAndState(to: .awake, reason: "Conditions failed before timer start")
                    }
                } else {
                    // State is .awake or .disturbed, conditions still not met. No change needed.
                }
            }
            
        case .asleep:
            if !conditionsMet {
                // Conditions failed while asleep.
                print("SleepDetectionService: [State: Asleep] Conditions no longer met (HR >= \(calculatedThreshold ?? -1) or Moved or RHR missing). Resetting to Awake.")
                resetTimersAndState(to: .awake, reason: "Conditions failed while asleep")
            }
            // Otherwise, remain asleep.

        case .finished, .error:
            // No state changes triggered by evaluation.
            break 
        }
    }

    // MARK: - Heart Rate Threshold Calculation

    // Made internal to be called from ViewModel for debug display
    /*private*/ func calculateHeartRateThreshold(rhr: Double, adjustmentOffset: Double) -> Double {
        // Calculate base threshold percentage from age group
        let baseThresholdPercentage = currentAgeGroup.heartRateThresholdPercentage
        // Apply the adjustment offset
        let adjustedThresholdPercentage = baseThresholdPercentage + adjustmentOffset
        // Clamp the adjusted percentage to a reasonable range (e.g., 75% to 98%)
        let clampedPercentage = max(0.75, min(0.98, adjustedThresholdPercentage))
        
        let calculatedThreshold = rhr * clampedPercentage
        
        let absoluteMinimumThreshold: Double = 40.0 
        let finalThreshold = max(calculatedThreshold, absoluteMinimumThreshold)
        
        print("SleepDetectionService: RHR=\(rhr), Age=\(currentAgeGroup), Base%=\(baseThresholdPercentage), Adj%=\(adjustedThresholdPercentage), Clamp%=\(clampedPercentage), CalcThr=\(calculatedThreshold), FinalThr=\(finalThreshold)")
        return finalThreshold
    }
    
    // Renamed back from resetSleepDetectionState - Now also handles state transition
    private func resetTimersAndState(to newState: SleepState, reason: String) { 
        print("SleepDetectionService: Resetting state to \(newState). Reason: \(reason)")
        lowHRStartTime = nil
        // self.heartRateData = [] // Reset buffer if used
        
        // Update state only if it's different
        if currentSleepState != newState {
            currentSleepState = newState
        }
    }

    // MARK: - Public Control (Optional)
    func startDetection() {
        print("SleepDetectionService: 開始偵測... Age: \(currentAgeGroup), Adj: \(currentAdjustmentOffset)")
        currentSleepState = .detecting
        resetTimersAndState(to: .detecting, reason: "Manual start")
    }

    func stopDetection() {
         print("SleepDetectionService: 停止偵測...")
         // Reset state? Stop timers?
         resetTimersAndState(to: .awake, reason: "Manual stop")
         currentSleepState = .awake // Or idle?
    }

    // MARK: - Public Methods
    /// Allows the ViewModel to update the age group used for calculations.
    func updateAgeGroup(_ newGroup: AgeGroup) {
        print("SleepDetectionService: 年齡組更新為 \(newGroup)")
        self.currentAgeGroup = newGroup
        // No immediate re-evaluation needed, next cycle will use the new group
    }

    // New method to update the adjustment offset
    func updateAdjustmentOffset(_ newOffset: Double) {
        print("SleepDetectionService: 調整偏移更新為 \(newOffset)")
        self.currentAdjustmentOffset = newOffset
        // No immediate re-evaluation needed, next cycle will use the new offset
    }

} 