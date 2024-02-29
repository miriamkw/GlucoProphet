//
//  LSTMNew.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 19/01/2024.
//

import Foundation
import CoreML
import RealmSwift

// Example implementation of a class conforming to BaseModel
class LSTMNew: BaseModel {
    let identifier: String
    private let bgStore = BloodGlucoseStore.shared
    private let carbStore = CarbohydrateStore.shared
    private let insulinStore = InsulinStore.shared
    
    private var model: lstm_multioutput__me_multioutput__180__custom_loss?

    init(identifier: String) {
        self.identifier = identifier
        
        // Load the ML models once during initialization
        do {
            self.model = try lstm_multioutput__me_multioutput__180__custom_loss(configuration: MLModelConfiguration())
        } catch {
            print("Error loading ML model: \(error)")
        }
    }
    
    func predict(tempBasal: Double, addedBolus: Double, addedCarbs: Double) -> [BloodGlucoseModel] {
        var predictions = [BloodGlucoseModel]()
        let regressionLength = 6
        let basal_rate = 0.8
        
        do {
            let realm = try Realm()
            let bloodGlucoseValues = realm.objects(bgStore.realmObjectType).sorted(byKeyPath: "date", ascending: true)
            
            guard bloodGlucoseValues.count >= regressionLength else {
                // When there are not enough blood glucose measurements available, return an empty list of predictions
                return []
            }
            let recentBloodGlucoseValues = Array(bloodGlucoseValues.suffix(regressionLength))
            
            let carbValues = carbStore.getResampledCarbohydrates(date: recentBloodGlucoseValues[regressionLength - 1].date, numSamples: regressionLength)
            let insulinValues = insulinStore.getResampledInsulin(date: recentBloodGlucoseValues[regressionLength - 1].date, numSamples: regressionLength)
            
            // Create an MLFeatureProvider with input values
            guard let multiArray = try? MLMultiArray(shape: [1, 42, 3], dataType: .float32) else {
                fatalError("Error creating MLMultiArray")
            }
            
            for i in 0..<42 {
                if i < 6 {
                    // Blood Glucose
                    multiArray[i * 3] = NSNumber(value: transformCGM(value: recentBloodGlucoseValues[i].value * unit_k))
                    
                    // Carbohydrates
                    let carbs = i == 5 ? carbValues[i] + addedCarbs : carbValues[i]
                    multiArray[i * 3 + 1] = NSNumber(value: transformCarbs(value: carbs))
                    
                    // Insulin
                    let insulin = i == 5 ? insulinValues[i] + addedBolus : insulinValues[i]
                    multiArray[i * 3 + 2] = NSNumber(value: transformInsulin(value: insulin))
                } else {
                    // Blood Glucose
                    multiArray[i * 3] = NSNumber(value: -1)
                    
                    // Carbohydrates
                    multiArray[i * 3 + 1] = NSNumber(value: transformCarbs(value: 0))
                    
                    // Insulin
                    multiArray[i * 3 + 2] = NSNumber(value: transformInsulin(value: basal_rate / 12))
                }
            }
            
            let currentDate = recentBloodGlucoseValues[regressionLength - 1].date
            
            // Make the prediction
            if let predicted_values = try model?.prediction(masking_input: multiArray).Identity {
                let count = predicted_values.count
                for i in 0..<count {
                    predictions.append(getPredictionSample(prediction: predicted_values[i], date: currentDate, prediction_horizon: Double(5 * (i+1))))
                }
            }
        } catch {
            print("Error initialising new realm, \(error)")
        }
            
        return predictions
    }
    
    func getPredictionSample(prediction: NSNumber, date: Date, prediction_horizon: Double) -> BloodGlucoseModel {
        let newSample = BloodGlucoseModel()
        newSample.id = UUID()
        newSample.date = date.addingTimeInterval(60*prediction_horizon)
        newSample.value = Double(truncating: prediction) / unit_k
        
        return newSample
    }
    
    
    // Features: ['CGM', 'carbs', 'insulin']
    // Feature Means: [1.50264346e+02 6.67214318e-01 1.48117275e-01]
    // Feature Standard Deviations: [50.99592857  5.97361117  0.65547346]

    
    func transformCGM(value: Double) -> Double {
        let mean = 1.50264346e+02
        let std = 50.99592857
        return (value - mean) / std
    }
    func transformCarbs(value: Double) -> Double {
        let mean = 6.67214318e-01
        let std = 5.97361117
        return (value - mean) / std
    }
    func transformInsulin(value: Double) -> Double {
        let mean = 1.48117275e-01
        let std = 0.65547346
        return (value - mean) / std
    }
}
