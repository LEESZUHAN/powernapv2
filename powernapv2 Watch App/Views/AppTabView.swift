import SwiftUI

struct AppTabView: View {
    // Receive ViewModel from the environment
    @EnvironmentObject var viewModel: PowerNapViewModel 
    // State to control the selected tab, default to MainNapView (tag 2)
    @State private var selectedTab: Int = 2 

    var body: some View {
        // Bind the TabView selection to the state variable
        TabView(selection: $selectedTab) {
            SettingsAgeThresholdView()
                // Pass ViewModel or necessary bindings if needed
                .environmentObject(viewModel) // Pass environment object
                .tag(1)

            MainNapView()
                .environmentObject(viewModel)
                .tag(2)

            // Conditional Debug View
            #if DEBUG
            DebugDataView()
                .environmentObject(viewModel)
                .tag(3)
            #endif

            SettingsGeneralView()
                // Pass ViewModel or necessary bindings if needed
                .environmentObject(viewModel) // Pass environment object
                .tag(4)
        }
        // Ensure viewModel is initialized and passed correctly from PowerNapApp
    }
}

// Add Previews if desired 
#Preview {
    // Need to provide a dummy ViewModel for preview
    AppTabView()
        .environmentObject(PowerNapViewModel())
} 