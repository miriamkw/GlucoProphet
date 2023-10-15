//
//  BloodGlucoseStore.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 15/10/2023.
//

import HealthKit

class BloodGlucoseStore : ObservableObject {
    
    var bgSamples = [BloodGlucoseModel]()
    
    private let healthKitDataStore = HealthKitDataStore.shared
    
    // Create singleton instance
    static let shared = BloodGlucoseStore()
    private let timeInterval = 60*60
    
    func starObserver(completion: @escaping () -> Swift.Void, updateHandler: @escaping () -> Swift.Void) {
        self.healthKitDataStore.getSamples(for: getGlucoseLevelSampleType(), start: Date().addingTimeInterval(-TimeInterval(timeInterval)), completion: { (samples, deleted) in
            self.setBloodGlucoseValues(samples: samples, deleted: deleted) {
                completion()
            }
        }, updateHandler: { (samples, deleted) in
            self.setBloodGlucoseValues(samples: samples, deleted: deleted) {
                updateHandler()
            }
            
        })
    }
    
    private func setBloodGlucoseValues(samples: [HKQuantitySample], deleted: [HKDeletedObject], completion: @escaping () -> Swift.Void) {
        var mostRecentSamples = bgSamples
        // Filter out glucose values that no longer are relevant
        mostRecentSamples.removeAll { sample in
            sample.date < Date().addingTimeInterval(-TimeInterval(timeInterval))
        }
        // Add new samples
        for sample in samples {
            let value = BloodGlucoseModel(id: sample.uuid, date: sample.startDate, value: sample.quantity.doubleValue(for: .millimolesPerLiter))
            mostRecentSamples.append(value)
        }
        // Remove deleted samples
        mostRecentSamples.removeAll { sample in
            deleted.contains { deletedObject in
                deletedObject.uuid == sample.id
            }
        }
        // Sort the values by date
        mostRecentSamples = mostRecentSamples.sorted { value1, value2 in
            value1.date < value2.date
        }
        self.bgSamples = mostRecentSamples
        completion()
    }
    
    func getGlucoseLevelSampleType() -> HKSampleType {
        guard let glucoseLevelSampleType = HKSampleType.quantityType(forIdentifier: .bloodGlucose) else {
          fatalError("Glucose Level Sample Type is no longer available in HealthKit")
        }
        return glucoseLevelSampleType
    }
}


