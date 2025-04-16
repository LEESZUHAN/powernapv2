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
*   **狀態:** Open (Ignored - 待觀察)
*   **分析:** 這是 Swift 對擴展系統類型添加協議遵循的標準警告。目前用於預覽和調試，不影響功能。
*   **解決方案/後續:** 暫時忽略。未來可考慮使用 `@retroactive` 或移除擴展。

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