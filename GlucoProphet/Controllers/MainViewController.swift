//
//  MainViewController.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 15/10/2023.
//

import HealthKit
import CoreML
import CoreMotion

class MainViewController: NSObject, ObservableObject {
    
    override init() {
        super.init()
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            self.fetchData {
                DispatchQueue.main.async {
                    self.selectedElement = self.pastValues.last
                }
            }
        }
    }
    
    @Published var selectedElement: BloodGlucoseModel?
    @Published var pastValues = [BloodGlucoseModel]()
    @Published var predictedValues = [BloodGlucoseModel]()
        
    private let bgStore = BloodGlucoseStore.shared
    private let insulinStore = InsulinStore.shared
    private let carbStore = CarbohydrateStore.shared
    // private let predictionModel = MockModel(identifier: "MockModel")
    // private let predictionModel = RidgeRegressor(identifier: "RidgeRegressor")
    private let predictionModel = LSTM(identifier: "LSTM")
    
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
   
    /// This method is triggered on the launch of the application and does the following:
    /// 1) A dispatchgroup makes sure that all the different datatypes are fetched that is needed as an input in the machine learning model for the first prediction
    /// 2) At the same time, the updateHandlers for the HealthKit queries are triggered, and initialized to evoke new blood glucose predictions when a sample is added/deleted
    /// 3) When all the DispatchGroups are completed, the .notify method is called, and the first predictions are made
    /// 4) At the end, the activity-classifier is started
    ///
    func fetchData(completion: @escaping () -> Swift.Void) {
        // DispatchGroup makes sure all values from HealthKit are fetched before we call the first prediction
                
        let group = DispatchGroup()
                
        // First group is fetching glucose values, make sure it finished before the first prediction is called
        /*
        // Get relevant insulin values
        group.enter()
        self.insulinStore.starObserver(completion: {
            group.leave()
        }, updateHandler: {
            self.fetchPredictions()
        })*/
        
        // Get relevant carbohydrate consumptions
        group.enter()
        self.carbStore.starObserver(completion: {
            group.leave()
        }, updateHandler: {
            self.fetchPredictions()
        })
        
        group.enter()
        self.bgStore.startObserver(completion: {
            DispatchQueue.main.async {
                self.pastValues = self.bgStore.bgSamples
            }
            group.leave()
        }, updateHandler: {
            self.fetchPredictions()
            if let newestBgSample = self.bgStore.bgSamples.last {
                // Move Lollipop when there is a new sample
                DispatchQueue.main.async {
                    self.pastValues = self.bgStore.bgSamples
                    self.selectedElement = newestBgSample
                }
            }
        })

        // TODO: This should be refetched more often than on launch of the application
        
        // Make predictions after we made sure that the glucose, carbs and insulin samples are collected
        group.notify(queue: DispatchQueue.main) {
            self.fetchPredictions()
            completion()
        }
    }
    
    /// This method calculates new blood glucose predictions based on the most recent stored data inputs.
    /// This method must always be called on the main thread, because it updates the UI.
    private func fetchPredictions() {
        DispatchQueue.main.async {
            self.predictedValues = self.predictionModel.predict(tempBasal: self.tempBasal, addedBolus: self.addedBolus, addedCarbs: self.addedCarbs)
        }
    }
    
    private func roundedValue(value: Double, decimals: Double) -> Double {
        return Double(round(pow(10, decimals) * value) / pow(10, decimals))
    }
}

