import SwiftUI

struct SettingsAgeThresholdView: View {
    // Get ViewModel from environment
    @EnvironmentObject var viewModel: PowerNapViewModel 
    
    // Local state for the slider, representing steps (-5 to +5)
    // Initialize it based on the ViewModel's percentage offset
    @State private var adjustmentSteps: Double = 0
    
    // Define the range and step for the adjustment (e.g., +/- 5% in 1% steps)
    let adjustmentRange: ClosedRange<Double> = -5...5
    let step: Double = 1
    let percentagePerStep: Double = 0.01 // Each step represents 1%

    var body: some View {
        Form { 
            Section("年齡組") {
                // Bind Picker directly to viewModel's userAgeGroup
                Picker("選擇年齡組", selection: $viewModel.userAgeGroup) {
                    ForEach(AgeGroup.allCases, id: \.self) { group in
                        Text(group.rawValue) // Display rawValue directly
                            .tag(group) // Ensure the tag matches the enum case
                    }
                }
                .onChange(of: viewModel.userAgeGroup) { _, newGroup in
                     // Call ViewModel's update function when manually changed
                     viewModel.updateManualAgeGroup(newGroup)
                }
                 Text("App 會嘗試自動偵測，您可在此手動覆蓋。")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }

            Section("睡眠判定調整 (\(adjustmentSteps > 0 ? "+" : "")\(Int(adjustmentSteps))%)") {
                 // Bind Slider to the local adjustmentSteps state
                 Slider(value: $adjustmentSteps, in: adjustmentRange, step: step)
                    .onChange(of: adjustmentSteps) { _, newValue in
                         // Convert steps back to percentage offset and update ViewModel
                         let percentageOffset = newValue * percentagePerStep
                         viewModel.updateThresholdAdjustment(percentageOffset)
                    }
                    
                HStack {
                    Text("判定較嚴格")
                    Spacer()
                    Text("判定較寬鬆")
                }
                .font(.caption)
                .foregroundColor(.gray)
                
                Text("提示：若 App 難以偵測入睡，請向右調整 (寬鬆)；若容易誤判，請向左調整 (嚴格)。")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            // Initialize the slider position based on the current ViewModel value
            let initialOffset = viewModel.thresholdAdjustmentPercentageOffset
            adjustmentSteps = round(initialOffset / percentagePerStep) // Convert offset back to steps
        }
        // Add navigation title if run independently, but TabView usually handles titles
        // .navigationTitle("年齡與閾值") 
    }
}

#Preview {
    // Preview needs the ViewModel in the environment
    SettingsAgeThresholdView()
        .environmentObject(PowerNapViewModel())
}

// Add Previews if desired
// Requires defining AgeGroup enum and its cases for preview to work
/*
enum AgeGroup: String, CaseIterable {
    case teen = "青少年"
    case adult = "成人"
    case senior = "銀髮族"
}
*/
 
 