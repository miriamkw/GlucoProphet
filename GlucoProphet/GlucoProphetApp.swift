//
//  GlucoProphetApp.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 15/10/2023.
//

import SwiftUI

@main
struct GlucoProphetApp: App {
    /*
    var body: some Scene {
        
        // Authorize HealthKit
        let _ = HealthKitSetupAssistant.authorizeHealthKit { (authorized, error) in
          guard authorized else {
            let baseMessage = "HealthKit Authorization Failed"
            if let error = error {
              print("\(baseMessage). Reason: \(error.localizedDescription)")
            } else {
              print(baseMessage)
            }
            return
          }
          print("HealthKit Successfully Authorized.")
        }
        
        WindowGroup {
            MainView()
                .environmentObject(MainViewController())
        }
        */
    @State private var isHealthKitAuthorized = false

    var body: some Scene {
        WindowGroup {
            if isHealthKitAuthorized {
                MainView()
                    .environmentObject(MainViewController())
            } else {
                // Authorize HealthKit
                let _ = HealthKitSetupAssistant.authorizeHealthKit { (authorized, error) in
                  guard authorized else {
                    let baseMessage = "HealthKit Authorization Failed"
                    if let error = error {
                      print("\(baseMessage). Reason: \(error.localizedDescription)")
                    } else {
                      print(baseMessage)
                    }
                    return
                  }
                    self.isHealthKitAuthorized = true
                  print("HealthKit Successfully Authorized.")
                }
            }
        }
    }
}
