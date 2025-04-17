//
//  ContentView.swift
//  powernapv2 Watch App
//
//  Created by michaellee on 4/15/25.
//

import SwiftUI
import HealthKit       // For displaying HKAuthorizationStatus
import UserNotifications // For displaying UNAuthorizationStatus

struct ContentView: View {
    // Access the ViewModel from the environment
    @EnvironmentObject var viewModel: PowerNapViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PowerNap")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center) // Center title

            Divider()

            Text("狀態：準備就緒")
                .font(.headline)

            // Display Permission Status for confirmation
            HStack {
                Text("通知權限:")
                Spacer()
                Text(viewModel.notificationAuthorizationStatus.description)
                    .foregroundColor(statusColor(for: viewModel.notificationAuthorizationStatus))
            }

            HStack {
                Text("健康權限:")
                Spacer()
                Text(viewModel.healthKitAuthorizationStatus.description)
                    .foregroundColor(statusColor(for: viewModel.healthKitAuthorizationStatus))
            }
            
            Spacer() // Push content to the top
            
            // TODO: Add Start/Stop button later
            Button("開始小睡 (尚未實作)") {
                // Action to start nap detection/timer
            }
            .disabled(true) // Disable for now

        }
        .padding()
    }
    
    // Helper function to determine status color
    private func statusColor(for status: UNAuthorizationStatus) -> Color {
        switch status {
        case .authorized: return .green
        case .denied: return .red
        default: return .gray
        }
    }
    
    private func statusColor(for status: HKAuthorizationStatus) -> Color {
        switch status {
        case .sharingAuthorized: return .green
        case .sharingDenied: return .red
        default: return .gray
        }
    }
}

// Update Preview to provide a dummy ViewModel
#Preview {
    // Create a dummy ViewModel instance for the preview
    let dummyViewModel = PowerNapViewModel()
    // Simulate authorized state for preview purposes
    // Note: Direct modification might not be possible if @Published properties are private.
    // If needed, create a specific init in ViewModel for previews or use mock data.
    
    // A better approach for previews if direct modification isn't easy:
    // Just show the ContentView structure without relying on live ViewModel state
    // or pass a specifically configured mock ViewModel.
    
    // The #Preview macro implicitly returns the last expression
    ContentView()
        .environmentObject(dummyViewModel) // Provide the dummy model to the environment
}
