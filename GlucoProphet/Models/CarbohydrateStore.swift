//
//  CarbohydrateStore.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 15/10/2023.
//

import HealthKit

class CarbohydrateStore {
    
    var carbSamples = [HKQuantitySample]()
    
    private let healthKitDataStore = HealthKitDataStore.shared
    
    private var totalDuration: Double {
        return 60*60 // TODO: Add a proper time period to fetch data
    }
    
    // Create singleton instance
    static let shared = CarbohydrateStore()
    
    func getCarbSampleType() -> HKSampleType {
        guard let carbSampleType = HKSampleType.quantityType(forIdentifier: .dietaryCarbohydrates) else {
          fatalError("Carbohydrate Intake Sample Type is no longer available in HealthKit")
        }
        return carbSampleType
    }
    
    func starObserver(completion: @escaping () -> Swift.Void, updateHandler: @escaping () -> Swift.Void) {
        self.healthKitDataStore.getSamples(for: getCarbSampleType(), start: Date().addingTimeInterval(-TimeInterval(totalDuration)), completion: { (samples, deleted) in
            self.setCarbValues(samples: samples, deleted: deleted)
            completion()
        }, updateHandler: { (samples, deleted) in
            self.setCarbValues(samples: samples, deleted: deleted)
            updateHandler()
        })
    }
    
    private func setCarbValues(samples: [HKQuantitySample], deleted: [HKDeletedObject]) {
        var mostRecentSamples = carbSamples
        // Filter out glucose values that no longer are relevant
        mostRecentSamples.removeAll { sample in
            sample.endDate < Date().addingTimeInterval(-TimeInterval(totalDuration))
        }
        // Add new samples
        mostRecentSamples.append(contentsOf: samples)
        // Remove deleted samples
        mostRecentSamples.removeAll { sample in
            deleted.contains { deletedObject in
                deletedObject.uuid == sample.uuid
            }
        }
        self.carbSamples = mostRecentSamples
    }
    
    /// Given a set of carbohydrate intakes, get the carbs on board for a given date.
    ///
    /// - parameter samples: Carbohydrate intake samples from HealthKit
    /// - parameter date: Date to calculate carbohydrates on board
    /// - returns: Carbohydrates on board for the given time interval for the given carbohydrate samples
    ///
    func getCOB(date: Date, addedCarbs: Double = 0.0) -> Double {
        var res = 0.0
        for sample in carbSamples {
            let carbQuantity = sample.quantity.doubleValue(for: .gram())
            // The new timeinterval is by defualt also a double value, in seconds
            let timeSinceCarbIntake = date.timeIntervalSince(sample.startDate)/60 // In minutes, positive when it happened in the past

            // Skip current iteration of for loop for samples in the future, or is older than totalDuration
            if ((timeSinceCarbIntake < 0) || (timeSinceCarbIntake > totalDuration/60)) {
                continue
            }
            
            res = res + carbQuantity
        }
        // Add added carbohydrates from UI
        res = res + addedCarbs
        return res
    }
    
     /// Given a set of carbohydrate intakes, get the absorbed carbohydrates between two dates
     ///
     /// - parameter samples: Carbohydrate intake samples from HealthKit
     /// - parameter startDate: Start date to calculate absorbed carbohydrates
     /// - parameter endDate: End date to calculate absorbed carbohydrates
     /// - returns: Absorbed carbohydrates in the given time interval for the given carbohydrate samples
     ///
    func getAbsorbedCarbohydrates(startDate: Date, endDate: Date, addedCarbs: Double = 0.0) -> Double {
         if (startDate.timeIntervalSince(endDate) > 0) {
             fatalError("Start date passed is larger than end date!")
         }
        var res = 0.0
        for sample in carbSamples {
            let carbQuantity = sample.quantity.doubleValue(for: .gram())
            let timeSinceCarbIntake = startDate.timeIntervalSince(sample.startDate)/60 // In minutes, positive when it happened in the past
            
            // Skip current iteration of for loop for samples in the future, or is older than totalDuration
            if (timeSinceCarbIntake < 0 || (timeSinceCarbIntake > totalDuration/60)) {
                continue
            }
            
            // If the insulin dose happened for over 7 minutes, the dose will be split into five minute intervals
            res = res + carbQuantity
        }
        // Add added carbohydrates from UI
        res = res + addedCarbs
        return res
    }
}

