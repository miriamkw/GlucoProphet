//
//  RidgeRegressor.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 08/01/2024.
//

import Foundation
import CoreML

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
        
        guard bgStore.bgSamples.count >= regressionLength else {
            // When there are no blood glucose measurements available, return an empty list of predictions
            return []
        }
        let bloodGlucoseValues = Array(bgStore.bgSamples.suffix(regressionLength))
        
        let carbValues = carbStore.getResampledCarbohydrates(date: bloodGlucoseValues[regressionLength - 1].date, numSamples: regressionLength)
        let insulinValues = insulinStore.getResampledInsulin(date: bloodGlucoseValues[regressionLength - 1].date, numSamples: regressionLength)
                
        typealias InputValues = (CGM: Double, carbs: Double, insulin: Double, CGM_5: Double, CGM_10: Double, CGM_15: Double, CGM_20: Double, CGM_25: Double, carbs_5: Double, carbs_10: Double, carbs_15: Double, carbs_20: Double, carbs_25: Double, insulin_5: Double, insulin_10: Double, insulin_15: Double, insulin_20: Double, insulin_25: Double)
        
        let inputValues: InputValues = (
            CGM: bloodGlucoseValues[5].value * unit_k,
            carbs: carbValues[5] + addedCarbs,
            insulin: insulinValues[5] + addedBolus,
            CGM_5: bloodGlucoseValues[4].value * unit_k,
            CGM_10: bloodGlucoseValues[3].value * unit_k,
            CGM_15: bloodGlucoseValues[2].value * unit_k,
            CGM_20: bloodGlucoseValues[1].value * unit_k,
            CGM_25: bloodGlucoseValues[0].value * unit_k,
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
        
        if let newestBgSample = bgStore.bgSamples.last {
            do {
                let currentDate = newestBgSample.date
                
                let model_15 = try ridge__me__15(configuration: MLModelConfiguration())
                let model_30 = try ridge__me__30(configuration: MLModelConfiguration())
                let model_45 = try ridge__me__45(configuration: MLModelConfiguration())
                let model_60 = try ridge__me__60(configuration: MLModelConfiguration())
                let model_75 = try ridge__me__75(configuration: MLModelConfiguration())
                let model_90 = try ridge__me__90(configuration: MLModelConfiguration())
                let model_105 = try ridge__me__105(configuration: MLModelConfiguration())
                let model_120 = try ridge__me__120(configuration: MLModelConfiguration())
                let model_135 = try ridge__me__135(configuration: MLModelConfiguration())
                let model_150 = try ridge__me__150(configuration: MLModelConfiguration())
                let model_165 = try ridge__me__165(configuration: MLModelConfiguration())
                let model_180 = try ridge__me__180(configuration: MLModelConfiguration())
                                                    
                // Make the prediction
                let prediction_15 = try model_15.prediction(CGM: inputValues.CGM, carbs: inputValues.carbs, insulin: inputValues.insulin, CGM_5: inputValues.CGM_5, CGM_10: inputValues.CGM_10, CGM_15: inputValues.CGM_15, CGM_20: inputValues.CGM_20, CGM_25: inputValues.CGM_25, carbs_5: inputValues.carbs_5, carbs_10: inputValues.carbs_10, carbs_15: inputValues.carbs_15, carbs_20: inputValues.carbs_20, carbs_25: inputValues.carbs_25, insulin_5: inputValues.insulin_5, insulin_10: inputValues.insulin_10, insulin_15: inputValues.insulin_15, insulin_20: inputValues.insulin_20, insulin_25: inputValues.insulin_25).prediction
                let prediction_30 = try model_30.prediction(CGM: inputValues.CGM, carbs: inputValues.carbs, insulin: inputValues.insulin, CGM_5: inputValues.CGM_5, CGM_10: inputValues.CGM_10, CGM_15: inputValues.CGM_15, CGM_20: inputValues.CGM_20, CGM_25: inputValues.CGM_25, carbs_5: inputValues.carbs_5, carbs_10: inputValues.carbs_10, carbs_15: inputValues.carbs_15, carbs_20: inputValues.carbs_20, carbs_25: inputValues.carbs_25, insulin_5: inputValues.insulin_5, insulin_10: inputValues.insulin_10, insulin_15: inputValues.insulin_15, insulin_20: inputValues.insulin_20, insulin_25: inputValues.insulin_25).prediction
                let prediction_45 = try model_45.prediction(CGM: inputValues.CGM, carbs: inputValues.carbs, insulin: inputValues.insulin, CGM_5: inputValues.CGM_5, CGM_10: inputValues.CGM_10, CGM_15: inputValues.CGM_15, CGM_20: inputValues.CGM_20, CGM_25: inputValues.CGM_25, carbs_5: inputValues.carbs_5, carbs_10: inputValues.carbs_10, carbs_15: inputValues.carbs_15, carbs_20: inputValues.carbs_20, carbs_25: inputValues.carbs_25, insulin_5: inputValues.insulin_5, insulin_10: inputValues.insulin_10, insulin_15: inputValues.insulin_15, insulin_20: inputValues.insulin_20, insulin_25: inputValues.insulin_25).prediction
                let prediction_60 = try model_60.prediction(CGM: inputValues.CGM, carbs: inputValues.carbs, insulin: inputValues.insulin, CGM_5: inputValues.CGM_5, CGM_10: inputValues.CGM_10, CGM_15: inputValues.CGM_15, CGM_20: inputValues.CGM_20, CGM_25: inputValues.CGM_25, carbs_5: inputValues.carbs_5, carbs_10: inputValues.carbs_10, carbs_15: inputValues.carbs_15, carbs_20: inputValues.carbs_20, carbs_25: inputValues.carbs_25, insulin_5: inputValues.insulin_5, insulin_10: inputValues.insulin_10, insulin_15: inputValues.insulin_15, insulin_20: inputValues.insulin_20, insulin_25: inputValues.insulin_25).prediction
                let prediction_75 = try model_75.prediction(CGM: inputValues.CGM, carbs: inputValues.carbs, insulin: inputValues.insulin, CGM_5: inputValues.CGM_5, CGM_10: inputValues.CGM_10, CGM_15: inputValues.CGM_15, CGM_20: inputValues.CGM_20, CGM_25: inputValues.CGM_25, carbs_5: inputValues.carbs_5, carbs_10: inputValues.carbs_10, carbs_15: inputValues.carbs_15, carbs_20: inputValues.carbs_20, carbs_25: inputValues.carbs_25, insulin_5: inputValues.insulin_5, insulin_10: inputValues.insulin_10, insulin_15: inputValues.insulin_15, insulin_20: inputValues.insulin_20, insulin_25: inputValues.insulin_25).prediction
                let prediction_90 = try model_90.prediction(CGM: inputValues.CGM, carbs: inputValues.carbs, insulin: inputValues.insulin, CGM_5: inputValues.CGM_5, CGM_10: inputValues.CGM_10, CGM_15: inputValues.CGM_15, CGM_20: inputValues.CGM_20, CGM_25: inputValues.CGM_25, carbs_5: inputValues.carbs_5, carbs_10: inputValues.carbs_10, carbs_15: inputValues.carbs_15, carbs_20: inputValues.carbs_20, carbs_25: inputValues.carbs_25, insulin_5: inputValues.insulin_5, insulin_10: inputValues.insulin_10, insulin_15: inputValues.insulin_15, insulin_20: inputValues.insulin_20, insulin_25: inputValues.insulin_25).prediction
                let prediction_105 = try model_105.prediction(CGM: inputValues.CGM, carbs: inputValues.carbs, insulin: inputValues.insulin, CGM_5: inputValues.CGM_5, CGM_10: inputValues.CGM_10, CGM_15: inputValues.CGM_15, CGM_20: inputValues.CGM_20, CGM_25: inputValues.CGM_25, carbs_5: inputValues.carbs_5, carbs_10: inputValues.carbs_10, carbs_15: inputValues.carbs_15, carbs_20: inputValues.carbs_20, carbs_25: inputValues.carbs_25, insulin_5: inputValues.insulin_5, insulin_10: inputValues.insulin_10, insulin_15: inputValues.insulin_15, insulin_20: inputValues.insulin_20, insulin_25: inputValues.insulin_25).prediction
                let prediction_120 = try model_120.prediction(CGM: inputValues.CGM, carbs: inputValues.carbs, insulin: inputValues.insulin, CGM_5: inputValues.CGM_5, CGM_10: inputValues.CGM_10, CGM_15: inputValues.CGM_15, CGM_20: inputValues.CGM_20, CGM_25: inputValues.CGM_25, carbs_5: inputValues.carbs_5, carbs_10: inputValues.carbs_10, carbs_15: inputValues.carbs_15, carbs_20: inputValues.carbs_20, carbs_25: inputValues.carbs_25, insulin_5: inputValues.insulin_5, insulin_10: inputValues.insulin_10, insulin_15: inputValues.insulin_15, insulin_20: inputValues.insulin_20, insulin_25: inputValues.insulin_25).prediction
                let prediction_135 = try model_135.prediction(CGM: inputValues.CGM, carbs: inputValues.carbs, insulin: inputValues.insulin, CGM_5: inputValues.CGM_5, CGM_10: inputValues.CGM_10, CGM_15: inputValues.CGM_15, CGM_20: inputValues.CGM_20, CGM_25: inputValues.CGM_25, carbs_5: inputValues.carbs_5, carbs_10: inputValues.carbs_10, carbs_15: inputValues.carbs_15, carbs_20: inputValues.carbs_20, carbs_25: inputValues.carbs_25, insulin_5: inputValues.insulin_5, insulin_10: inputValues.insulin_10, insulin_15: inputValues.insulin_15, insulin_20: inputValues.insulin_20, insulin_25: inputValues.insulin_25).prediction
                let prediction_150 = try model_150.prediction(CGM: inputValues.CGM, carbs: inputValues.carbs, insulin: inputValues.insulin, CGM_5: inputValues.CGM_5, CGM_10: inputValues.CGM_10, CGM_15: inputValues.CGM_15, CGM_20: inputValues.CGM_20, CGM_25: inputValues.CGM_25, carbs_5: inputValues.carbs_5, carbs_10: inputValues.carbs_10, carbs_15: inputValues.carbs_15, carbs_20: inputValues.carbs_20, carbs_25: inputValues.carbs_25, insulin_5: inputValues.insulin_5, insulin_10: inputValues.insulin_10, insulin_15: inputValues.insulin_15, insulin_20: inputValues.insulin_20, insulin_25: inputValues.insulin_25).prediction
                let prediction_165 = try model_165.prediction(CGM: inputValues.CGM, carbs: inputValues.carbs, insulin: inputValues.insulin, CGM_5: inputValues.CGM_5, CGM_10: inputValues.CGM_10, CGM_15: inputValues.CGM_15, CGM_20: inputValues.CGM_20, CGM_25: inputValues.CGM_25, carbs_5: inputValues.carbs_5, carbs_10: inputValues.carbs_10, carbs_15: inputValues.carbs_15, carbs_20: inputValues.carbs_20, carbs_25: inputValues.carbs_25, insulin_5: inputValues.insulin_5, insulin_10: inputValues.insulin_10, insulin_15: inputValues.insulin_15, insulin_20: inputValues.insulin_20, insulin_25: inputValues.insulin_25).prediction
                let prediction_180 = try model_180.prediction(CGM: inputValues.CGM, carbs: inputValues.carbs, insulin: inputValues.insulin, CGM_5: inputValues.CGM_5, CGM_10: inputValues.CGM_10, CGM_15: inputValues.CGM_15, CGM_20: inputValues.CGM_20, CGM_25: inputValues.CGM_25, carbs_5: inputValues.carbs_5, carbs_10: inputValues.carbs_10, carbs_15: inputValues.carbs_15, carbs_20: inputValues.carbs_20, carbs_25: inputValues.carbs_25, insulin_5: inputValues.insulin_5, insulin_10: inputValues.insulin_10, insulin_15: inputValues.insulin_15, insulin_20: inputValues.insulin_20, insulin_25: inputValues.insulin_25).prediction
                
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
    
    func getPredictionSample(prediction: Double, date: Date, prediction_horizon: Double) -> BloodGlucoseModel {
        let newSample = BloodGlucoseModel(
            id: UUID(),
            date: date.addingTimeInterval(60*prediction_horizon),
            value: prediction / unit_k)
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

