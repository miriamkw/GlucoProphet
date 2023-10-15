//
//  HealthKitSetupAssistant.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 15/10/2023.
//

import HealthKit

class HealthKitSetupAssistant {
  
  private enum HealthkitSetupError: Error {
    case notAvailableOnDevice
    case dataTypeNotAvailable
  }
  
    // TODO: Cleanup this method to only contain needed datatypes
    
  class func authorizeHealthKit(completion: @escaping (Bool, Error?) -> Swift.Void) {
      //1. Check to see if HealthKit Is Available on this device
      guard HKHealthStore.isHealthDataAvailable() else {
        completion(false, HealthkitSetupError.notAvailableOnDevice)
        return
      }
      
      //2. Prepare the data types that will interact with HealthKit
      guard let bloodGlucose = HKObjectType.quantityType(forIdentifier: .bloodGlucose),
            let insulin = HKObjectType.quantityType(forIdentifier: .insulinDelivery),
            let carbohydrates = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates),
            let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            let rr = HKObjectType.quantityType(forIdentifier: .respiratoryRate)
      else {
              completion(false, HealthkitSetupError.dataTypeNotAvailable)
              return
      }
                
      let healthKitTypesToRead: Set<HKObjectType> = [bloodGlucose,
                                                     insulin,
                                                     carbohydrates,
                                                     hrv,
                                                     rr,
                                                     HKObjectType.workoutType()
      ]
      
      //4. Request Authorization
      HKHealthStore().requestAuthorization(toShare: nil,
                                           read: healthKitTypesToRead) { (success, error) in
        completion(success, error)
      }
  }
}

