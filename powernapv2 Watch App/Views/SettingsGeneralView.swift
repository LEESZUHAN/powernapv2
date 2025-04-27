import SwiftUI
import HealthKit // For HKAuthorizationStatus
import UserNotifications // For UNAuthorizationStatus

struct SettingsGeneralView: View {
    // Get ViewModel from environment
    @EnvironmentObject var viewModel: PowerNapViewModel 

    var body: some View {
        Form { 
            Section("喚醒選項") {
                // Bind toggles to ViewModel properties
                Toggle("音效", isOn: $viewModel.isWakeUpSoundEnabled)
                Toggle("震動", isOn: $viewModel.isWakeUpHapticEnabled)
                // TODO: Add Picker for Haptic Strength later if needed
                // Text("震動強度 Picker Placeholder")
            }

            Section("權限狀態") {
                permissionStatusRow(permissionName: "健康", status: viewModel.healthKitAuthorizationStatus)
                permissionStatusRow(permissionName: "通知", status: viewModel.notificationAuthorizationStatus)
                
                // Show button only if any permission is denied
                if viewModel.healthKitAuthorizationStatus == .sharingDenied || viewModel.notificationAuthorizationStatus == .denied {
                    Button("前往系統設定") {
                        viewModel.openAppSettings()
                    }
                    .font(.footnote)
                    .foregroundColor(.orange)
                }
            }

            Section("其他") {
                 Button("回報/反饋") {
                    viewModel.sendFeedback() // Call ViewModel's feedback method
                 }
            }
        }
        // Add navigation title if run independently, but TabView usually handles titles
        // .navigationTitle("通用設定")
    }
    
    // Helper view for permission status row
    @ViewBuilder
    private func permissionStatusRow(permissionName: String, status: HKAuthorizationStatus) -> some View {
        HStack {
            Text("\(permissionName) 權限:")
            Spacer()
            Text(status.description)
                .foregroundColor(statusColor(for: status))
        }
    }
    
    @ViewBuilder
    private func permissionStatusRow(permissionName: String, status: UNAuthorizationStatus) -> some View {
        HStack {
            Text("\(permissionName) 權限:")
            Spacer()
            Text(status.description)
                .foregroundColor(statusColor(for: status))
        }
    }
    
    // Helper function for status color (could be moved to ViewModel extension or kept here)
    private func statusColor(for status: HKAuthorizationStatus) -> Color {
        switch status {
        case .sharingAuthorized: return .green
        case .sharingDenied: return .red
        default: return .gray
        }
    }

    private func statusColor(for status: UNAuthorizationStatus) -> Color {
        switch status {
        case .authorized, .provisional, .ephemeral: return .green
        case .denied: return .red
        default: return .gray
        }
    }
}
 
#Preview {
    // Preview needs the ViewModel in the environment
    SettingsGeneralView()
        .environmentObject(PowerNapViewModel())
} 