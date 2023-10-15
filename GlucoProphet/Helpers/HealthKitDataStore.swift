//
//  HealthKitDataStore.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 15/10/2023.
//


import HealthKit
import UIKit

final class HealthKitDataStore {
    
    let healthStore = HKHealthStore()
    // Create singleton instance
    static let shared = HealthKitDataStore()
    
    // TUTORIAL: https://www.devfright.com/how-to-use-healthkit-hkanchoredobjectquery/
    func getSamples(for sampleType: HKSampleType, start: Date?, end: Date = Date(), completion: @escaping ([HKQuantitySample], [HKDeletedObject]) -> Swift.Void, updateHandler: @escaping ([HKQuantitySample], [HKDeletedObject]) -> Swift.Void) {
        let predicate = HKQuery.predicateForSamples(withStart: start,
                                                          end: nil,
                                                          options: .strictEndDate)
        
        // The last object is always the newest, which is why there is no sortdescriptor
        let query = HKAnchoredObjectQuery(type: sampleType,
                                          predicate: predicate,
                                          anchor: nil,
                                          limit: HKObjectQueryNoLimit
                                            ) { (_, samplesOrNil, deletedOrNil, _, errorOrNil)  in
            guard let samples = samplesOrNil as? [HKQuantitySample], let deleted = deletedOrNil else {
                fatalError("*** An error occurred during the initial query: \(errorOrNil!.localizedDescription) ***")
            }
            completion(samples, deleted)
        }
        
        // Setting up long-runnning query
        query.updateHandler = { (_, samplesOrNil, deletedOrNil, _, errorOrNil) in
            guard let samples = samplesOrNil as? [HKQuantitySample], let deleted = deletedOrNil else {
                // Handle the error here.
                fatalError("*** An error occurred during an update: \(errorOrNil!.localizedDescription) ***")
            }
            updateHandler(samples, deleted)
        }
        self.healthStore.execute(query)
    }
    
    func getSamplesSorted(for sampleType: HKSampleType, start: Date?, end: Date = Date(), completion: @escaping ([HKQuantitySample]) -> Swift.Void) {
        let predicate = HKQuery.predicateForSamples(withStart: start,
                                                          end: nil,
                                                          options: .strictEndDate)
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        
        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) {
            query, results, error in
            guard let samples = results as? [HKQuantitySample] else {
                fatalError("Error fetching samples from HealthKit")
            }
            completion(samples)
        }
        
        self.healthStore.execute(query)
    }
    
}

