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
    
    // Unit is seconds
    private var totalDuration: Double {
        return 60*60 // Storing data for one hour, adjust if needed
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
        // Filter out carbohydrate values that no longer are relevant
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
    
    /// Generates resampled carbohydrate values for a specified time range.
    ///
    /// - Parameters:
    ///   - date: The reference date for generating the resampled carbohydrates.
    ///   - numSamples: The number of intervals for which to generate resampled carbohydrates.
    ///   - interval: The interval in minutes between each resampled sample
    ///
    /// - Returns: An array of resampled carbohydrate values for each 5-minute interval.
    func getResampledCarbohydrates(date: Date, numSamples: Int, interval: Int = 5) -> [Double] {
        var resampledCarbs = [Double]()

        for i in 0..<numSamples {
            let intervalStart = date.addingTimeInterval(-TimeInterval((numSamples - i) * interval * 60))
            let intervalEnd = date.addingTimeInterval(-TimeInterval((numSamples - i - 1) * interval * 60))

            let carbSamplesInInterval = carbSamples.filter { sample in
                let sampleDate = sample.startDate
                return sampleDate >= intervalStart && sampleDate < intervalEnd
            }

            // Sum up carbohydrates within the interval
            let sumCarbs = carbSamplesInInterval.reduce(0.0) { (result, sample) in
                let grams = sample.quantity.doubleValue(for: HKUnit.gram())
                return result + grams
            }
            resampledCarbs.append(sumCarbs)
        }
        return resampledCarbs
    }
}

