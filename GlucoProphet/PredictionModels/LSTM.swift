//
//  LSTM.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 19/01/2024.
//

import Foundation
import CoreML
import RealmSwift

let unit_k = 18.0182

// Example implementation of a class conforming to BaseModel
class LSTM: BaseModel {
    let identifier: String
    private let bgStore = BloodGlucoseStore.shared
    private let carbStore = CarbohydrateStore.shared
    private let insulinStore = InsulinStore.shared
    
    private var model_15: lstm__me__15?
    private var model_30: lstm__me__30?
    private var model_45: lstm__me__45?
    private var model_60: lstm__me__60?
    private var model_75: lstm__me__75?
    private var model_90: lstm__me__90?
    private var model_105: lstm__me__105?
    private var model_120: lstm__me__120?
    private var model_135: lstm__me__135?
    private var model_150: lstm__me__150?
    private var model_165: lstm__me__165?
    private var model_180: lstm__me__180?

    init(identifier: String) {
        self.identifier = identifier
        
        // Load the ML models once during initialization
        do {
            self.model_15 = try lstm__me__15(configuration: MLModelConfiguration())
            self.model_30 = try lstm__me__30(configuration: MLModelConfiguration())
            self.model_45 = try lstm__me__45(configuration: MLModelConfiguration())
            self.model_60 = try lstm__me__60(configuration: MLModelConfiguration())
            self.model_75 = try lstm__me__75(configuration: MLModelConfiguration())
            self.model_90 = try lstm__me__90(configuration: MLModelConfiguration())
            self.model_105 = try lstm__me__105(configuration: MLModelConfiguration())
            self.model_120 = try lstm__me__120(configuration: MLModelConfiguration())
            self.model_135 = try lstm__me__135(configuration: MLModelConfiguration())
            self.model_150 = try lstm__me__150(configuration: MLModelConfiguration())
            self.model_165 = try lstm__me__165(configuration: MLModelConfiguration())
            self.model_180 = try lstm__me__180(configuration: MLModelConfiguration())
        } catch {
            print("Error loading ML models: \(error)")
        }
    }
    
    func predict(tempBasal: Double, addedBolus: Double, addedCarbs: Double) -> [BloodGlucoseModel] {
        var predictions = [BloodGlucoseModel]()
        let regressionLength = 6
        
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
            guard let multiArray = try? MLMultiArray(shape: [1, 6, 3], dataType: .float32) else {
                fatalError("Error creating MLMultiArray")
            }
            
            for i in 0..<6 {
                // Blood Glucose
                multiArray[i * 3] = NSNumber(value: recentBloodGlucoseValues[i].value * unit_k)
                
                // Carbohydrates
                let carbs = i == 5 ? carbValues[i] + addedCarbs : carbValues[i]
                multiArray[i * 3 + 1] = NSNumber(value: carbs)
                
                // Insulin
                let insulin = i == 5 ? insulinValues[i] + addedBolus : insulinValues[i]
                multiArray[i * 3 + 2] = NSNumber(value: insulin)
            }
            
            let currentDate = recentBloodGlucoseValues[regressionLength - 1].date
            
            // Make the prediction
            if let prediction_15 = try model_15?.prediction(lstm_input: multiArray).Identity[0] {
                predictions.append(getPredictionSample(prediction: prediction_15, date: currentDate, prediction_horizon: 15))
            }
            if let prediction_30 = try model_30?.prediction(lstm_1_input: multiArray).Identity[0] {
                predictions.append(getPredictionSample(prediction: prediction_30, date: currentDate, prediction_horizon: 30))
            }
            if let prediction_45 = try model_45?.prediction(lstm_2_input: multiArray).Identity[0] {
                predictions.append(getPredictionSample(prediction: prediction_45, date: currentDate, prediction_horizon: 45))
            }
            if let prediction_60 = try model_60?.prediction(lstm_3_input: multiArray).Identity[0] {
                predictions.append(getPredictionSample(prediction: prediction_60, date: currentDate, prediction_horizon: 60))
            }
            if let prediction_75 = try model_75?.prediction(lstm_4_input: multiArray).Identity[0] {
                predictions.append(getPredictionSample(prediction: prediction_75, date: currentDate, prediction_horizon: 75))
            }
            if let prediction_90 = try model_90?.prediction(lstm_5_input: multiArray).Identity[0] {
                predictions.append(getPredictionSample(prediction: prediction_90, date: currentDate, prediction_horizon: 90))
            }
            if let prediction_105 = try model_105?.prediction(lstm_6_input: multiArray).Identity[0] {
                predictions.append(getPredictionSample(prediction: prediction_105, date: currentDate, prediction_horizon: 105))
            }
            if let prediction_120 = try model_120?.prediction(lstm_7_input: multiArray).Identity[0] {
                predictions.append(getPredictionSample(prediction: prediction_120, date: currentDate, prediction_horizon: 120))
            }
            if let prediction_135 = try model_90?.prediction(lstm_5_input: multiArray).Identity[0] {
                predictions.append(getPredictionSample(prediction: prediction_135, date: currentDate, prediction_horizon: 135))
            }
            if let prediction_150 = try model_150?.prediction(lstm_9_input: multiArray).Identity[0] {
                predictions.append(getPredictionSample(prediction: prediction_150, date: currentDate, prediction_horizon: 150))
            }
            if let prediction_165 = try model_165?.prediction(lstm_10_input: multiArray).Identity[0] {
                predictions.append(getPredictionSample(prediction: prediction_165, date: currentDate, prediction_horizon: 165))
            }
            if let prediction_180 = try model_180?.prediction(lstm_11_input: multiArray).Identity[0] {
                predictions.append(getPredictionSample(prediction: prediction_180, date: currentDate, prediction_horizon: 180))
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
}
