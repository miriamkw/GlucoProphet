//
//  InsulinStore.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 15/10/2023.
//

import HealthKit
import RealmSwift

class InsulinStore {
        
    private let healthKitDataStore = HealthKitDataStore.shared
    private let realmManager = RealmManager.shared
    
    // Unit is seconds
    private var timeInterval: Double = 60*60*12 // Storing data for 12 hours, adjust if needed
    
    // Create singleton instance
    static let shared = InsulinStore()
    
    let realmObjectType = InsulinModel.self
    
    func getInsulinDeliverySampleType() -> HKSampleType {
        guard let insulinDeliverySampleType = HKSampleType.quantityType(forIdentifier: .insulinDelivery) else {
          fatalError("Insulin Delivery Sample Type is no longer available in HealthKit")
        }
        return insulinDeliverySampleType
    }
    
    func starObserver(completion: @escaping () -> Swift.Void, updateHandler: @escaping () -> Swift.Void) {
        self.healthKitDataStore.getSamples(for: getInsulinDeliverySampleType(), start: Date().addingTimeInterval(-TimeInterval(timeInterval)), completion: { (samples, deleted) in
            self.updateInsulinValuesRealm(samples: samples, deleted: deleted)
            completion()
        }, updateHandler: { (samples, deleted) in
            self.updateInsulinValuesRealm(samples: samples, deleted: deleted)
            updateHandler()
        })
    }
    
    private func updateInsulinValuesRealm(samples: [HKQuantitySample], deleted: [HKDeletedObject]) {
        
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
                let newData = InsulinModel()
                newData.id = sample.uuid
                newData.date = sample.startDate
                newData.value = sample.quantity.doubleValue(for: .internationalUnit())
                realmManager.write(newData)
            }
        }
    }
            
    /// Generates resampled insulin values for a specified time range.
    ///
    /// - Parameters:
    ///   - date: The reference date for generating the resampled insulin.
    ///   - numSamples: The number of intervals for which to generate resampled insulin.
    ///   - interval: The interval in minutes between each resampled sample
    ///
    /// - Returns: An array of resampled insulin values for each 5-minute interval.
    func getResampledInsulin(date: Date, numSamples: Int, interval: Int = 5) -> [Double] {
        var resampledInsulin = [Double]()
        
        do {
            let realm = try Realm()
            let insulinSamples = realm.objects(self.realmObjectType).sorted(byKeyPath: "date", ascending: true)
            
            for i in 0..<numSamples {
                let intervalStart = date.addingTimeInterval(-TimeInterval((numSamples - i) * interval * 60))
                let intervalEnd = date.addingTimeInterval(-TimeInterval((numSamples - i - 1) * interval * 60))
                
                let insulinSamplesInInterval = insulinSamples.filter { sample in
                    return sample.date >= intervalStart && sample.date < intervalEnd
                }
                
                // Sum up carbohydrates within the interval
                let sumInsulin = insulinSamplesInInterval.reduce(0.0) { (result, sample) in
                    let insulin = sample.value
                    return result + insulin
                }
                resampledInsulin.append(sumInsulin)
            }
        } catch {
            print("Error initialising new realm, \(error)")
        }
        return resampledInsulin
    }
}


