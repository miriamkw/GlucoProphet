//
//  BloodGlucoseStore.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 15/10/2023.
//

import HealthKit

class BloodGlucoseStore : ObservableObject {
        
    private let healthKitDataStore = HealthKitDataStore.shared
    private let realmManager = RealmManager.shared
    
    // Create singleton instance
    static let shared = BloodGlucoseStore()
    
    let realmObjectType = BloodGlucoseModel.self
    
    // Define time horizon for blood glucose storage (in seconds)
    private let timeInterval = 60*60
    
    func startObserver(completion: @escaping () -> Swift.Void, updateHandler: @escaping () -> Swift.Void) {
        self.healthKitDataStore.getSamples(for: getGlucoseLevelSampleType(), start: Date().addingTimeInterval(-TimeInterval(timeInterval)), completion: { (samples, deleted) in
            self.updateBloodGlucoseValuesRealm(samples: samples, deleted: deleted)
            completion()
        }, updateHandler: { (samples, deleted) in
            self.updateBloodGlucoseValuesRealm(samples: samples, deleted: deleted)
            updateHandler()
        })
    }
    
    private func updateBloodGlucoseValuesRealm(samples: [HKQuantitySample], deleted: [HKDeletedObject]) {
        
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
                let newData = BloodGlucoseModel()
                newData.id = sample.uuid
                newData.date = sample.startDate
                newData.value = sample.quantity.doubleValue(for: .millimolesPerLiter)
                realmManager.write(newData)
            }
        }
    }
    
    func getGlucoseLevelSampleType() -> HKSampleType {
        guard let glucoseLevelSampleType = HKSampleType.quantityType(forIdentifier: .bloodGlucose) else {
          fatalError("Glucose Level Sample Type is no longer available in HealthKit")
        }
        return glucoseLevelSampleType
    }
}


