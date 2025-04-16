import Foundation
import HealthKit
import Combine

class HealthKitService {
    
    private let healthStore = HKHealthStore()
    
    // --- Published Properties ---
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    // TODO: Add publishers for heart rate, RHR etc. in Phase 2
    
    // --- Data Types to Request ---
    // Define the health data types we need access to.
    private let typesToRead: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
        // Add other types if needed (e.g., workout, active energy)
    ]
    
    private let typesToWrite: Set<HKSampleType> = [
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        // Add other types if needed
    ]
    
    init() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("錯誤：此設備不支持 HealthKit。")
            // Consider setting a specific error state for authorizationStatus or another property
            self.authorizationStatus = .sharingDenied // Or a custom state indicating unavailability
            return
        }
        print("HealthKitService 初始化完成。")
        checkAuthorizationStatus() // Check status on initialization
    }
    
    // --- 權限管理 ---
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        // Check if HealthKit is available (already done in init, but good practice)
        guard HKHealthStore.isHealthDataAvailable() else {
            let error = NSError(domain: "com.yourapp.HealthKitService", code: 1, userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available on this device."])
            completion(false, error)
            return
        }
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { [weak self] success, error in
            // Always dispatch back to the main thread for UI updates or ViewModel interactions
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("HealthKit 權限請求失敗: \(error.localizedDescription)")
                    // Update status even on error, as it might have changed (e.g., denied)
                    self.checkAuthorizationStatus()
                    completion(false, error)
                    return
                }
                
                if success {
                    print("HealthKit 權限請求成功 (但不代表所有類型都被授權)")
                    // Re-check the authorization status as the user might have granted/denied specific types
                    self.checkAuthorizationStatus()
                } else {
                    // This 'success' being false usually means the user cancelled or an error occurred.
                    // The error case above handles specific errors.
                    print("HealthKit 權限請求未成功 (可能取消或發生錯誤)")
                    self.checkAuthorizationStatus() // Still check status
                }
                
                // We report 'success' based on the request call itself, 
                // but the actual authorization state is reflected in the published property.
                completion(success, nil)
            }
        }
    }
    
    func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            self.authorizationStatus = .sharingDenied // Or a custom state
            return
        }
        
        // Check authorization status for a representative type (e.g., Sleep Analysis write access)
        // You might need a more sophisticated check depending on your app's core requirements.
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            print("無法獲取睡眠分析類型")
            // Handle this error appropriately - maybe default to notDetermined or an error state
            self.authorizationStatus = .notDetermined
            return
        }
        
        let currentStatus = healthStore.authorizationStatus(for: sleepType)
        print("檢查 HealthKit 權限狀態 (以睡眠分析為代表): \(currentStatus.rawValue)")
        
        // Update the published property on the main thread
        DispatchQueue.main.async {
            self.authorizationStatus = currentStatus
        }
    }
    
    // --- 數據讀取/寫入 (第二階段實現) ---
    // func fetchRestingHeartRate() { ... }
    // func startHeartRateQuery() { ... }
    // func saveNapSample(startDate: Date, endDate: Date) { ... }
} 