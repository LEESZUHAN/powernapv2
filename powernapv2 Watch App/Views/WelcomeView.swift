import SwiftUI
import UserNotifications // Needed for UNAuthorizationStatus
import HealthKit // Needed for HKAuthorizationStatus

struct WelcomeView: View {
    // Receive the ViewModel instance from the App level
    @ObservedObject var viewModel: PowerNapViewModel
    
    @State private var isRequestingPermissions = false // State to track if requests are in progress
    
    var body: some View {
        VStack(spacing: 15) { // Reduced spacing slightly
            Text("歡迎使用 PowerNap")
                .font(.title2)
            
            Text("為了準確偵測您的入睡時間，我們需要取得您的「健康」和「通知」權限。")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // --- 權限狀態顯示 ---
            VStack(spacing: 8) {
                permissionStatusView(permissionName: "通知", status: viewModel.notificationAuthorizationStatus)
                permissionStatusView(permissionName: "健康", status: viewModel.healthKitAuthorizationStatus)
            }
            .padding(.vertical, 5)

            // --- 授權按鈕 --- 
            if shouldShowRequestButton() {
                Button("開始授權") {
                    requestPermissionsSequentially()
                }
                .padding(.top, 5)
                .disabled(isRequestingPermissions) // Disable button while requesting
                .overlay { // Show spinner when requesting
                    if isRequestingPermissions {
                        ProgressView()
                    }
                }
            }
            
            // --- 前往設定按鈕 --- 
            if shouldShowSettingsButton() {
                Button("部分權限未開啟，前往設定？") {
                    viewModel.openAppSettings()
                }
                .font(.caption)
                .foregroundColor(.orange) // Make it more noticeable 
                .padding(.top, 5)
            }
            
        }
        .padding()
        // Use .task for async operations tied to the view's lifecycle
        .task {
            // Optionally check permissions when the view appears if needed,
            // but ViewModel already does this in init.
            // viewModel.checkInitialPermissions() // ViewModel init calls this
        }
    }
    
    // --- Helper Functions ---
    
    // Determines if the main request button should be shown
    private func shouldShowRequestButton() -> Bool {
        // Show if either permission is not determined
        return viewModel.notificationAuthorizationStatus == .notDetermined || 
               viewModel.healthKitAuthorizationStatus == .notDetermined
    }
    
    // Determines if the 'Go to Settings' button should be shown
    private func shouldShowSettingsButton() -> Bool {
        // Show if either permission is denied, but not if we should show the main request button
        let notificationDenied = viewModel.notificationAuthorizationStatus == .denied
        let healthKitDenied = viewModel.healthKitAuthorizationStatus == .sharingDenied
        return (notificationDenied || healthKitDenied) && !shouldShowRequestButton()
    }
    
    // Request permissions one after the other
    private func requestPermissionsSequentially() {
        isRequestingPermissions = true
        
        viewModel.requestNotificationPermission(completion: { [weak viewModel] _, _ in
            // After notification request finishes (regardless of outcome),
            // request HealthKit permission if it's not determined yet.
            // Ensure viewModel is still valid.
            guard let viewModel = viewModel else { 
                DispatchQueue.main.async { self.isRequestingPermissions = false }
                return
            }
            
            // Check HealthKit status *after* notification request completes
            if viewModel.healthKitAuthorizationStatus == .notDetermined {
                viewModel.requestHealthKitPermission(completion: { _, _ in
                    // Both requests are now complete
                    DispatchQueue.main.async {
                        self.isRequestingPermissions = false
                    }
                })
            } else {
                // HealthKit permission was already determined, just finish
                DispatchQueue.main.async {
                    self.isRequestingPermissions = false
                }
            }
        })
    }

    // --- Subviews ---
    
    // Updated permissionStatusView to accept the actual enum types
    @ViewBuilder
    private func permissionStatusView(permissionName: String, status: UNAuthorizationStatus) -> some View {
        HStack {
            Text("\(permissionName) 權限:")
            Spacer()
            statusTextView(for: status)
        }
        .font(.caption)
    }
    
    @ViewBuilder
    private func permissionStatusView(permissionName: String, status: HKAuthorizationStatus) -> some View {
        HStack {
            Text("\(permissionName) 權限:")
            Spacer()
            statusTextView(for: status)
        }
        .font(.caption)
    }
    
    // Creates the Text view for the status with appropriate color
    @ViewBuilder 
    private func statusTextView(for status: UNAuthorizationStatus) -> some View {
        Text(status.description) // Using the CustomStringConvertible extension
            .foregroundColor(statusColor(for: status))
    }

    @ViewBuilder
    private func statusTextView(for status: HKAuthorizationStatus) -> some View {
        Text(status.description) // Using the CustomStringConvertible extension
            .foregroundColor(statusColor(for: status))
    }
    
    // Updated statusColor functions for enum types
    private func statusColor(for status: UNAuthorizationStatus) -> Color {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .gray
        @unknown default:
            return .gray
        }
    }
    
    private func statusColor(for status: HKAuthorizationStatus) -> Color {
        switch status {
        case .sharingAuthorized:
            return .green
        case .sharingDenied:
            return .red
        case .notDetermined:
            return .gray
        @unknown default:
            return .gray
        }
    }
}

// 預覽 (Preview)
struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView(viewModel: PowerNapViewModel())
    }
}

// 為了讓 Preview 中的 description 更易讀，可以添加擴展 (可選)
extension UNAuthorizationStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notDetermined: return "未決定"
        case .denied: return "已拒絕"
        case .authorized: return "已授權"
        case .provisional: return "臨時授權"
        case .ephemeral: return "短暫授權"
        @unknown default:
            return "未知狀態"
        }
    }
}

extension HKAuthorizationStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notDetermined: return "未決定"
        case .sharingDenied: return "已拒絕"
        case .sharingAuthorized: return "已授權"
        @unknown default:
            return "未知狀態"
        }
    }
} 