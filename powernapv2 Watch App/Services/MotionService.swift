import Foundation
import CoreMotion
import Combine

// MARK: - Constants
private struct MotionConstants {
    static let deviceMotionUpdateInterval: TimeInterval = 0.1 // 更新頻率 (10Hz)，可以根據需要調整
    static let stillnessThresholdG: Double = 0.05 // userAcceleration 幅度閾值 (單位: g)，需要實驗調整
    static let stillnessDurationThreshold: TimeInterval = 5.0 // 縮短持續靜止時間要求 (5秒)
}

class MotionService {
    
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    
    // MARK: - Published Properties
    @Published var isStill: Bool = true
    
    // 未來用於發布數據的 Publisher (第二階段)
    // @Published var motionLevel: Double = 0.0 // 可以是加速度計數據的某種量化表示
    
    // --- 內部狀態 ---
    private var stillStartTime: Date? // 用於追蹤靜止開始時間
    
    init() {
        // 設置更新隊列為後台執行
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        
        // 檢查運動數據是否可用
        guard motionManager.isDeviceMotionAvailable else {
            // 處理 Core Motion 不可用的情況
            print("錯誤：此設備不支持 Core Motion Device Motion。")
            // 可能需要進一步檢查加速度計等是否可用
            if !motionManager.isAccelerometerAvailable {
                print("錯誤：此設備不支持加速度計。")
            }
            return
        }
        print("MotionService 初始化完成。")
    }
    
    // --- 權限管理 (如果需要特定數據類型) ---
    // CoreMotion 對於基本運動數據通常不需要像 HealthKit 那樣的顯式權限請求
    // 但如果使用 CMMotionActivityManager 或需要位置信息則可能需要
    // func requestAuthorizationIfNeeded() { ... }
    
    // --- 數據更新 (第二階段實現) ---
    func startUpdates() {
        // 使用 Device Motion 而不是 Accelerometer
        guard motionManager.isDeviceMotionAvailable else {
            print("Device Motion 不可用，無法啟動更新。")
            return
        }
        
        // 清除之前的狀態
        stillStartTime = nil
        // 預設啟動時認為是靜止的，直到檢測到運動
        updateStillness(isCurrentlyStill: true)
        
        motionManager.deviceMotionUpdateInterval = MotionConstants.deviceMotionUpdateInterval
        
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] (motion, error) in
            guard let self = self, let deviceMotion = motion else {
                if let error = error {
                    print("Device Motion 更新錯誤: \(error.localizedDescription)")
                    // Consider stopping updates or handling the error
                    DispatchQueue.main.async { self?.isStill = true } // Fallback to still on error?
                }
                return
            }
            
            self.processDeviceMotionData(deviceMotion)
        }
        print("已啟動 Device Motion 更新")
    }
    
    func stopUpdates() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
            print("已停止 Device Motion 更新")
        }
        // 重置狀態
        stillStartTime = nil
        // 停止時可以認為是靜止的
        updateStillness(isCurrentlyStill: true)
    }
    
    // MARK: - Private Helper Methods
    
    private func processDeviceMotionData(_ motion: CMDeviceMotion) {
        let userAcceleration = motion.userAcceleration
        
        // 計算 userAcceleration 的幅度 (magnitude)
        let accelerationMagnitude = sqrt(userAcceleration.x * userAcceleration.x + 
                                       userAcceleration.y * userAcceleration.y + 
                                       userAcceleration.z * userAcceleration.z)
        
        // print(String(format: "Accel Magnitude: %.4f g", accelerationMagnitude)) // Debug log
        
        // 判斷是否移動 (幅度超過閾值)
        let isMoving = accelerationMagnitude > MotionConstants.stillnessThresholdG
        
        if isMoving {
            // 如果檢測到移動，重置靜止計時器，並標記為非靜止
            stillStartTime = nil
            updateStillness(isCurrentlyStill: false)
            // print("Detected Movement (Magnitude: \(String(format: "%.4f", accelerationMagnitude)))") // Debug log
        } else {
            // 如果檢測到靜止 (幅度低於或等於閾值)
            if stillStartTime == nil {
                // 如果是剛開始靜止，記錄時間
                stillStartTime = Date()
                // print("Stillness Timer Started (Magnitude: \(String(format: "%.4f", accelerationMagnitude)))") // Debug log
                // 暫時不更新 isStill，等待持續時間達標
                // 如果啟動時 isStill 是 true，且第一次檢測就低於閾值，則保持 true
                // 如果之前是 isMoving (isStill=false)，則需要等待時間達標才能變回 true
            } else {
                // 如果已經在靜止計時中，檢查是否達到閾值
                if let start = stillStartTime,
                   Date().timeIntervalSince(start) >= MotionConstants.stillnessDurationThreshold {
                    // 達到持續靜止時間，標記為靜止
                    updateStillness(isCurrentlyStill: true)
                    // print("Detected Stillness (Duration Met)") // Debug log
                } else {
                    // 持續時間未達標，狀態不變
                }
            }
        }
    }
    
    // Helper to update published property on main thread
    private func updateStillness(isCurrentlyStill: Bool) {
        // 只有當狀態真的改變時才更新，避免不必要的 UI 刷新
        if self.isStill != isCurrentlyStill {
            DispatchQueue.main.async {
                self.isStill = isCurrentlyStill
                // print("isStill updated to: \(isCurrentlyStill)") // Debug log
            }
        }
    }
} 