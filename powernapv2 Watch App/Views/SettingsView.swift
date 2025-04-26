import SwiftUI

struct SettingsView: View {
    // Inject the ViewModel from the environment
    @EnvironmentObject var viewModel: PowerNapViewModel
    
    // Stepper 的範圍
    private let durationRange = 1...30

    var body: some View {
        // Use List or ScrollView for potentially longer content
        List { // Using List provides standard watchOS styling for settings
            Section {
                // Use Stepper for duration selection
                Stepper("\(viewModel.selectedNapDuration) 分鐘", value: $viewModel.selectedNapDuration, in: durationRange)
                    .sensoryFeedback(.increase, trigger: viewModel.selectedNapDuration) // Add haptic feedback
                    
            } header: {
                 Text("小睡時長")
                    .font(.headline) // Keep headline style for section
            }

            Section {
                Picker("選擇年齡組", selection: $viewModel.userAgeGroup) {
                    ForEach(AgeGroup.allCases) { ageGroup in
                        Text(ageGroup.rawValue).tag(ageGroup)
                    }
                }
                // NavigationLink style is good for Picker with enums
                .pickerStyle(.navigationLink)
                .onChange(of: viewModel.userAgeGroup) { oldValue, newValue in // Use updated onChange
                     print("SettingsView: Picker 選擇變更 (\(newValue))，調用 updateManualAgeGroup")
                     viewModel.updateManualAgeGroup(newValue)
                }
                Text("此設定會影響睡眠偵測的判斷標準。")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .listRowBackground(Color.clear) // Make background clear if needed

            } header: {
                 Text("年齡組")
                    .font(.headline)
            }

            // TODO: Add controls for Haptics and Sound later
            // Section("喚醒設定") { ... }

        }
        .navigationTitle("設定")
        // Handle the deprecated onChange warning by using the new version
        // (Applied directly to the Picker above)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { // Wrap in NavigationStack for preview
             SettingsView()
                .environmentObject(PowerNapViewModel())
        }
    }
} 