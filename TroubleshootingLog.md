# PowerNap 專案問題追蹤記錄

本文件記錄開發過程中遇到的潛在問題、警告、錯誤及其解決狀態和嚴重性。

## 注意事項

*   Gemini 回報的 Linter 錯誤可能與 Xcode 中的即時錯誤/警告略有不同或有延遲，最終以 Xcode 建置 (Build) 結果為準。

## 問題列表

### 1. `MessagesApplicationStub.xcassets` 相關的建置警告

*   **問題描述:** 在為 iPhone 模擬器建置時，Xcode 顯示警告 `warning: Could not get trait set for device Watch7,3 with version 11.2`，來源於 `MessagesApplicationStub.xcassets`。
*   **發現時間:** 2025-04-15 (基於 Build log)
*   **嚴重性:** Low (低)
*   **狀態:** Open (Ignored - 待觀察)
*   **分析:** 似乎是 Xcode 預設模板在處理模擬器建置時產生的附帶警告，與 iMessage 擴充功能相關，而非 Watch App 本身。目前建置成功，不影響 App 運行。
*   **解決方案/後續:** 暫時忽略。如果未來導致其他問題或持續困擾，再考慮深入研究專案設定。

### 2. 系統類型 `CustomStringConvertible` 擴展警告

*   **問題描述:** 在 `WelcomeView.swift` 中為 `UNAuthorizationStatus` 和 `HKAuthorizationStatus` 添加 `CustomStringConvertible` 擴展時，Xcode 顯示警告，提示未來若系統框架自己實現該協議可能導致衝突。
*   **發現時間:** 2025-04-15 (基於 Build log)
*   **嚴重性:** Low (低)
*   **狀態:** Resolved (已解決)
*   **分析:** 這是 Swift 對擴展系統類型添加協議遵循的標準警告。目前用於預覽和調試，不影響功能。
*   **解決方案:** 已將擴展移至 `PowerNapViewModel.swift`，並使用 `@retroactive` 標記。

### 3. `WelcomeView.swift` 初始編譯錯誤 (Cannot find type...)

*   **問題描述:** 初次建置 `WelcomeView.swift` 時，編譯器報錯 `Cannot find type 'UNAuthorizationStatus'` 和 `Cannot find type 'HKAuthorizationStatus'`。
*   **發現時間:** 2025-04-15 (基於 Build log)
*   **嚴重性:** High (當時阻礙編譯)
*   **狀態:** Resolved (已解決)
*   **分析:** `WelcomeView.swift` 文件缺少對 `UserNotifications` 和 `HealthKit` 框架的 import。
*   **解決方案:** 在 `WelcomeView.swift` 頂部添加 `import UserNotifications` 和 `import HealthKit`。

### 4. `WelcomeView.swift` 條件判斷錯誤 (HKAuthorizationStatus case 名稱)

*   **問題描述:** 在 `WelcomeView.swift` 檢查 HealthKit 權限狀態時，使用了錯誤的 case 名稱 `.denied`。
*   **發現時間:** 2025-04-15 (基於 Build log)
*   **嚴重性:** High (當時阻礙編譯)
*   **狀態:** Resolved (已解決)
*   **分析:** `HKAuthorizationStatus` 表示拒絕的 case 實際名稱是 `.sharingDenied`。
*   **解決方案:** 將條件判斷 `viewModel.healthKitAuthorizationStatus == .denied` 修改為 `viewModel.healthKitAuthorizationStatus == .sharingDenied`。

### 5. Gemini Linter 誤報 `Cannot find 'PowerNapViewModel' in scope`

*   **問題描述:** Gemini 的 Linter 在多次編輯後持續報告 `WelcomeView.swift` 中 `Cannot find 'PowerNapViewModel' in scope`，但 Xcode 實際建置並未報告此錯誤且成功。
*   **發現時間:** 2025-04-15
*   **嚴重性:** Info (資訊)
*   **狀態:** Closed (Spurious - 誤報/已忽略)
*   **分析:** 可能是 Gemini 使用的 Linter 索引更新延遲或與 Xcode 建置環境存在差異導致的誤報。
*   **解決方案/後續:** 忽略此 Linter 錯誤，以 Xcode 實際建置結果為準。

### 6. ViewModel 權限狀態綁定時序導致的日誌誤導

*   **問題描述:** `PowerNapViewModel` 在 `setupBindings` 中使用 `.sink` 訂閱 `HealthKitService` 的 `authorizationStatus` 時，會先收到初始的 `.notDetermined` 狀態，導致觸發非授權的處理邏輯（打印 "停止 HR 查詢"），隨後才收到真實的授權狀態並觸發正確的查詢啟動邏輯。類似地，在 `init` 末尾調用的 `determineUserAgeGroup` 方法內部檢查 `healthKitAuthorizationStatus` 時，也可能因為 Combine 異步更新延遲而讀取到舊的未授權狀態，導致打印 "HealthKit 未授權" 日誌，儘管實際權限可能已在請求後變為已授權。這些初始的"停止"或"未授權"日誌可能造成混淆。
*   **發現時間:** 2025-04-21 (基於 Console log 分析), 2025-04-26 (確認 init 時序問題)
*   **嚴重性:** Low (低) / Info (資訊)
*   **狀態:** Open (Optional Optimization - 可選優化)
*   **分析:** 這是 Combine @Published 屬性初始化與 `.sink` 接收初始值、以及 `init` 內同步檢查與 Combine 異步更新之間的正常時序行為。功能上目前無影響，但日誌不夠精確。
*   **解決方案/後續:** 未來可考慮在 `.sink` 前使用 `.dropFirst()` 操作符忽略初始值，或在 `determineUserAgeGroup` 中採用異步方式等待權限狀態確認，使日誌更清晰。目前暫不處理。

### 7. ViewModel 初始化錯誤 ('self' used before initialization)

*   **問題描述:** 在 `PowerNapViewModel` 的 `init` 方法中，初始化 `sleepDetectionService` 時嘗試傳遞 `self.userAgeGroup`，導致編譯錯誤 `'self' used in property access 'userAgeGroup' before all stored properties are initialized` (Build log 2025-04-23T23-24-41)。
*   **發現時間:** 2025-04-23
*   **嚴重性:** High (阻礙編譯)
*   **狀態:** Resolved (已解決)
*   **分析:** 在 Swift 的 `init` 方法中，所有 `let` 宣告的屬性必須在 `self` 的任何其他屬性被訪問之前完成初始化。在子物件 (sleepDetectionService) 的初始化過程中訪問 `self.userAgeGroup` 違反了此規則。
*   **解決方案:**
    1.  修改 `init` 方法，使 `sleepDetectionService` 先使用一個預設值 (`.adult`) 初始化。
    2.  將 `determineUserAgeGroup()` 方法的調用移至 `init` 方法的末尾，確保所有屬性初始化完畢後再執行。
    3.  `determineUserAgeGroup()` 內部在確定年齡組後，會調用 `sleepDetectionService.updateAgeGroup()` 來同步正確的年齡組。

### 8. ViewModel Actor Isolation Warnings (Swift 6 Concurrency)

*   **問題描述:** `PowerNapViewModel.swift` 中的 `Timer.scheduledTimer` 閉包直接訪問或修改 `@MainActor` 隔離的屬性/方法 (如 `timeRemaining`, `napState`, `notificationService`, `extendedRuntimeManager`, `stopCountdownTimer`)，導致多個警告，提示這在 Swift 6 中將是錯誤 (Build log 2025-04-23T23-29-00)。
*   **發現時間:** 2025-04-23
*   **嚴重性:** Medium (中 - 未來版本兼容性)
*   **狀態:** Resolved (已解決)
*   **分析:** Timer 的閉包默認不在 Main Actor 上執行，直接訪問 Main Actor 隔離的狀態可能導致資料競爭。
*   **解決方案:** 已使用 `Task { @MainActor in ... }` 將閉包內訪問 Main Actor 隔離的屬性/方法的程式碼包裝起來，確保線程安全。

### 9. 未使用的變數警告

*   **問題描述:** `PowerNapViewModel.swift` 中存在未使用的變數，如 `wasAuthorized` (在 `healthKitAuthorizationStatus` sink 中)、`self` (在 `guard let self = self` 中)、`source` (在 `determineUserAgeGroup` 中) (Build log 2025-04-23T23-29-00)。
*   **發現時間:** 2025-04-23
*   **嚴重性:** Low (低)
*   **狀態:** Open (Cleanup - 待清理)
*   **分析:** 這些變數在定義或賦值後未被讀取。
*   **解決方案/後續:** 清理代碼，移除未使用的變數或使用 `_` 替代。

### 10. SettingsView `onChange` API 過時警告

*   **問題描述:** `SettingsView.swift` 中使用的 `onChange(of:perform:)` API 在 watchOS 10.0 中已被棄用 (Build log 2025-04-23T23-29-00)。我們在後續修改中已更新此 API。
*   **發現時間:** 2025-04-23
*   **嚴重性:** Low (低)
*   **狀態:** Resolved (已解決)
*   **分析:** 應使用新版的 `onChange` API。
*   **解決方案:** 已更新為 `onChange(of:initial:_:)`。

### 11. ScrollView contentOffset 性能警告

*   **問題描述:** Console Log 提示 `ScrollView contentOffset binding has been read; this will cause grossly inefficient view performance...` (Console log 2025-04-23)。
*   **發現時間:** 2025-04-23
*   **嚴重性:** Low (低) / Medium (中 - 影響 UI 性能)
*   **狀態:** Open (Optimization - 待優化)
*   **分析:** 在 ScrollView 內部直接讀取 contentOffset 綁定會導致視圖在每次滾動偏移量變化時重新計算，效率低下。
*   **解決方案/後續:** 應將讀取 `contentOffset` 的邏輯移到 ScrollView 外部的視圖中，例如使用 `GeometryReader` 或 `PreferenceKey`。

### 12. Extended Runtime Session 配置錯誤

*   **問題描述:** 嘗試啟動 Extended Runtime Session 時失敗，Console Log 顯示錯誤 `client not approved` 和 `This application does not have an appropriate Info plist key or entitlement to start a session.` (Console log 2025-04-23, 2025-04-24)。
*   **發現時間:** 2025-04-23
*   **嚴重性:** High (高 - 阻塞核心功能)
*   **狀態:** Resolved (已解決)
*   **分析:** App 的 Watch App Target 缺少必要的背景模式聲明，或者 `Info.plist` 結構錯誤導致聲明無效。
*   **解決方案:** 已修正 `powernapv2 Watch App/Info.plist` 文件結構，確保 `WKBackgroundModes` 鍵 (值為 `mindfulness`) 被正確包含在頂層字典中，並在 Target 的 `Signing & Capabilities` 中添加 `Background Modes` 能力且勾選 `Mindfulness` Session Type。運行 Console Log (`2025-04-26T16-37-04`) 已確認 Session 可以成功啟動。

### 13. Crown Sequencer Warning

*   **問題描述:** Console Log 顯示警告 `Crown Sequencer was set up without a view property. This will inevitably lead to incorrect crown indicator states` (Console log 2025-04-24)。
*   **發現時間:** 2025-04-24
*   **嚴重性:** Low (低) / Info (資訊)
*   **狀態:** Open (Needs Observation - 待觀察)
*   **分析:** 通常與數位錶冠的交互有關，可能是 `Picker` 或 `ScrollView` 使用不當導致，也可能是模擬器偽影。
*   **解決方案/後續:** 觀察修改 `SettingsView` 中的 Picker 為 `Stepper` 後此警告是否消失。如果持續存在，再檢查相關視圖的 `.focusable()` 或數位錶冠修飾符。 