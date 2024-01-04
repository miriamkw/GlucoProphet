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
        // First group is fetching glucose values, make sure it finished before making predictions
        /*
        // Get relevant insulin values
        group.enter()
        self.insulinStore.starObserver(completion: {
            group.leave()
        }, updateHandler: {
            self.fetchPredictions()
        })*/
        /*
        // Get relevant carbohydrate consumptions
        group.enter()
        self.carbStore.starObserver(completion: {
            group.leave()
        }, updateHandler: {
            self.fetchPredictions()
        })*/
        
        group.enter()
        self.bgStore.starObserver(completion: {
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
    ///
    private func fetchPredictions() {
        var predictions: [BloodGlucoseModel] = []
        guard let refSample = bgStore.bgSamples.last else {
            fatalError("Failed to fetch last glucose value")
        }
        //var currentValue = refSample.value
        let refSamples = bgStore.bgSamples.suffix(6)
        if refSamples.count == 6 {
            // Mean and stdev from dataset for standardization and destandardization
            let mean = 159.76930886832153
            let stdev = 60.379903503417154
            var data = [Double]()
            for sample in refSamples {
                let val = (sample.value*18 - mean)/stdev
                data.append(val)
            }
            guard let mlMultiArray = try? MLMultiArray(shape:[1,6,1], dataType: MLMultiArrayDataType.float32) else {
                fatalError("Unexpected runtime error. MLMultiArray")
            }
            for (index, element) in data.enumerated() {
                mlMultiArray[index] = NSNumber(floatLiteral: element)
            }

            let predConverted = 6.0
            let newValue = (predConverted) < 2.0 ? 2.0 : predConverted
            let newSample = BloodGlucoseModel(
                id: UUID(),
                date: refSample.date.addingTimeInterval(60*5*6),
                value: newValue)
            predictions.append(newSample)

            let predConverted2 = 7.0
            let newValue2 = (predConverted2) < 2.0 ? 2.0 : predConverted2
            let newSample2 = BloodGlucoseModel(
                id: UUID(),
                date: refSample.date.addingTimeInterval(60*5*12),
                value: newValue2)
            predictions.append(newSample2)
            
            DispatchQueue.main.async {
                self.predictedValues = predictions
            }
        }
    }
    
    private func roundedValue(value: Double, decimals: Double) -> Double {
        return Double(round(pow(10, decimals) * value) / pow(10, decimals))
    }
}

