//
//  InsulinModel.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 26/01/2024.
//

import Foundation
import RealmSwift

class InsulinModel: Object, Identifiable {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted var date: Date
    @Persisted var value: Double
}
