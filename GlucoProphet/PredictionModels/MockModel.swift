//
//  MockModel.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 04/01/2024.
//

import Foundation
import RealmSwift

// Example implementation of a class conforming to BaseModel
class MockModel: BaseModel {
    let identifier: String
    private let bgStore = BloodGlucoseStore.shared
    
    init(identifier: String) {
        self.identifier = identifier
    }
    
    func predict(tempBasal: Double, addedBolus: Double, addedCarbs: Double) -> [BloodGlucoseModel] {
        var predictions = [BloodGlucoseModel]()
        
        do {
            let realm = try Realm()
            guard let newestBgSample = realm.objects(bgStore.realmObjectType).sorted(byKeyPath: "date", ascending: true).last else {
                return []
            }
            for i in 0..<24 {
                let basalFactor = tempBasal * Double(i) * 0.1
                let bolusFactor = addedBolus * Double(i) * 0.1
                let carbFactor = addedCarbs * Double(i) * 0.01

                var prediction = newestBgSample.value - basalFactor - bolusFactor + carbFactor
                prediction = (prediction) < 2.0 ? 2.0 : prediction
                
                let newSample = BloodGlucoseModel()
                newSample.id = UUID()
                newSample.date = newestBgSample.date.addingTimeInterval(60*5*Double(i + 1))
                newSample.value = prediction

                predictions.append(newSample)
            }
        } catch {
            print("Error initialising new realm, \(error)")
        }
        return predictions
    }
    
}
