//
//  powernapv2App.swift
//  powernapv2 Watch App
//
//  Created by michaellee on 4/15/25.
//

import SwiftUI
import HealthKit       // For HKAuthorizationStatus comparison
import UserNotifications // For UNAuthorizationStatus comparison

@main
struct PowerNapApp: App {
    // Initialize the shared ViewModel here
    @StateObject var viewModel = PowerNapViewModel()
    // Use AppStorage for automatic persistence and view updates
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false

    var body: some Scene {
        WindowGroup {
            // Use a conditional view to show onboarding or the main app view
            if !hasLaunchedBefore {
                 // Use NavigationStack for the onboarding flow
                 NavigationStack {
                     // WelcomeView now gets viewModel from environment
                     WelcomeView(onComplete: completeOnboarding) 
                          .environmentObject(viewModel) 
                 }
            } else {
                 AppTabView()
                     .environmentObject(viewModel) // Pass the ViewModel to the main TabView
            }
        }
        // Optional: Add background scene for complications or background refresh if needed
    }
    
    // Function to be called when onboarding is complete
    private func completeOnboarding() {
        // This will automatically update UserDefaults because of @AppStorage
        hasLaunchedBefore = true 
        print("Onboarding complete. hasLaunchedBefore set to true.")
    }
}
