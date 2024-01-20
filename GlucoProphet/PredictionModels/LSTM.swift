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
    private let insulinStore = InsulinStore.shared
    
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
        let insulinValues = insulinStore.getResampledInsulin(date: bloodGlucoseValues[regressionLength - 1].date, numSamples: regressionLength)
        
        // Create an MLFeatureProvider with input values
        guard let multiArray = try? MLMultiArray(shape: [1, 6, 3], dataType: .float32) else {
            fatalError("Error creating MLMultiArray")
        }
                
        for i in 0..<6 {
            // Blood Glucose
            multiArray[i * 3] = NSNumber(value: bloodGlucoseValues[i].value * unit_k)
            
            // Carbohydrates
            let carbs = i == 5 ? carbValues[i] + addedCarbs : carbValues[i]
            multiArray[i * 3 + 1] = NSNumber(value: carbs)
            
            // Insulin
            let insulin = i == 5 ? insulinValues[i] + addedBolus : insulinValues[i]
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
                
                let model_15 = try lstm__me__15(configuration: MLModelConfiguration())
                let model_30 = try lstm__me__30(configuration: MLModelConfiguration())
                let model_45 = try lstm__me__45(configuration: MLModelConfiguration())
                let model_60 = try lstm__me__60(configuration: MLModelConfiguration())
                let model_75 = try lstm__me__75(configuration: MLModelConfiguration())
                let model_90 = try lstm__me__90(configuration: MLModelConfiguration())
                let model_105 = try lstm__me__105(configuration: MLModelConfiguration())
                let model_120 = try lstm__me__120(configuration: MLModelConfiguration())
                let model_135 = try lstm__me__135(configuration: MLModelConfiguration())
                let model_150 = try lstm__me__150(configuration: MLModelConfiguration())
                let model_165 = try lstm__me__165(configuration: MLModelConfiguration())
                let model_180 = try lstm__me__180(configuration: MLModelConfiguration())
                                    
                // Make the prediction
                let prediction_15 = try model_15.prediction(lstm_input: multiArray).Identity[0]
                let prediction_30 = try model_30.prediction(lstm_1_input: multiArray).Identity[0]
                let prediction_45 = try model_45.prediction(lstm_2_input: multiArray).Identity[0]
                let prediction_60 = try model_60.prediction(lstm_3_input: multiArray).Identity[0]
                let prediction_75 = try model_75.prediction(lstm_4_input: multiArray).Identity[0]
                let prediction_90 = try model_90.prediction(lstm_5_input: multiArray).Identity[0]
                let prediction_105 = try model_105.prediction(lstm_6_input: multiArray).Identity[0]
                let prediction_120 = try model_120.prediction(lstm_7_input: multiArray).Identity[0]
                let prediction_135 = try model_135.prediction(lstm_8_input: multiArray).Identity[0]
                let prediction_150 = try model_150.prediction(lstm_9_input: multiArray).Identity[0]
                let prediction_165 = try model_165.prediction(lstm_10_input: multiArray).Identity[0]
                let prediction_180 = try model_180.prediction(lstm_11_input: multiArray).Identity[0]
                
                predictions.append(getPredictionSample(prediction: prediction_15, date: currentDate, prediction_horizon: 15))
                predictions.append(getPredictionSample(prediction: prediction_30, date: currentDate, prediction_horizon: 30))
                predictions.append(getPredictionSample(prediction: prediction_45, date: currentDate, prediction_horizon: 45))
                predictions.append(getPredictionSample(prediction: prediction_60, date: currentDate, prediction_horizon: 60))
                predictions.append(getPredictionSample(prediction: prediction_75, date: currentDate, prediction_horizon: 75))
                predictions.append(getPredictionSample(prediction: prediction_90, date: currentDate, prediction_horizon: 90))
                predictions.append(getPredictionSample(prediction: prediction_105, date: currentDate, prediction_horizon: 105))
                predictions.append(getPredictionSample(prediction: prediction_120, date: currentDate, prediction_horizon: 120))
                predictions.append(getPredictionSample(prediction: prediction_135, date: currentDate, prediction_horizon: 135))
                predictions.append(getPredictionSample(prediction: prediction_150, date: currentDate, prediction_horizon: 150))
                predictions.append(getPredictionSample(prediction: prediction_165, date: currentDate, prediction_horizon: 165))
                predictions.append(getPredictionSample(prediction: prediction_180, date: currentDate, prediction_horizon: 180))
                
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
