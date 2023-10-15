//
//  InsulinStore.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 15/10/2023.
//

import HealthKit

// TODO: The current version is using insulinmodels etc.

class InsulinStore {
    
    var insulinSamples = [HKQuantitySample]()
    
    // TODO: Insert scheduled basal rates using different times on day!
    private let scheduledBasalRate = 0.9 // Units per hour
    private let healthKitDataStore = HealthKitDataStore.shared
    
    private var totalDuration: Double {
        return 60*60 // TODO: How many samples to include?
    }
    // Create singleton instance
    static let shared = InsulinStore()
    
    func getInsulinDeliverySampleType() -> HKSampleType {
        guard let insulinDeliverySampleType = HKSampleType.quantityType(forIdentifier: .insulinDelivery) else {
          fatalError("Insulin Delivery Sample Type is no longer available in HealthKit")
        }
        return insulinDeliverySampleType
    }
    
    func starObserver(completion: @escaping () -> Swift.Void, updateHandler: @escaping () -> Swift.Void) {
        self.healthKitDataStore.getSamples(for: getInsulinDeliverySampleType(), start: Date().addingTimeInterval(-TimeInterval(totalDuration)), completion: { (samples, deleted) in
            self.setInsulinValues(samples: samples, deleted: deleted)
            completion()
        }, updateHandler: { (samples, deleted) in
            self.setInsulinValues(samples: samples, deleted: deleted)
            updateHandler()
        })
    }
    
    private func setInsulinValues(samples: [HKQuantitySample], deleted: [HKDeletedObject]) {
        var mostRecentSamples = insulinSamples
        // Filter out glucose values that no longer are relevant
        mostRecentSamples.removeAll { sample in
            sample.endDate < Date().addingTimeInterval(-TimeInterval(totalDuration))
        }
        // Add new samples
        mostRecentSamples.append(contentsOf: samples)
        // Remove deleted samples
        mostRecentSamples.removeAll { sample in
            deleted.contains { deletedObject in
                deletedObject.uuid == sample.uuid
            }
        }
        self.insulinSamples = mostRecentSamples
    }
    
    /// Given a set of insulin doses, get the insulin on board for a given date.
    /// Note: This includes basal rates, and assumes date basal rates are delivered
    /// with a five minute interval. Basal rates might have a large delay to be registered in HealthKit, so in the end it is added the scheduled rate to the calculation.
    ///
    /// - parameter samples: Insulin dose samples from HealthKit
    /// - parameter date: Date to calculate insulin on board
    /// - returns: Insulin on board for the given time interval for the given insulin samples
    ///
    func getIOB(date: Date, tempBasal: Double, addedBolus: Double = 0.0) -> Double {
        var res = 0.0
        var lastBasalDate = date.addingTimeInterval(-TimeInterval(totalDuration))
        
        for sample in insulinSamples {
            // Delivery reason separates basal rates (=1) from bolus doses (=2)
            guard let deliveryReason = sample.metadata?["HKInsulinDeliveryReason"] else {
                fatalError("Insulin dose without delivery reason in metadata")
            }
            if ("\(deliveryReason)" == "1") {
                lastBasalDate = sample.endDate
            }
            var insulinDoseQuantity = sample.quantity.doubleValue(for: .internationalUnit())
            let timeSinceInsulinDose = date.timeIntervalSince(sample.endDate)/60 // In minutes, positive when it happened in the past
            let insulinDoseTimeSpan = sample.startDate.distance(to: sample.endDate)/60
            let n = Int(round(insulinDoseTimeSpan / 5))

            // Skip current iteration of for loop for doses that will happen in the future, or is older than totalDuration
            if ((timeSinceInsulinDose < 0) || (timeSinceInsulinDose > totalDuration/60)) {
                continue
            }
            // If the insulin dose happened for over 7 minutes, the dose will be split into five minute intervals
            if (n > 1) {
                insulinDoseQuantity = insulinDoseQuantity / Double(n)
                for i in 0...n-1 {
                    // If the splitting creates dose in the future, break the for loop
                    let currentStartDate = sample.startDate.addingTimeInterval(TimeInterval(5*60*i))
                    if (date.timeIntervalSince(currentStartDate) < 0) {
                        break
                    }
                    res = res + insulinDoseQuantity
                }
            } else {
                res = res + insulinDoseQuantity
            }
        }
        // Add added bolus from UI
        res = res + addedBolus
        
        // Add basal doses from unregistered basal
        // Scheduled basal rates are not pump events and will not be written in each Loop cycle: https://loopkit.github.io/loopdocs/faqs/apple-health-faqs/#basal
        // Only when there is a new temp or shceduled basal
        // Hence, we will search for the last written basal rate, and generate
        // This might in some circumstances create wrong values (if the most recent adjustment is a temp basal, because we will assume that it is the scheduled one)
        // However, usually while using closed loop the temp basal will change often, so the effect will be negigable. If not closed-loop, it will not be a problem.
        let intervalsSinceLastBasal = Int(round(lastBasalDate.distance(to: Date())/60 / 5))
        if intervalsSinceLastBasal > 0 {
            for _ in 0...(intervalsSinceLastBasal) {
                res = res + scheduledBasalRate/12
            }
        }
        // Add basal doses from temporary future basal
        let intervalsSinceDose = Int(round(Date().distance(to: date)/60 / 5))
        if intervalsSinceDose > 0 {
            for _ in 0...(intervalsSinceDose) {
                res = res + tempBasal/12
            }
        }
        return res
    }
    
     /// Given a set of insulin doses, get the absorbed insulin between two dates. Basal rates might have a large delay to be registered in HealthKit, so in the end it is added the scheduled rate to the calculation.
     ///
     /// - parameter samples: Insulin dose samples from HealthKit
     /// - parameter startDate: Start date to calculate absorbed insulin
     /// - parameter endDate: End date to calculate absorbed insulin
     /// - returns: Absorbed insulin in the given time interval for the given insulin samples
     ///
    func getAbsorbedInsulin(startDate: Date, endDate: Date, tempBasal: Double, addedBolus: Double = 0.0) -> Double {
         if (startDate.timeIntervalSince(endDate) > 0) {
             fatalError("Start date passed is larger than end date!")
         }
        var res = 0.0
        var lastBasalDate = startDate.addingTimeInterval(-TimeInterval(totalDuration))
        for sample in insulinSamples {
            guard let deliveryReason = sample.metadata?["HKInsulinDeliveryReason"] else {
                fatalError("Insulin dose without delivery reason in metadata")
            }
            if ("\(deliveryReason)" == "1") {
                lastBasalDate = sample.endDate
            }
            var insulinDoseQuantity = sample.quantity.doubleValue(for: .internationalUnit())
            let timeSinceInsulinDose = startDate.timeIntervalSince(sample.endDate)/60 // In minutes, positive when it happened in the past
            let insulinDoseTimeSpan = sample.startDate.distance(to: sample.endDate)/60
            let n = Int(round(insulinDoseTimeSpan / 5))
            
            // Skip current iteration of for loop for doses that will happen in the future (from startDate), or is older than totalDuration
            if (timeSinceInsulinDose < 0 || (timeSinceInsulinDose > totalDuration/60)) {
                continue
            }
            
            // If the insulin dose happened for over 7 minutes, the dose will be split into five minute intervals
            if (n > 1) {
                insulinDoseQuantity = insulinDoseQuantity / Double(n)
                for _ in 0...n-1 {
                    res = res + insulinDoseQuantity
                }
            } else {
                res = res + insulinDoseQuantity
            }
        }
        // Add added bolus
        res = res + addedBolus
        
        // Add basal doses from unregistered basal
        let intervalsSinceLastBasal = Int(round(lastBasalDate.distance(to: Date())/60 / 5))
        if intervalsSinceLastBasal > 0 {
            for _ in 0...(intervalsSinceLastBasal-1) {
                res = res + scheduledBasalRate/12
            }
        }
        
        // Add basal doses from temporary future basal
        let intervalsSinceDose = Int(round(Date().distance(to: startDate)/60 / 5))
        for _ in 0...(intervalsSinceDose) {
            res = res + tempBasal/12
        }

        return res
    }
}


