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
struct powernapv2_Watch_AppApp: App {
    // Create the single instance of the ViewModel here
    @StateObject private var viewModel = PowerNapViewModel()
    
    var body: some Scene {
        WindowGroup {
            // Conditionally show WelcomeView or ContentView based on permissions
            if viewModel.healthKitAuthorizationStatus == .sharingAuthorized && 
               viewModel.notificationAuthorizationStatus == .authorized {
                ContentView()
                    .environmentObject(viewModel)
            } else {
                WelcomeView(viewModel: viewModel)
            }
        }
    }
}
