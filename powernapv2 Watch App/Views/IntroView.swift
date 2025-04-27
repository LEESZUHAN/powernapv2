import SwiftUI

struct IntroView: View {
    // Receive the completion handler
    var onComplete: () -> Void 
    // Explicitly declare EnvironmentObject
    @EnvironmentObject var viewModel: PowerNapViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("PowerNap 如何運作？")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("PowerNap 會監測您的心率和活動狀態，判斷您何時入睡。一旦入睡，它會根據您設定的時長開始倒數，並在時間到時溫和地喚醒您，讓您精神煥發！")
                    .font(.body)
                
                // Add more details if needed, ensure it fits within 50-100 words target
                
                Spacer()
                
                NavigationLink("下一步：所需權限") {
                    // Navigate to PermissionsExplanationView
                    // Pass the completion handler down
                    // Explicitly pass the environment object
                    PermissionsExplanationView(onComplete: onComplete)
                        .environmentObject(viewModel) 
                }
            }
            .padding()
        }
        .navigationTitle("簡介") // Set a title for the navigation bar
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Preview
struct IntroView_Previews: PreviewProvider {
    static var previews: some View {
        // Wrap in NavigationStack for preview
        NavigationStack {
            IntroView(onComplete: {})
                .environmentObject(PowerNapViewModel()) // Add viewModel to environment for preview
        }
    }
} 