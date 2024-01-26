//
//  BloodGlucoseModel.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 15/10/2023.
//

import Foundation
import RealmSwift

struct BloodGlucoseModelOld: Identifiable {
    let id: UUID
    let date: Date
    let value: Double
}

class BloodGlucoseModel: Object, Identifiable {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted var date: Date
    @Persisted var value: Double
}


