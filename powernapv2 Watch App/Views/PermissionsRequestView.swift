import SwiftUI
import UserNotifications // Needed for UNAuthorizationStatus
import HealthKit // Needed for HKAuthorizationStatus

struct PermissionsRequestView: View {
    // Receive ViewModel and completion handler from the navigation flow
    @EnvironmentObject var viewModel: PowerNapViewModel
    var onComplete: () -> Void 
    
    @State private var isRequestingPermissions = false
    
    var body: some View {
        VStack(spacing: 15) {
            Text("授權請求")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("請點擊下方按鈕以授予權限。您隨時可以在系統「設定」中更改。")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Display current status (reuse from old WelcomeView)
            VStack(spacing: 8) {
                permissionStatusView(permissionName: "通知", status: viewModel.notificationAuthorizationStatus)
                permissionStatusView(permissionName: "健康", status: viewModel.healthKitAuthorizationStatus)
            }
            .padding(.vertical, 5)
            
            // Request Button
            if shouldShowRequestButton() {
                Button("開始授權") {
                    requestPermissionsSequentially()
                }
                .padding(.top, 5)
                .disabled(isRequestingPermissions)
                .overlay { 
                    if isRequestingPermissions {
                        ProgressView()
                    }
                }
            } else if !isRequestingPermissions { 
                // If not requesting and no need to show request button, it means all permissions are determined.
                // Show a button to finish onboarding.
                Button("完成") {
                    onComplete() // Call the completion handler to finish onboarding
                }
                .padding(.top, 10)
                .buttonStyle(.borderedProminent)
            }

            // Go to Settings Button (reuse from old WelcomeView)
            if shouldShowSettingsButton() {
                Button("部分權限未開啟，前往設定？") {
                    viewModel.openAppSettings()
                }
                .font(.caption)
                .foregroundColor(.orange)
                .padding(.top, 5)
            }
        }
        .padding()
        .navigationTitle("請求權限")
        .navigationBarTitleDisplayMode(.inline)
        // Automatically check if onboarding can be completed when status changes
        .onChange(of: viewModel.notificationAuthorizationStatus) { _, _ in checkCompletion() }
        .onChange(of: viewModel.healthKitAuthorizationStatus) { _, _ in checkCompletion() }
    }
    
    // --- Helper Functions (copied/adapted from old WelcomeView) ---

    private func shouldShowRequestButton() -> Bool {
        return viewModel.notificationAuthorizationStatus == .notDetermined || 
               viewModel.healthKitAuthorizationStatus == .notDetermined
    }

    private func shouldShowSettingsButton() -> Bool {
        let notificationDenied = viewModel.notificationAuthorizationStatus == .denied
        let healthKitDenied = viewModel.healthKitAuthorizationStatus == .sharingDenied
        return (notificationDenied || healthKitDenied) && !shouldShowRequestButton()
    }

    private func requestPermissionsSequentially() {
        isRequestingPermissions = true
        
        viewModel.requestNotificationPermission(completion: { [weak viewModel] _, _ in
            guard let viewModel = viewModel else { 
                DispatchQueue.main.async { self.isRequestingPermissions = false }
                return
            }
            
            if viewModel.healthKitAuthorizationStatus == .notDetermined {
                viewModel.requestHealthKitPermission(completion: { _, _ in
                    DispatchQueue.main.async {
                        self.isRequestingPermissions = false
                        // Check completion after HK request finishes
                        self.checkCompletion()
                    }
                })
            } else {
                DispatchQueue.main.async {
                    self.isRequestingPermissions = false
                    // Check completion after notification request finishes (if HK was already set)
                    self.checkCompletion()
                }
            }
        })
    }
    
    // Check if onboarding can be completed (all permissions determined)
    private func checkCompletion() {
        // We only complete automatically if *both* permissions are authorized.
        // If one is denied, the user needs to manually press "完成" or go to settings.
        if viewModel.notificationAuthorizationStatus == .authorized && viewModel.healthKitAuthorizationStatus == .sharingAuthorized {
            print("PermissionsRequestView: Both permissions authorized. Completing onboarding.")
            onComplete()
        } else if viewModel.notificationAuthorizationStatus != .notDetermined && viewModel.healthKitAuthorizationStatus != .notDetermined {
            print("PermissionsRequestView: All permissions determined (but not all authorized). Ready for manual completion.")
            // User can now press the "完成" button.
        }
    }

    // --- Subviews (copied/adapted from old WelcomeView) ---
    
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
    
    @ViewBuilder 
    private func statusTextView(for status: UNAuthorizationStatus) -> some View {
        Text(status.description)
            .foregroundColor(statusColor(for: status))
    }

    @ViewBuilder
    private func statusTextView(for status: HKAuthorizationStatus) -> some View {
        Text(status.description)
            .foregroundColor(statusColor(for: status))
    }
    
    private func statusColor(for status: UNAuthorizationStatus) -> Color {
        switch status {
        case .authorized, .provisional, .ephemeral: return .green
        case .denied: return .red
        case .notDetermined: return .gray
        @unknown default: return .gray
        }
    }
    
    private func statusColor(for status: HKAuthorizationStatus) -> Color {
        switch status {
        case .sharingAuthorized: return .green
        case .sharingDenied: return .red
        case .notDetermined: return .gray
        @unknown default: return .gray
        }
    }
}

// Preview
struct PermissionsRequestView_Previews: PreviewProvider {
    static var previews: some View {
        // Need to provide a ViewModel and a dummy onComplete for preview
        let vm = PowerNapViewModel()
        // Simulate different states for previewing
        // vm.notificationAuthorizationStatus = .denied
        // vm.healthKitAuthorizationStatus = .notDetermined 
        
        NavigationStack {
            PermissionsRequestView(onComplete: { print("Preview Onboarding Complete") })
                .environmentObject(vm)
        }
    }
} 