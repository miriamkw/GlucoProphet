//
//  RidgeRegressor.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 08/02/2024.
//

import Foundation
import CoreML
import RealmSwift

// Example implementation of a class conforming to BaseModel
class RidgeRegressor: BaseModel {
    let identifier: String
    
    private let bgStore = BloodGlucoseStore.shared
    private let carbStore = CarbohydrateStore.shared
    private let insulinStore = InsulinStore.shared
    
    init(identifier: String) {
        self.identifier = identifier
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
                print("Not enought blood glucose values to predict")
                return []
            }
            let recentBloodGlucoseValues = Array(bloodGlucoseValues.suffix(regressionLength))
            
            let carbValues = carbStore.getResampledCarbohydrates(date: bloodGlucoseValues[regressionLength - 1].date, numSamples: regressionLength)
            let insulinValues = insulinStore.getResampledInsulin(date: bloodGlucoseValues[regressionLength - 1].date, numSamples: regressionLength)
                    
            typealias InputValues = (CGM: Double, carbs: Double, insulin: Double, CGM_5: Double, CGM_10: Double, CGM_15: Double, CGM_20: Double, CGM_25: Double, carbs_5: Double, carbs_10: Double, carbs_15: Double, carbs_20: Double, carbs_25: Double, insulin_5: Double, insulin_10: Double, insulin_15: Double, insulin_20: Double, insulin_25: Double)
            
            let inputValues: InputValues = (
                CGM: recentBloodGlucoseValues[5].value * unit_k,
                carbs: carbValues[5] + addedCarbs,
                insulin: insulinValues[5] + addedBolus,
                CGM_5: recentBloodGlucoseValues[4].value * unit_k,
                CGM_10: recentBloodGlucoseValues[3].value * unit_k,
                CGM_15: recentBloodGlucoseValues[2].value * unit_k,
                CGM_20: recentBloodGlucoseValues[1].value * unit_k,
                CGM_25: recentBloodGlucoseValues[0].value * unit_k,
                carbs_5: carbValues[4],
                carbs_10: carbValues[3],
                carbs_15: carbValues[2],
                carbs_20: carbValues[1],
                carbs_25: carbValues[0],
                insulin_5: insulinValues[4],
                insulin_10: insulinValues[3],
                insulin_15: insulinValues[2],
                insulin_20: insulinValues[1],
                insulin_25: insulinValues[0]
            )
            
            let currentDate = recentBloodGlucoseValues[regressionLength - 1].date
            
            
            let modelWeights = loadModelWeights()
            guard let coefficients = modelWeights["coefficients"] as? [[Double]], 
                    let intercepts = modelWeights["intercepts"] as? [Double],
                    let feature_names = modelWeights["feature_names"] as? [String] else {
                print("Coult not find coefficients, intercepts, or feature names in model weights")
                return []
            }
            
            for (iteration, coefficientRow) in coefficients.enumerated() {
                // TODO: For weights in weights_list multiply inputs with coefficients
                
                var result: Double = 0
                    
                // Iterate over the coefficients in the current row and multiply each coefficient with the corresponding input value
                for j in 0..<coefficientRow.count {
                                        
                    // Access the corresponding value using key path and Mirror
                    if let inputValue = Mirror(reflecting: inputValues).children.first(where: { $0.label == feature_names[j] })?.value as? Double {
                        result += coefficientRow[j] * inputValue
                    } else if feature_names[j].contains("insulin_what_if") {
                        result += coefficientRow[j] * (basal_rate / 12)
                    } else if feature_names[j].contains("carbs_what_if") {
                        result += coefficientRow[j] * 0
                    } else {
                        print("Input value key not found")
                        return []
                    }
                }
                let newPrediction = getPredictionSample(prediction: result + intercepts[iteration], date: currentDate, prediction_horizon: 5 * Double(iteration + 1))
                predictions.append(newPrediction)
            }
        } catch {
            print("Error initialising new realm, \(error)")
        }
        return predictions
    }
    
    func getPredictionSample(prediction: Double, date: Date, prediction_horizon: Double) -> BloodGlucoseModel {
        let newSample = BloodGlucoseModel()
        newSample.id = UUID()
        newSample.date = date.addingTimeInterval(60*prediction_horizon)
        newSample.value = prediction / unit_k
                
        return newSample
    }
    
    // Load model weights from file
    func loadModelWeights() -> [String: Any] {        
        let fileName = "ridge_multioutput_constrained__me_multioutput__180"
        if let fileURL = Bundle.main.url(forResource: fileName, withExtension: "json") {
            let weightsData = try! Data(contentsOf: fileURL)
            let weights = try! JSONSerialization.jsonObject(with: weightsData, options: []) as! [String: Any]
            return weights
        } else {
            print("JSON file not found.")
        }
        let weightsData = try! Data(contentsOf: URL(fileURLWithPath: "GlucoProphet/PredictionModels/\(fileName).json"))
        let weights = try! JSONSerialization.jsonObject(with: weightsData, options: []) as! [String: Any]
        return weights
    }
}


