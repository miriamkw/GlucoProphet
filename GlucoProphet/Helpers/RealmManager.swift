//
//  RealmManager.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 26/01/2024.
//

import Foundation
import RealmSwift

class RealmManager {
    
    // Create singleton instance
    static let shared = RealmManager()
    
    func write(_ object: Object) {
        do {
            let realm = try Realm()
            try realm.write {
                realm.add(object)
            }
        } catch {
            print("Error saving object to Realm \(error)")
        }
    }
    
    func deleteObjectWithUUID<T: Object>(_ objectType: T.Type, uuid: UUID) {
        do {
            let realm = try Realm()

            // Delete the object with the specified UUID
            if let objectToDelete = realm.object(ofType: objectType, forPrimaryKey: uuid) {
                try realm.write {
                    realm.delete(objectToDelete)
                }
            }
        } catch {
            print("Error deleting object in Realm \(error)")
        }
    }

    // Delete all objects that are older than the given time interval
    func deleteObjectsOlderThanTimeInterval<T: Object>(_ objectType: T.Type, timeInterval: Double) {
        do {
            let realm = try Realm()
            
            // Delete blood glucose measurements that are no longer relevant
            let outdatedObjects = realm.objects(objectType).filter("date < %@", Date().addingTimeInterval(-timeInterval))

            try realm.write {
                realm.delete(outdatedObjects)
            }
        } catch {
            print("Error deleting object in Realm \(error)")
        }
    }
    
    func existsRealmObject<T: Object>(_ objectType: T.Type, uuid: UUID) -> Bool {
        do {
            let realm = try Realm()
            return realm.object(ofType: objectType, forPrimaryKey: uuid) != nil
        } catch {
            print("Error accessing Realm, \(error)")
            return false
        }
    }
    
    func printAll<T: Object>(_ objectType: T.Type) {
        do {
            let realm = try Realm()
            
            let allInstances = realm.objects(objectType)
            print("All instances of \(objectType)")
            // Print the instances
            for instance in allInstances {
                print(instance)
            }

        } catch {
            print("Error initialising new realm, \(error)")
        }
    }
}
