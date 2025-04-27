# PowerNap v2 專案審查與優化建議（o4mini Review）

## 一、專案結構與模組化

- 目前各功能已分為 Service、ViewModel、Shared Models 等目錄，結構清晰。
- 建議：
  - 再細分 Service 層，如 HealthKitService、MotionService 可獨立成模組（或 framework）。
  - 將 SharedModels 再依領域（如 AgeGroup、NapState）分組，易於維護與擴展。
  - 考慮將常量、enum、協定放在一個 `Core` 或 `Common` 資料夾。

## 二、MVVM 與 ViewModel

- ViewModel 專責狀態管理與業務流程，已使用 Combine 綁定狀態。
- 建議：
  - 避免在 init 做過多邏輯（如呼叫 HealthKitService 授權、ExtendedRuntime 啟動），改成明確的 `start()` 方法觸發。
  - 增加對錯誤與 loading 狀態的 @Published 屬性，提供 View 完整回饋。
  - 使用依賴注入（Dependency Injection）傳入 services，方便測試與替換。

## 三、Service 層設計

- HealthKitService 與 MotionService 負責平台 API 呼叫，實現清楚。
- 建議：
  - 為每個 service 增加錯誤型別（`enum ServiceError: Error`），統一 error handling。
  - 將異步 API 改用 `async/await` 回傳結果，頂層 ViewModel 負責錯誤顯示。
  - 加入重試機制（如 HealthKit 授權重試）或超時設置。

## 四、睡眠偵測演算法

- SleepDetectionService 已依年齡組別區分閾值，邏輯清晰。
- 建議：
  - 抽象演算法參數（threshold、duration）成可注入策略，便於 A/B 測試或調整。
  - 為核心演算法撰寫單元測試，模擬不同年齡、心率、動作序列，驗證判定正確率。
  - 分離資料收集與演算法執行，避免 service 內部過度耦合。

## 五、ExtendedRuntimeManager

- 目前預設使用 workout category，可滿足持續收集需求。
- 建議：
  - 顯式在程式碼中指定 `WKExtendedRuntimeSession(category: .workout)`，增加可讀性。
  - 在 delegate callback 中，將過期、失效原因回傳 ViewModel，由 UI 或通知中心決定後續動作。

## 六、UI 層與 SwiftUI 實現

- UI 尚未完成，建議：
  - 先產出界面原型（Wireframe），定義主要畫面：倒數計時、睡眠狀態、通知設定、歷史數據。
  - 遵循 SwiftUI 組件化原則，將常用視圖拆成重用 component。
  - 考慮 Accessibility（VoiceOver、動態字級）、深色模式支援。
  - UI 狀態應綁定 ViewModel 的 loading、error、data 屬性。

## 七、簽名與權限管理

- 授權流程與 Capabilities 已大致完成。
- 建議：
  - 將所有 entitlement 與 Info.plist 欄位集中管理在文檔中，並加入 CI 檢查腳本驗證。
  - 確保 HealthKit、Background Modes 及相關 entitlement 在各 target（App／App Extension）一致。

## 八、測試與 CI/CD

- 目前尚未架構測試。
- 建議：
  - 建立 Unit Tests 目錄，撰寫核心邏輯（AgeGroup、SleepDetection、Service 呼叫）的單元測試。
  - 使用 Xcode Scheme 區分 Release、Debug，並在 CI（如 GitHub Actions、Fastlane）自動執行測試。
  - 建立簡易 UI Tests，檢查畫面流程。

## 九、日誌與除錯

- 建議：
  - 引入統一日誌框架（如 Apple 的 `os.log`），分等級輸出 debug、info、error 資訊。
  - 考慮使用斷言（assert）或 precondition 驗證不變式。

## 十、命名規範與程式碼風格

- 建議：
  - 使用 SwiftLint 依照官方 Swift API Design Guideline 進行風格檢查。
  - 函式、變數命名保持一致，如 `startNap()`, `stopNap()`, `determineUserAgeGroup()`。
  - 把 magic number（如心率閾值、最短持續時間）集中放在常量或設定檔中。

## 十一、下一步規劃

1. 完成 UI 主要畫面，並整合 ViewModel 資料綁定。
2. 撰寫單元測試與 UI 測試，確保核心功能穩定。
3. 性能分析（Profile CPU／Memory），避免長時間背景運行耗電過快。
4. 使用者研究與反饋，優化睡眠偵測準確度與使用體驗。 