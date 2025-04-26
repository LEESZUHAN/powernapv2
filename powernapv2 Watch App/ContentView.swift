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
        // Wrap in NavigationView for navigation capability
        NavigationView {
            // Wrap the content in a ScrollView to allow scrolling
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("PowerNap")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center) // Center title

                    Divider()

                    // Display the current NAP state from the ViewModel
                    HStack {
                        Text("狀態:")
                            .font(.headline)
                        Spacer()
                        Text(napStateDescription(for: viewModel.napState)) // Use napState for primary status
                            .font(.headline)
                    }
                    // Optionally, show detailed sleep state when detecting/napping
                    if viewModel.napState == .detecting || viewModel.napState == .napping {
                        HStack {
                            Text("偵測狀態:")
                                .font(.caption)
                            Spacer()
                            Text(sleepStateDescription(for: viewModel.sleepState))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

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
                    
                    Divider()

                    // Display Heart Rate Data
                    HStack {
                        Text("即時心率 (HR):")
                        Spacer()
                        Text(heartRateText)
                    }
                    
                    HStack {
                        Text("靜息心率 (RHR):")
                        Spacer()
                        Text(restingHeartRateText)
                    }
                    
                    Divider()

                    // Display Countdown Timer
                    HStack {
                        Text("剩餘時間:")
                            .font(.headline)
                        Spacer()
                        Text(formatTimeInterval(viewModel.timeRemaining))
                            .font(.system(.title2, design: .rounded).monospacedDigit())
                            .foregroundColor(viewModel.isTimerRunning ? .orange : .gray)
                    }

                    Divider()
                    
                    // Navigation Link to Settings
                    NavigationLink(destination: SettingsView()) { 
                        Label("設定小睡時長", systemImage: "timer")
                    }
                    
                    Spacer() // Push content towards the top
                    
                    // Start/Stop Button - Dynamically changes based on napState
                    Button {
                        if viewModel.napState == .idle || viewModel.napState == .finished {
                            viewModel.startNap()
                        } else {
                            viewModel.stopNap()
                        }
                    } label: {
                        if viewModel.napState == .idle || viewModel.napState == .finished {
                            Label("開始小睡", systemImage: "powersleep")
                        } else {
                            Label("停止小睡", systemImage: "stop.circle.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint( (viewModel.napState == .idle || viewModel.napState == .finished) ? .green : .red )
                    .disabled(viewModel.healthKitAuthorizationStatus != .sharingAuthorized) // Disable if no HK permission

                }
                .padding()
            }
             // Add a title to the NavigationView itself if desired
             // .navigationTitle("主畫面") // Optional: Can keep the title inside the VStack
        }
    }
    
    // MARK: - Computed Properties for Display
    
    private func napStateDescription(for state: NapState) -> String {
        switch state {
        case .idle: return "準備就緒"
        case .detecting: return "偵測入睡中..."
        case .napping: return "小睡中..."
        case .paused: return "已暫停"
        case .finished: return "小睡完成"
        case .error(let msg): return "錯誤: \(msg)"
        }
    }
    
    private func sleepStateDescription(for state: SleepState) -> String {
        switch state {
        case .awake: return "清醒"
        case .detecting: return "偵測中..."
        case .asleep: return "已入睡"
        case .disturbed: return "睡眠被中斷"
        case .finished: return "小睡完成"
        case .error(let message): return "錯誤: \(message)"
        }
    }
    
    private var heartRateText: String {
        guard let hr = viewModel.heartRate else { return "--" }
        return String(format: "%.0f bpm", hr)
    }
    
    private var restingHeartRateText: String {
        guard let rhr = viewModel.restingHeartRate else { return "--" }
        return String(format: "%.0f bpm", rhr)
    }
    
    // MARK: - Helper Functions
    
    private func formatTimeInterval(_ interval: TimeInterval?) -> String {
        guard let interval = interval, interval > 0 else {
            return "--:--"
        }
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
