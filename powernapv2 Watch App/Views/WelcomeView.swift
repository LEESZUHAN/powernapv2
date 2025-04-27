import SwiftUI
// Remove unused imports if any (UserNotifications, HealthKit)

struct WelcomeView: View {
    // Receive ViewModel from the environment
    @EnvironmentObject var viewModel: PowerNapViewModel
    var onComplete: () -> Void 
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("歡迎使用 PowerNap v2")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Image(systemName: "powersleep") // Example icon
                .resizable()
                .scaledToFit()
                .frame(height: 50)
                .foregroundColor(.blue)
            
            Spacer()
            
            NavigationLink("開始了解") {
                // Navigate to IntroView
                // Pass the completion handler down the chain
                // Explicitly inject the environment object here as well
                IntroView(onComplete: onComplete)
                    .environmentObject(viewModel)
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
        // No need for .task or permission logic here anymore
        // Navigation title might be set by NavigationStack in App
    }
}

// Preview
struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview needs NavigationStack and environment object
        NavigationStack {
            // Create a dummy ViewModel for the preview
            WelcomeView(onComplete: {})
                .environmentObject(PowerNapViewModel()) 
        }
    }
} 