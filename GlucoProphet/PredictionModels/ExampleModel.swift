//
//  ExampleModel.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 04/01/2024.
//

import Foundation

// Example implementation of a class conforming to BaseModel
class ExampleModel: BaseModel {
    let identifier: String
    private let bgStore = BloodGlucoseStore.shared
    
    init(identifier: String) {
        self.identifier = identifier
    }
    
    func predict(tempBasal: Double, addedBolus: Double, addedCarbs: Double) -> [BloodGlucoseModel] {
        var predictions = [BloodGlucoseModel]()
        
        if let newestBgSample = bgStore.bgSamples.last {
            for i in 0..<24 {
                let basalFactor = tempBasal * Double(i) * 0.1
                let bolusFactor = addedBolus * Double(i) * 0.1
                let carbFactor = addedCarbs * Double(i) * 0.01

                var prediction = newestBgSample.value - basalFactor - bolusFactor + carbFactor
                prediction = (prediction) < 2.0 ? 2.0 : prediction
                
                let newSample = BloodGlucoseModel(
                    id: UUID(),
                    date: newestBgSample.date.addingTimeInterval(60*5*Double(i + 1)),
                    value: prediction)
                predictions.append(newSample)
            }
        }
        return predictions
    }
    
}
