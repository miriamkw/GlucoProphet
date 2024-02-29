//
//  MainViewController.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 15/10/2023.
//

import HealthKit
import CoreML
import CoreMotion
import RealmSwift

class MainViewController: NSObject, ObservableObject {
        
    override init() {
        super.init()

        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            // After setting pastValues, call fetchData on the main thread
            DispatchQueue.main.async {
                self.fetchData()
                self.fetchPredictions()
                self.setLollipopValue()
            }
        }
    }
    
    @Published var selectedElement: BloodGlucoseModel?
    @Published var predictedValues = [BloodGlucoseModel]()
        
    private let bgStore = BloodGlucoseStore.shared
    private let insulinStore = InsulinStore.shared
    private let carbStore = CarbohydrateStore.shared
    private let realmManager = RealmManager.shared
    
    // private let predictionModel = MockModel(identifier: "MockModel")
    private let ridge = RidgeRegressor(identifier: "RidgeRegressor")
    private let ridge_new = RidgeRegressorNew(identifier: "RidgeRegressorNew")
    private let lstm = LSTM(identifier: "LSTM")
    private let lstm_new = LSTMNew(identifier: "LSTMNew")
        
    // UI state variables
    @Published var tempBasal = 0.9 {
        didSet {
            if !(tempBasal == oldValue) {
                fetchPredictions()
            }
        }
    }
    @Published var addedBolus = 0.0 {
        didSet {
            if !(addedBolus == oldValue) {
                fetchPredictions()
            }
        }
    }
    @Published var addedCarbs = 0.0 {
        didSet {
            if !(addedCarbs == oldValue) {
                fetchPredictions()
            }
        }
    }
    @Published var selectedModel = "RidgeRegressor" {
        didSet {
            if !(selectedModel == oldValue) {
                fetchPredictions()
                setLollipopValue()
            }
        }
    }
   
    /// This method is triggered on the launch of the application and does the following:
    /// 1) A dispatchgroup makes sure that all the different datatypes are fetched that is needed as an input in the machine learning model for the first prediction
    /// 2) At the same time, the updateHandlers for the HealthKit queries are triggered, and initialized to evoke new blood glucose predictions when a sample is added/deleted
    /// 3) When all the DispatchGroups are completed, the .notify method is called, and the first predictions are made
    /// 4) At the end, the activity-classifier is started
    ///
    func fetchData() {
        // DispatchGroup makes sure all values from HealthKit are fetched before we call the first prediction
        
        let group = DispatchGroup()
                
        // First group is fetching glucose values, make sure it finished before the first prediction is called
        
        // Get relevant insulin values
        group.enter()
        self.insulinStore.starObserver(completion: {
            group.leave()
        }, updateHandler: {
            self.fetchPredictions()
        })
        
        // Get relevant carbohydrate consumptions
        group.enter()
        self.carbStore.starObserver(completion: {
            group.leave()
        }, updateHandler: {
            self.fetchPredictions()
        })
        
        group.enter()
        self.bgStore.startObserver(completion: {
            self.setLollipopValue()
            group.leave()
        }, updateHandler: {            
            self.fetchPredictions()
            // Move Lollipop when there is a new sample
            self.setLollipopValue()
        })

        // Make predictions after we made sure that the glucose, carbs and insulin samples are collected
        group.notify(queue: DispatchQueue.main) {
            self.fetchPredictions()
        }
    }
    
    /// This method calculates new blood glucose predictions based on the most recent stored data inputs.
    /// This method must always be called on the main thread, because it updates the UI.
    private func fetchPredictions() {
        DispatchQueue.main.async {
            var predictions: [BloodGlucoseModel] = []
            if self.selectedModel == "LSTM" {
                predictions = self.lstm.predict(tempBasal: self.tempBasal, addedBolus: self.addedBolus, addedCarbs: self.addedCarbs)
            } else if self.selectedModel == "LSTMNew" {
                predictions = self.lstm_new.predict(tempBasal: self.tempBasal, addedBolus: self.addedBolus, addedCarbs: self.addedCarbs)
            } else if self.selectedModel == "RidgeRegressorNew" {
                predictions = self.ridge_new.predict(tempBasal: self.tempBasal, addedBolus: self.addedBolus, addedCarbs: self.addedCarbs)
            } else {
                predictions = self.ridge.predict(tempBasal: self.tempBasal, addedBolus: self.addedBolus, addedCarbs: self.addedCarbs)
            }
            // Add linear interpolation between each predicted sample so that there is a predicted measurement for every 5-minute interval
            self.predictedValues = self.generateInterpolatedSamples(predictions: predictions)
        }
    }
    
    /// Generate linearnly interpolated samples with 5-minute intervals between each predicted value.
    func generateInterpolatedSamples(predictions: [BloodGlucoseModel]) -> [BloodGlucoseModel] {
        var interpolatedSamples = [BloodGlucoseModel]()
        
        do {
            let realm = try Realm()
            guard let newestBgSample = realm.objects(bgStore.realmObjectType).sorted(byKeyPath: "date", ascending: true).last else {
                return []
            }
            
            for i in 0..<predictions.count {
                let currentPrediction = predictions[i]
                let previousPrediction = i == 0 ? newestBgSample : predictions[i - 1]
                
                // Calculate the time difference between current and previous predictions
                let timeDifference = currentPrediction.date.timeIntervalSince(previousPrediction.date)
                
                // Calculate the number of 5-minute intervals between predictions
                let numberOfIntervals = Int(timeDifference / (5 * 60)) - 1
                
                if numberOfIntervals > 0 {
                    // Perform linear interpolation
                    for j in 1...numberOfIntervals {
                        let interpolationFactor = Double(j) / Double(numberOfIntervals + 1)
                        let interpolatedValue = (1 - interpolationFactor) * previousPrediction.value + interpolationFactor * currentPrediction.value
                        
                        let interpolatedSample = BloodGlucoseModel()
                        interpolatedSample.id = UUID()
                        interpolatedSample.date = previousPrediction.date.addingTimeInterval(5 * 60 * Double(j))
                        interpolatedSample.value = interpolatedValue
                        
                        interpolatedSamples.append(interpolatedSample)
                    }
                    // Add the current prediction
                    interpolatedSamples.append(currentPrediction)
                } else {
                    interpolatedSamples.append(currentPrediction)
                }
            }
        } catch {
            print("Error initialising new realm, \(error)")
        }
        return interpolatedSamples
    }
    
    private func roundedValue(value: Double, decimals: Double) -> Double {
        return Double(round(pow(10, decimals) * value) / pow(10, decimals))
    }
    
    private func setLollipopValue() {
        DispatchQueue.main.async {
            do {
                let realm = try Realm()
                if let newestBgSample = realm.objects(self.bgStore.realmObjectType).sorted(byKeyPath: "date", ascending: true).last {
                    self.selectedElement = newestBgSample
                }
            } catch {
                print("Error initialising new realm, \(error)")
            }
        }
    }
}

