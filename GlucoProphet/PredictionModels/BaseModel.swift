//
//  BaseModel.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 04/01/2024.
//

import Foundation

// Base model protocol
protocol BaseModel {
    var identifier: String { get }
    
    // Function to predict
    func predict(tempBasal: Double, addedBolus: Double, addedCarbs: Double) -> [BloodGlucoseModel]
    
}

