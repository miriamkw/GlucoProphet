//
//  RidgeRegressor.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 08/01/2024.
//

import Foundation

// Example implementation of a class conforming to BaseModel
class RidgeRegressor: BaseModel {
    let identifier: String
    private let bgStore = BloodGlucoseStore.shared
    
    init(identifier: String) {
        self.identifier = identifier
    }
    
    func predict(tempBasal: Double, addedBolus: Double, addedCarbs: Double) -> [BloodGlucoseModel] {
        /*
         TO DO:
         1. Fetch model input data and store it into an input dictionary
         2. Transform data
         3. Predict and return samples
         */
        var input_dict = [String: Double]()
        var predictions = [BloodGlucoseModel]()
        
        // TO DO: Create input_dict with fetched data, using dispatchgroups?
        guard bgStore.bgSamples.count >= 4 else {
            // When there are no blood glucose measurements available, return an empty list of predictions
            return []
        }
        let bgMean = 150.0 / 18.0
        let bgStdDev = 51.0 / 18.0
        let lastFourSamples = Array(bgStore.bgSamples.suffix(4))
        
        input_dict["CGM"] = scaleValue(value: lastFourSamples[3].value, mean: bgMean, stdDev: bgStdDev)
        input_dict["CGM_5"] = scaleValue(value: lastFourSamples[2].value, mean: bgMean, stdDev: bgStdDev)
        input_dict["CGM_10"] = scaleValue(value: lastFourSamples[1].value, mean: bgMean, stdDev: bgStdDev)
        input_dict["CGM_15"] = scaleValue(value: lastFourSamples[0].value, mean: bgMean, stdDev: bgStdDev)
        print("INPUT DICT", input_dict)
        
        // TODO: Call all predict methods with input_dict and return predictions. Hardcoding to start with.
        if let newestBgSample = bgStore.bgSamples.last {
            var prediction = predict_30(input_dict: input_dict)
            prediction = (prediction) < 2.0 ? 2.0 : prediction
            print("PREDICTION", prediction)
            
            let newSample = BloodGlucoseModel(
                id: UUID(),
                date: newestBgSample.date.addingTimeInterval(60*5*6),
                value: prediction / 18.0)
            predictions.append(newSample)
        }
        return predictions
    }
    
    
    // TODO: Reorganize to avoid redundancy in this code.
    func predict_30(input_dict: [String: Double]) -> Double {
        let coefficients: [String: Double] = [
            "CGM": 1.17360542e+02,
            "CGM_5": 1.17360542e+02,
            "CGM_10": 1.17360542e+02,
            "CGM_15": 1.17360542e+02
        ]
        
        var prediction: Double = 0.0
        
        for (key, value) in input_dict {
            if let coefficient = coefficients[key] {
                prediction += coefficient * value
            }
        }

        return prediction
    }
    
    func scaleValue(value: Double, mean: Double, stdDev: Double) -> Double {
        // Transform data with standard scaling
        guard stdDev != 0 else {
            // Handle the case where the standard deviation is zero to avoid division by zero
            return Double.nan // or handle it as appropriate for your use case
        }
        
        return (value - mean) / stdDev
    }
    
    
}

