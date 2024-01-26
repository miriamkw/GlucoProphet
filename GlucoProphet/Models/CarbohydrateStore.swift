//
//  CarbohydrateStore.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 15/10/2023.
//

import HealthKit
import RealmSwift

class CarbohydrateStore {
        
    private let healthKitDataStore = HealthKitDataStore.shared
    private let realmManager = RealmManager.shared
    
    // Unit is seconds
    private var timeInterval: Double = 60*60*12 // Storing data for 12 hours, adjust if needed
    
    // Create singleton instance
    static let shared = CarbohydrateStore()
    
    let realmObjectType = CarbohydrateModel.self
    
    func getCarbSampleType() -> HKSampleType {
        guard let carbSampleType = HKSampleType.quantityType(forIdentifier: .dietaryCarbohydrates) else {
          fatalError("Carbohydrate Intake Sample Type is no longer available in HealthKit")
        }
        return carbSampleType
    }
    
    func starObserver(completion: @escaping () -> Swift.Void, updateHandler: @escaping () -> Swift.Void) {
        self.healthKitDataStore.getSamples(for: getCarbSampleType(), start: Date().addingTimeInterval(-TimeInterval(timeInterval)), completion: { (samples, deleted) in
            self.updateCarbohydrateValuesRealm(samples: samples, deleted: deleted)
            completion()
        }, updateHandler: { (samples, deleted) in
            self.updateCarbohydrateValuesRealm(samples: samples, deleted: deleted)
            updateHandler()
        })
    }
    
    private func updateCarbohydrateValuesRealm(samples: [HKQuantitySample], deleted: [HKDeletedObject]) {
        
        // Delete old values in Realm
        realmManager.deleteObjectsOlderThanTimeInterval(realmObjectType, timeInterval: Double(timeInterval))
        
        // Delete values in Realm if deleted in HealthKit
        for sample in deleted {
            realmManager.deleteObjectWithUUID(realmObjectType, uuid: sample.uuid)
        }
        
        // Add new samples in Realm
        for sample in samples {
            let isRecent = sample.startDate > Date().addingTimeInterval(-TimeInterval(timeInterval))
            let existsRealmObject = realmManager.existsRealmObject(realmObjectType, uuid: sample.uuid)
            if (isRecent && !existsRealmObject) {
                let newData = CarbohydrateModel()
                newData.id = sample.uuid
                newData.date = sample.startDate
                newData.value = sample.quantity.doubleValue(for: .gram())
                realmManager.write(newData)
            }
        }
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
        
        do {
            let realm = try Realm()
            let carbSamples = realm.objects(self.realmObjectType).sorted(byKeyPath: "date", ascending: true)
            
            for i in 0..<numSamples {
                let intervalStart = date.addingTimeInterval(-TimeInterval((numSamples - i) * interval * 60))
                let intervalEnd = date.addingTimeInterval(-TimeInterval((numSamples - i - 1) * interval * 60))
                
                let carbSamplesInInterval = carbSamples.filter { sample in
                    return sample.date >= intervalStart && sample.date < intervalEnd
                }
                
                // Sum up carbohydrates within the interval
                let sumCarbs = carbSamplesInInterval.reduce(0.0) { (result, sample) in
                    let grams = sample.value
                    return result + grams
                }
                resampledCarbs.append(sumCarbs)
            }
        } catch {
            print("Error initialising new realm, \(error)")
        }
        return resampledCarbs
    }
}

