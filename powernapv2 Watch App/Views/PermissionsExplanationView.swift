import SwiftUI

struct PermissionsExplanationView: View {
    // Receive the completion handler
    var onComplete: () -> Void 
    // Explicitly declare EnvironmentObject
    @EnvironmentObject var viewModel: PowerNapViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("我們需要以下權限：")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                PermissionDetailRow(permissionName: "健康 - 心率", 
                                    explanation: "監測您的即時心率和靜息心率，是判斷您是否入睡的核心依據。")
                
                PermissionDetailRow(permissionName: "健康 - 睡眠", 
                                    explanation: "我們會將偵測到的小睡記錄寫入「健康」App，方便您追蹤。")
                
                PermissionDetailRow(permissionName: "健康 - 生日", 
                                    explanation: "用於自動判斷您的年齡組別，以套用最適合您的睡眠偵測參數。您也可以稍後手動設定。")
                
                PermissionDetailRow(permissionName: "動作與健身", 
                                    explanation: "偵測您是否處於靜止狀態，這是入睡的另一個重要指標。")
                
                PermissionDetailRow(permissionName: "通知", 
                                    explanation: "在您的小睡時間結束時，發送通知來喚醒您。")

                Spacer()
                
                NavigationLink("下一步：請求權限") {
                    // Navigate to PermissionsRequestView
                    // Pass completion handler
                    // Explicitly pass the environment object
                    PermissionsRequestView(onComplete: onComplete)
                        .environmentObject(viewModel)
                }
            }
            .padding()
        }
        .navigationTitle("權限說明")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Helper View for consistent formatting
struct PermissionDetailRow: View {
    let permissionName: String
    let explanation: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(permissionName)
                .font(.headline)
            Text(explanation)
                .font(.footnote)
                .foregroundColor(.gray)
        }
        Divider()
    }
}

// Preview
struct PermissionsExplanationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PermissionsExplanationView(onComplete: {})
                .environmentObject(PowerNapViewModel()) // Add viewModel to environment for preview
        }
    }
} 