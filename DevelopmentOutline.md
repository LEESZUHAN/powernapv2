# PowerNap 新專案開發大綱

## 開發策略與核心原則

鑑於先前專案遇到的頑固建置問題（詳見《PowerNapXcodeDebugGuide.md》），本次採用**全新 Xcode 專案**從零開始開發，以確保專案的健康與穩定。

**核心開發原則：**

1.  **遵循最佳實踐：** 嚴格遵循《PowerNapXcodeDebugGuide.md》中總結的最佳實踐，特別是在：
    *   **共享類型管理：** 確保如 `AgeGroup` 等共享類型擁有單一來源檔案，並正確設定 Target Membership。
    *   **依賴注入：** 在 ViewModel 初始化時，於 `init` 方法內部創建服務實例，避免在參數預設值中使用 Actor 隔離類型。
    *   **架構清晰：** 維持 ViewModel 管理 Services 的單向依賴關係。
2.  **階段化推進：** 按照本文件定義的階段順序開發，先建立基礎架構和核心服務，再逐步實現複雜功能和 UI。
3.  **優先權限與引導：** 首先完成第一階段的權限管理與引導流程，這是 App 的基礎門檻，也是相對獨立的模塊。
4.  **謹慎處理核心算法：** 在基礎穩定後，再實現第二階段的核心睡眠偵測算法，特別是個人化模型部分。
5.  **持續測試：** 在每個功能點或小階段完成後進行充分測試，特別是核心算法和邊界情況。
6.  **關注效能：** 電池消耗和背景執行效率是 WatchOS App 的關鍵，需貫穿整個開發過程。

---

## 第一階段：專案架構、核心服務與權限引導

1.  **專案基礎設置**
    *   建立新的 Apple Watch 應用專案 (Watch-only App)。
    *   設置基本 SwiftUI UI 框架 (`ContentView`, `PowerNapApp`)。
    *   定義基礎資料模型 (如 `NapState`, `SleepState` 等)。
    *   **建立共享類型單一來源：** 創建 `SharedModels` 或類似資料夾，定義 `AgeGroup.swift`（參考 `PowerNapXcodeDebugGuide.md` 的範例），確保其 Target Membership 正確。

2.  **核心服務層實現 (基礎)**
    *   **`HealthKitService`:**
        *   實現 HealthKit 連接和基礎設定。
        *   實現請求 HealthKit 權限的邏輯（讀取心率、靜息心率；寫入睡眠分析）。
        *   實現獲取心率 (`HKQuantityTypeIdentifierHeartRate`) 和靜息心率 (`HKQuantityTypeIdentifierRestingHeartRate`) 的基本方法。
        *   實現寫入睡眠分析樣本 (`HKCategoryTypeIdentifierSleepAnalysis`) 的基本方法。
    *   **`MotionService`:**
        *   實現 CoreMotion 連接和基礎設定 (`CMMotionManager`)。
        *   實現請求運動權限的邏輯（如果需要特定數據類型）。
        *   實現獲取加速度數據的方法。
    *   **`NotificationService`:**
        *   實現 UNUserNotificationCenter 基礎設定。
        *   實現請求通知權限的邏輯。
    *   **`PermissionManager` (或整合至各服務/ViewModel):**
        *   設計用於統一管理和檢查 HealthKit、通知等權限狀態的機制。
        *   提供檢查權限狀態的接口。

3.  **權限管理與引導流程**
    *   **首次啟動歡迎畫面 (`WelcomeView` 或類似視圖):**
        *   簡要介紹 PowerNap 功能。
        *   清晰解釋為何需要「通知」和「健康」權限。
        *   提供按鈕觸發權限請求流程。
    *   **實現權限請求流程:**
        *   使用 `PermissionManager` 或直接調用各服務的權限請求方法。
        *   **依序**請求權限（例如，先通知，再健康）。
        *   根據權限請求結果更新 UI 或引導流程。
    *   **處理不同權限狀態:**
        *   在歡迎畫面或主畫面顯示當前的權限狀態（已授權、已拒絕、未決定）。
        *   如果權限被拒絕，提供清晰的引導，提示用戶前往系統設定開啟（可參考 `PowerNapViewModel` 中 `sendFeedback` 使用 `WKExtension.openSystemURL` 的 `#selector` 方式實現跳轉，注意這需要在 watchOS 上運行）。
    *   **每次啟動時的權限檢查:**
        *   在 App 啟動時 (如 `PowerNapApp` 或主 ViewModel 的 `init`) 檢查權限狀態。
        *   如果權限缺失，考慮顯示提示或引導用戶重新授權。

4.  **基礎 ViewModel**
    *   **`PowerNapViewModel` (或其他主 ViewModel):**
        *   初始化核心服務（遵循 `PowerNapXcodeDebugGuide.md` 的依賴注入最佳實踐）。
        *   管理權限狀態和引導流程的 UI 邏輯。
        *   建立 Combine 綁定以接收服務發布的基礎數據（如權限狀態）。

## 第二階段：核心睡眠監測演算法

1.  **心率與活動監測**
    *   **`HealthKitService`:** 穩定獲取和發布 (Publish) 即時心率和緩存的靜息心率。
    *   **`MotionService`:** 處理加速度數據，判斷用戶是否處於靜止狀態，計算動作級別，並發布相關狀態 (`isStill`, `motionLevel`)。
    *   **`SleepDetectionService`:**
        *   持有 `HealthKitService` 和 `MotionService` 的實例。
        *   訂閱心率和動作數據。

2.  **睡眠偵測邏輯 (`SleepDetectionService`)**
    *   實現基於**年齡組 (`AgeGroup`)** 和**靜息心率 (RHR)** 計算**動態心率閾值**的邏輯 (參考 `HeartRateAlgorithmGuideline.md`)。
        *   需要從 `HealthKitService` 獲取 RHR，並需要一種方式獲取或設定用戶的 `AgeGroup`（這部分 UI 將在第四階段實現，初期可使用預設值）。
    *   整合**心率條件**（低於動態閾值 + 持續時間達標，參考 `HeartRateAlgorithmGuideline.md` 的時間窗）和**活動條件**（持續靜止）。
    *   實現入睡偵測狀態機 (`SleepState`: awake, potentialSleep, asleep, disturbed)。
    *   發布 (`@Published`) 當前的 `SleepState` 和偵測到的 `sleepStartTime`。
    *   處理特殊情況（如 RHR 極低，參考指南）。

3.  **個人化心率模型 (策略)**
    *   **數據記錄 (`HealthKitService`)：** 確立在 `SleepDetectionService` 判定用戶進入 `.asleep` 狀態後，調用 `HealthKitService` 記錄一個對應時間段的 `HKCategorySample`（標記為午睡）到 HealthKit 的機制。**此階段僅確立機制，不實現模型學習。**
    *   **`PersonalizedHRModelService` (框架):**
        *   創建服務框架，定義學習和應用優化閾值的方法接口。
        *   **此階段不實現具體的學習算法**，僅搭建框架，預留接口。

4. **ViewModel 整合**
    *   **`PowerNapViewModel`:**
        *   初始化 `SleepDetectionService` 和 `PersonalizedHRModelService`。
        *   訂閱 `SleepDetectionService` 發布的 `SleepState` 和 `sleepStartTime`。
        *   訂閱 `HealthKitService` 和 `MotionService` 發布的心率、動作數據，用於 UI 展示。

## 第三階段：計時與喚醒功能

1.  **計時選項界面**
    *   在主視圖或設定視圖中，開發 1-30 分鐘範圍的滾輪選擇器 (Picker) 或其他 UI 元件。
    *   使用 `UserDefaults` 或其他持久化方式儲存用戶選擇的計時時長 (`selectedDuration`)。

2.  **倒數計時機制 (`PowerNapViewModel`)**
    *   實現計時器邏輯 (`Timer`)。
    *   **啟動邏輯：**
        *   **選項1 (預設)：** 訂閱 `SleepDetectionService` 的 `SleepState`，在狀態變為 `.asleep` 後自動啟動計時器。
        *   **選項2 (備用/可配置)：** 如果睡眠偵測被禁用（未來可加入此設定），則在用戶點擊開始按鈕後立即啟動計時器。
    *   管理計時器狀態（運行中、暫停、停止）。
    *   發布 (`@Published`) 剩餘時間 (`timeRemaining`) 和進度 (`progress`)，用於 UI 更新。

3.  **喚醒通知 (`NotificationService`)**
    *   完成 UNUserNotificationCenter 的配置，確保通知權限已請求。
    *   實現發送本地通知的方法，在計時結束時觸發。
    *   **加入可配置的喚醒震動：**
        *   根據用戶在設定中選擇的強度 (`hapticStrength`，存儲於 `UserDefaults`)，選擇不同的 `WKHapticType` 或自定義震動模式。
    *   **加入可選的喚醒聲音：**
        *   根據用戶設定 (`soundEnabled`) 決定是否在通知中包含聲音 (`UNNotificationSound`)。
    *   確保通知是時間敏感的 (`interruptionLevel = .timeSensitive`)，以便在勿擾模式下也能提醒。

4.  **背景執行**
    *   **`ExtendedRuntimeManager`:**
        *   實現 `WKExtendedRuntimeSession` 的配置和管理。
        *   在開始睡眠偵測或計時器時啟動 Session，確保 App 在背景持續運行以收集數據和計時。
        *   在會話結束或停止時正確結束 Session。
    *   **整合:** 在 `PowerNapViewModel` 的 `startNap` 和 `stopNap` (或 `completeNap`) 方法中調用 `ExtendedRuntimeManager`。

## 第四階段：UI/UX 設計與核心功能完善

1.  **主介面 (`PowerNapView`) 設計與實現**
    *   **狀態顯示：** 清晰顯示 App 當前狀態（等待、監測中、睡眠中、計時中、暫停、已完成）。
    *   **核心數據展示：** 顯示即時心率、靜息心率（或與閾值的關係）、動作狀態（靜止/活動）、睡眠狀態 (`SleepState`)。
    *   **計時器顯示：** 顯示剩餘時間（格式化）、進度條。
    *   **控制按鈕：** 開始、暫停/繼續、停止按鈕，根據當前狀態啟用/禁用。
    *   **權限狀態與引導：** 在主界面或易於訪問的地方（如設定頁）顯示通知和健康權限的狀態，並提供跳轉到系統設定的按鈕（如果權限被拒絕）。

2.  **設定界面 (`SettingsView`)**
    *   **計時時長選擇：** 實現第三階段設計的滾輪選擇器。
    *   **喚醒設定：**
        *   震動強度選擇 (Segmented Picker 或類似)。
        *   聲音開關 (Toggle)。
    *   **睡眠偵測開關 (Toggle，可選)：** 允許用戶完全禁用睡眠偵測，僅使用手動計時。
    *   **年齡組處理：**
        *   **`AgeGroupService` (或整合入 `HealthKitService` / `PowerNapViewModel`):** 嘗試從 HealthKit 讀取用戶出生日期以自動確定 `AgeGroup`。
        *   **UI 邏輯：** *僅當*無法從 HealthKit 自動獲取年齡時，才顯示手動選擇年齡組的 Picker（青少年/成人/銀髮族）。將選擇結果存儲起來（例如 `UserDefaults`）。
        *   提供一個選項，允許用戶**總是**手動設定年齡組，以覆蓋 HealthKit 的自動判定結果。
    *   **個人化模型微調入口 (預留):** 添加按鈕或區域，用於未來進入個人化心率模型閾值微調界面（第五階段實現）。
    *   **反饋按鈕：** 保留發送反饋的功能。

3.  **個人化心率模型實現 (`PersonalizedHRModelService`)**
    *   **模型學習邏輯:**
        *   實現定期（例如，每收集 N 次有效的 Power Nap 數據後）或手動觸發模型更新的機制。
        *   讀取 HealthKit 中**白天**標記為午睡的睡眠分析樣本。
        *   獲取這些時段內的**原始心率樣本**。
        *   根據 `HeartRateAlgorithmGuideline.md` 中的策略，分析心率數據（平均、最低、變異性等）。
        *   計算並存儲**優化的心率閾值比例** (`optimizedThresholdPercentage`)。
    *   **應用閾值:**
        *   `SleepDetectionService` 應能從 `PersonalizedHRModelService` 獲取優化的閾值比例，並優先使用它（如果存在）來計算動態心率閾值，否則使用基於年齡組的預設值。
    *   **數據存儲:** 選擇合適的方式存儲模型學習的結果（如 `UserDefaults` 或 Core Data）。

4. **交互與體驗優化**
    *   優化啟動、暫停、停止流程的流暢度和反饋。
    *   提供清晰的錯誤提示（如 HealthKit 訪問失敗、計時器啟動失敗等）。

5. **視覺識別 (初步)**
    *   設計 App Icon。
    *   確定基本配色和風格。

## 第五階段：進階功能、測試與優化

1. **個人化閾值微調界面**
    *   創建一個新的視圖，允許用戶查看當前個人化模型計算出的閾值（或與 RHR 的比例）。
    *   提供滑塊或步進器，允許用戶在模型計算結果的基礎上進行**微調**（例如，增加/減少一個百分比），給予用戶最終控制權。將用戶的微調偏好存儲起來。
    *   `SleepDetectionService` 在應用閾值時，應考慮用戶的微調設置。

2. **錶盤複雜功能 (Complication)**
    *   設計並實現 Complication (例如，圖文、進度條樣式)。
    *   顯示關鍵信息，如計時剩餘時間、App 狀態或快速啟動按鈕。
    *   確保 Complication 按時更新。

3. **功能與可用性測試**
    *   **重點測試權限流程：** 所有路徑（首次、拒絕、重授權、中途撤銷）。
    *   **重點測試睡眠檢測算法：** 不同年齡組、不同環境下的準確性；預設閾值和個人化閾值的效果。
    *   **重點測試個人化模型：** 數據記錄是否正確、模型更新是否觸發、閾值計算是否合理、用戶微調是否生效。
    *   驗證計時和喚醒的可靠性（包括時間敏感通知）。
    *   測試背景執行 (`ExtendedRuntimeSession`) 的穩定性和電池影響。
    *   檢查 UI 在不同 Apple Watch 型號和尺寸上的表現。

4. **效能與穩定性優化**
    *   使用 Instruments 等工具分析電池消耗和 CPU 使用情況，特別是在背景監測期間。
    *   優化 HealthKit 和 CoreMotion 的查詢頻率和數據處理邏輯。
    *   進行壓力測試和長時間運行測試，檢查內存洩漏和穩定性。

5. **使用者測試 (TestFlight)**
    *   發布 Beta 版本給測試用戶。
    *   收集真實反饋，特別關注睡眠檢測準確度、個人化閾值的效果以及喚醒體驗。
    *   根據反饋迭代調整算法參數和 UI/UX。

## 第六階段：發布準備與可選增強

1. **發布準備**
    *   完善 App Store 頁面信息（描述、截圖、關鍵字）。
    *   確保符合最新的 App Store 審核指南，特別是關於健康數據和背景模式的部分。
    *   最終測試和錯誤修復。

2. **可選增強功能 (根據時間和資源決定)**
    *   **數據統計與分析：** 如歷史小睡記錄、平均入睡時間、睡眠心率趨勢圖等。
    *   **更多個人化設定：** 如自定義喚醒聲音上傳、運動員模式（可能採用不同的閾值邏輯）。
    *   **進階整合：** 與 iPhone App 的數據同步或控制。
    *   **視覺設計強化：** 多主題、更精緻的動畫效果等。

## 硬體兼容性測試計劃

*   **目標最低支援**：Apple Watch Series 6+ (或根據實際情況調整)
*   **主要開發與測試環境**：優先使用較新的實機（如 Series 9）完成功能開發和主要測試。
*   **兼容性測試**：在功能穩定後，使用目標最低支援的實機（如果可能）和各種模擬器測試基本功能和 UI 適配。
*   **重點測試**：內存使用、UI 響應性、算法執行時間、電池消耗在不同硬體上的表現。

---

## 開發進度追蹤 (新專案)

### 第一階段
- [ ] 專案基礎設置 (新專案建立、基本 SwiftUI 框架)
- [ ] 基礎資料模型定義 (`NapState`, `SleepState`, `AgeGroup` 等共享類型)
- [ ] 核心服務層實現 (HealthKit, Motion, Notification 基礎框架和權限請求)
- [ ] `PermissionManager` 或等效機制實現
- [ ] 權限管理與引導流程 UI (`WelcomeView`, 狀態顯示, 跳轉設定)
- [ ] 首次啟動權限檢查邏輯
- [ ] 基礎 `PowerNapViewModel` (服務初始化, 權限管理邏輯)

### 第二階段
- [ ] `HealthKitService` 穩定獲取與發布 HR/RHR
- [ ] `MotionService` 穩定獲取與發布靜止/動作狀態
- [ ] `SleepDetectionService` 框架與數據訂閱
- [ ] 動態心率閾值計算邏輯 (基於 AgeGroup 和 RHR)
- [ ] 睡眠偵測狀態機與核心邏輯 (`SleepState` 判定)
- [ ] 特殊情況處理 (低 RHR)
- [ ] `HealthKitService` 實現記錄午睡樣本的接口
- [ ] `PersonalizedHRModelService` 服務框架建立
- [ ] `PowerNapViewModel` 整合睡眠偵測狀態和數據展示

### 第三階段
- [ ] 計時選項 UI (滾輪等)
- [ ] `UserDefaults` 存儲用戶設定 (時長, 震動, 聲音)
- [ ] `PowerNapViewModel` 倒數計時邏輯 (`Timer`)
- [ ] 計時器自動啟動邏輯 (基於 `SleepState`)
- [ ] 計時器手動啟動邏輯 (如果實現睡眠偵測禁用選項)
- [ ] `NotificationService` 發送本地通知
- [ ] 可配置震動強度實現
- [ ] 可選喚醒聲音實現
- [ ] 時間敏感通知設定
- [ ] `ExtendedRuntimeManager` 實現與整合

### 第四階段
- [ ] 主介面 `PowerNapView` 完整 UI 與狀態顯示
- [ ] 核心數據展示完善 (HR, RHR, Motion, SleepState)
- [ ] 計時器 UI (剩餘時間, 進度條)
- [ ] 控制按鈕邏輯 (Start, Pause, Resume, Stop)
- [ ] 設定界面 `SettingsView` 佈局
- [ ] 設定項實現 (時長, 震動, 聲音, 可選的睡眠偵測開關)
- [ ] 年齡組自動獲取與手動選擇/覆蓋邏輯及 UI
- [ ] `PersonalizedHRModelService` 模型學習與閾值計算邏輯實現
- [ ] `SleepDetectionService` 集成並應用個人化閾值
- [ ] 交互與體驗優化 (流程反饋, 錯誤處理)
- [ ] App Icon 設計與基本配色

### 第五階段
- [ ] 個人化閾值微調界面 UI 與邏輯
- [ ] `SleepDetectionService` 應用用戶微調閾值
- [ ] Complication 設計與實現
- [ ] Complication 更新邏輯
- [ ] 全面功能與可用性測試 (按測試點)
- [ ] 效能與穩定性分析及優化 (Instruments)
- [ ] 電池消耗測試
- [ ] TestFlight 發布與用戶反饋收集
- [ ] 根據反饋進行迭代調整

### 第六階段
- [ ] App Store 頁面準備
- [ ] App Store 審核指南符合性檢查
- [ ] 最終測試與 Bug 修復
- [ ] (可選) 增強功能開發 (數據統計, 更多設定等)

## 里程碑 (新專案)

1.  **基礎架構與權限版本 (Milestone 1)** - 完成第一階段，App 可以請求權限、顯示引導、核心服務框架建立。
2.  **核心睡眠偵測版本 (Milestone 2)** - 完成第二階段，實現基於預設閾值的睡眠偵測核心邏輯。
3.  **計時與喚醒版本 (Milestone 3)** - 完成第三階段，實現完整的計時、喚醒和背景執行功能。
4.  **完整功能與個人化初版 (Milestone 4)** - 完成第四階段，包含主要 UI、設定、個人化模型學習與應用。
5.  **Beta 測試版本 (Milestone 5)** - 完成第五階段的大部分內容，包含進階功能（微調、Complication），經過內部測試和優化，準備 TestFlight。
6.  **發布候選版本 (Release Candidate)** - 完成所有核心功能、測試、優化和 App Store 準備工作。

## 注意事項

*   **時刻參考《PowerNapXcodeDebugGuide.md》** 中的最佳實踐，避免重蹈覆轍。
*   技術難點仍在於睡眠偵測演算法的準確性、個人化模型的有效性以及背景執行的穩定性和功耗。
*   保持程式碼模塊化和清晰的職責劃分。
*   積極使用版本控制 (Git)，頻繁提交小的、功能完整的變更。 