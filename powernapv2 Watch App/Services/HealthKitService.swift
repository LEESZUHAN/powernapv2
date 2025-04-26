import Foundation
import HealthKit
import Combine

class HealthKitService {
    
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKQuery? // Store the query to manage its lifecycle
    private var restingHeartRateQuery: HKQuery? // Store the query
    
    // --- Published Properties ---
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var latestHeartRate: Double? = nil
    @Published var latestRestingHeartRate: Double? = nil
    
    // Keep track of background delivery enabling
    private var isBackgroundDeliveryEnabled = false
    
    // --- Data Types to Request ---
    // Define the health data types we need access to.
    private let typesToRead: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!
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
    
    // MARK: - Heart Rate Monitoring
    
    func startHeartRateQuery() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            print("無法獲取心率類型")
            return
        }
        
        // Stop previous query if exists
        stopHeartRateQuery()
        
        // Create the query. We want updates whenever a new sample is added.
        let query = HKAnchoredObjectQuery(type: heartRateType, predicate: nil, anchor: nil, limit: HKObjectQueryNoLimit) { 
            [weak self] query, samples, deletedObjects, newAnchor, error in
            
            guard let self = self else { return }
            
            if let error = error {
                print("心率 HKAnchoredObjectQuery 錯誤: \(error.localizedDescription)")
                // Optionally handle the error, e.g., update a status publisher
                return
            }
            
            // Process the most recent sample, if available
            self.processHeartRateSamples(samples)
            
            // We don't need the anchor for this simple implementation, but it's available if needed for more complex scenarios.
        }
        
        // Set the update handler to receive notifications of new heart rate data.
        query.updateHandler = { [weak self] query, samples, deletedObjects, newAnchor, error in
            guard let self = self else { return }
            
            if let error = error {
                print("心率 updateHandler 錯誤: \(error.localizedDescription)")
                return
            }
            
            // Process the new samples received in the update
            self.processHeartRateSamples(samples)
        }
        
        // Store and execute the query
        self.heartRateQuery = query
        healthStore.execute(query)
        print("已啟動心率查詢 (HKAnchoredObjectQuery)")
        
        // Also, try to enable background delivery if not already done
        enableBackgroundDeliveryForHeartRate()
    }
    
    func stopHeartRateQuery() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
            print("已停止心率查詢")
        }
    }
    
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample], let lastSample = quantitySamples.last else {
            // No new samples or samples are not of the expected type
            // print("沒有新的心率樣本或類型不匹配") // Can be noisy, enable if debugging
            return
        }
        
        // Get the heart rate value in beats per minute (bpm)
        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
        let value = lastSample.quantity.doubleValue(for: heartRateUnit)
        
        // Update the published property on the main thread
        DispatchQueue.main.async {
            // print("接收到新心率: \(value) bpm at \(lastSample.endDate)") // Log for debugging
            self.latestHeartRate = value
        }
    }
    
    // MARK: - Resting Heart Rate
    
    func fetchRestingHeartRate() {
        guard let restingHeartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            print("無法獲取靜息心率類型")
            return
        }
        
        // Create a predicate to get samples from the last 24 hours (or another relevant period)
        // RHR isn't updated frequently, so fetching recent data is usually sufficient.
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate) // Look back 1 day
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        // We only need the most recent sample.
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: restingHeartRateType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { 
            [weak self] query, samples, error in
            
            guard let self = self else { return }
            
            if let error = error {
                print("靜息心率查詢錯誤: \(error.localizedDescription)")
                // Optionally clear the value or update a status
                DispatchQueue.main.async {
                    self.latestRestingHeartRate = nil
                }
                return
            }
            
            guard let sample = samples?.first as? HKQuantitySample else {
                print("未找到最近的靜息心率樣本")
                // No sample found in the period, might be normal.
                // Consider if you need to clear the published value or keep the old one.
                // For simplicity, let's clear it if no recent sample is found.
                 DispatchQueue.main.async {
                    self.latestRestingHeartRate = nil
                }
                return
            }
            
            let restingHeartRateUnit = HKUnit.count().unitDivided(by: .minute())
            let value = sample.quantity.doubleValue(for: restingHeartRateUnit)
            
            DispatchQueue.main.async {
                 print("獲取到靜息心率: \(value) bpm (樣本日期: \(sample.endDate))")
                self.latestRestingHeartRate = value
            }
        }
        
        // Execute the query
        healthStore.execute(query)
    }
    
    // MARK: - Background Delivery
    
    private func enableBackgroundDeliveryForHeartRate() {
        guard !isBackgroundDeliveryEnabled, 
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            // Already enabled or type unavailable
            return
        }
        
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { [weak self] success, error in
            guard let self = self else { return }
            if success {
                print("成功啟用心率背景交付")
                self.isBackgroundDeliveryEnabled = true
            } else {
                if let error = error {
                    print("啟用心率背景交付失敗: \(error.localizedDescription)")
                } else {
                    print("啟用心率背景交付失敗 (未知原因)")
                }
                // We might want to retry or inform the user
            }
        }
    }
    
    // --- 舊的 Placeholder --- (可以保留或刪除)
    // func fetchRestingHeartRate() { ... }
    // func startHeartRateQuery() { ... } // Now implemented above
    // func saveNapSample(startDate: Date, endDate: Date) { ... }
    
    // 新增：獲取出生日期的方法
    func fetchDateOfBirth(completion: @escaping (Date?) -> Void) {
        print("嘗試獲取出生日期...")
        do {
            let dateOfBirth = try healthStore.dateOfBirthComponents()
            let calendar = Calendar.current
            // 注意：dateOfBirthComponents 返回的是 DateComponents，需要轉換為 Date
            // 我們只需要年份來計算年齡，但還是轉換為 Date 比較通用
            // 如果只需要年份，可以直接用 dateOfBirth.year
            if let date = calendar.date(from: dateOfBirth) {
                print("成功獲取出生日期: \(date)")
                completion(date)
            } else {
                 print("無法從 DateComponents 轉換為 Date")
                 // 檢查是否有年份信息
                 if let year = dateOfBirth.year {
                     print("僅獲取到年份: \(year)")
                     // 如果只需要年份計算，這裡可以處理
                     // 但目前 completion handler 期望 Date?，所以返回 nil
                 } else {
                     print("DateComponents 中沒有有效的日期信息。")
                 }
                 completion(nil)
            }
            
        } catch {
            print("獲取出生日期時出錯: \(error.localizedDescription)")
            completion(nil)
        }
    }
} 