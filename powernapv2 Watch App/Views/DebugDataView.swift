#if DEBUG // Only include this View in Debug builds
import SwiftUI
import HealthKit
import UserNotifications

struct DebugDataView: View {
    @EnvironmentObject var viewModel: PowerNapViewModel // Example injection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                Text("Debug Information").font(.headline).padding(.bottom, 5)
                
                Group {
                    Text("Nap State: \(viewModel.napState.description)")
                    Text("Sleep State: \(viewModel.sleepState.description)")
                }.padding(.bottom, 3)
                
                Divider()
                
                Group {
                    Text("HR: \(formatDouble(viewModel.heartRate)) bpm")
                    Text("RHR: \(formatDouble(viewModel.restingHeartRate)) bpm")
                    Text(viewModel.debugSleepThresholdInfo) // Already formatted
                    Text("Motion Level: \(formatDouble(viewModel.motionLevel, precision: 3))")
                }.padding(.bottom, 3)
                
                Divider()
                
                Group {
                    Text("Timer Running: \(viewModel.isTimerRunning ? "Yes" : "No")")
                    Text("Time Remaining: \(viewModel.timeRemainingFormatted)") // Use formatted time
                    Text("Selected Duration: \(viewModel.selectedNapDuration) min")
                }.padding(.bottom, 3)
                
                Divider()
                
                Group {
                    Text("Age Group: \(viewModel.userAgeGroup.rawValue)")
                    Text("Threshold Adjust: \(String(format: "%+.1f%%", viewModel.thresholdAdjustmentPercentageOffset * 100))")
                }.padding(.bottom, 3)
                
                Divider()
                
                Group {
                    Text("HK Auth: \(viewModel.healthKitAuthorizationStatus.description)")
                    Text("UN Auth: \(viewModel.notificationAuthorizationStatus.description)")
                    Text("Sound Enabled: \(viewModel.isWakeUpSoundEnabled ? "Yes" : "No")")
                    Text("Haptic Enabled: \(viewModel.isWakeUpHapticEnabled ? "Yes" : "No")")
                }.padding(.bottom, 3)
                
                Divider()
                
                Group {
                     Text("Ext Runtime Session: \(viewModel.isSessionRunning ? "Running" : "Stopped")")
                }
                
            }
            .padding()
        }
        // Add navigation title if run independently, but TabView usually handles titles
        // .navigationTitle("Debug") 
    }
    
    // Helper to format optional Doubles
    private func formatDouble(_ value: Double?, precision: Int = 1) -> String {
        guard let value = value else { return "N/A" }
        return String(format: "%.\(precision)f", value)
    }
}

#Preview {
    DebugDataView()
        .environmentObject(PowerNapViewModel()) // Provide dummy VM for preview
}

#endif // End of #if DEBUG 