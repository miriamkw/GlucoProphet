//
//  LSTM.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 19/01/2024.
//

import Foundation
import CoreML

let unit_k = 18.0182

// Example implementation of a class conforming to BaseModel
class LSTM: BaseModel {
    let identifier: String
    private let bgStore = BloodGlucoseStore.shared
    private let carbStore = CarbohydrateStore.shared
    
    init(identifier: String) {
        self.identifier = identifier
    }
    
    func predict(tempBasal: Double, addedBolus: Double, addedCarbs: Double) -> [BloodGlucoseModel] {
        var predictions = [BloodGlucoseModel]()
        
        let regressionLength = 6
        
        guard bgStore.bgSamples.count >= regressionLength else {
            // When there are no blood glucose measurements available, return an empty list of predictions
            return []
        }
        let bloodGlucoseValues = Array(bgStore.bgSamples.suffix(regressionLength))
        
        let carbValues = carbStore.getResampledCarbohydrates(date: bloodGlucoseValues[regressionLength - 1].date, numSamples: regressionLength)
        
        // Create an MLFeatureProvider with input values
        guard let multiArray = try? MLMultiArray(shape: [1, 6, 3], dataType: .float32) else {
            fatalError("Error creating MLMultiArray")
        }
                
        // TODO: Fetch information from HealthKit
        for i in 0..<6 {
            // Blood Glucose
            multiArray[i * 3] = NSNumber(value: bloodGlucoseValues[i].value * unit_k)
            
            // Carbohydrates
            let carbs = i == 5 ? carbValues[i] + addedCarbs : carbValues[i]
            multiArray[i * 3 + 1] = NSNumber(value: carbs)
            
            // Insulin
            let insulin = i == 5 ? 0.0666 + addedBolus : 0.0666
            multiArray[i * 3 + 2] = NSNumber(value: insulin)
        }
        
        let count = multiArray.count

        // Access and print the values
        for i in 0..<count {
            let value = multiArray[i].doubleValue // Adjust for the data type of your MLMultiArray
            print("Index \(i) Value: \(value)")
        }
        
        if let newestBgSample = bgStore.bgSamples.last {
            do {
                let currentDate = newestBgSample.date
                
                let model_30 = try lstm__me__30(configuration: MLModelConfiguration())
                let model_60 = try lstm__me__60(configuration: MLModelConfiguration())
                                    
                // Make the prediction
                let prediction_30 = try model_30.prediction(lstm_input: multiArray).Identity[0]
                let prediction_60 = try model_60.prediction(lstm_1_input: multiArray).Identity[0]
                
                predictions.append(getPredictionSample(prediction: prediction_30, date: currentDate, prediction_horizon: 30))
                predictions.append(getPredictionSample(prediction: prediction_60, date: currentDate, prediction_horizon: 60))
                
                predictions = generateInterpolatedSamples(newestBgSample: newestBgSample, predictions: predictions)
            } catch {
                print("Error making prediction: \(error)")
            }
        }
        return predictions
    }
    
    func getPredictionSample(prediction: NSNumber, date: Date, prediction_horizon: Double) -> BloodGlucoseModel {
        let newSample = BloodGlucoseModel(
            id: UUID(),
            date: date.addingTimeInterval(60*prediction_horizon),
            value: Double(truncating: prediction) / unit_k)
        return newSample
    }
    
    // TODO: This could maybe be moved to MainViewController to avoid redundancy since it will be relevant for all prediction approaches
    /// Generate linearnly interpolated samples with 5-minute intervals between each predicted value.
    func generateInterpolatedSamples(newestBgSample: BloodGlucoseModel, predictions: [BloodGlucoseModel]) -> [BloodGlucoseModel] {
        var interpolatedSamples = [BloodGlucoseModel]()

        for i in 0..<predictions.count {
            let currentPrediction = predictions[i]
            let previousPrediction = i == 0 ? newestBgSample : predictions[i - 1]
            
            // Calculate the time difference between current and previous predictions
            let timeDifference = currentPrediction.date.timeIntervalSince(previousPrediction.date)
            
            // Calculate the number of 5-minute intervals between predictions
            let numberOfIntervals = Int(timeDifference / (5 * 60)) - 1
            
            // Perform linear interpolation
            for j in 1...numberOfIntervals {
                let interpolationFactor = Double(j) / Double(numberOfIntervals + 1)
                let interpolatedValue = (1 - interpolationFactor) * previousPrediction.value + interpolationFactor * currentPrediction.value
                
                let interpolatedSample = BloodGlucoseModel(
                    id: UUID(),
                    date: previousPrediction.date.addingTimeInterval(5 * 60 * Double(j)),
                    value: interpolatedValue
                )
                interpolatedSamples.append(interpolatedSample)
            }
            // Add the current prediction
            interpolatedSamples.append(currentPrediction)
        }
        return interpolatedSamples
    }
}
