//
//  ContentView.swift
//  GlucoProphet
//
//  Created by Miriam K. Wolff on 15/10/2023.
//

import SwiftUI
import Charts

struct MainView: View {
    
    @EnvironmentObject var controller: MainViewController

    var body: some View {
        NavigationView {
            List {
                Section {
                    Chart {
                        ForEach(controller.pastValues, id: \.id) { series in
                            AreaMark(
                                x: .value("Date", series.date),
                                y: .value("Glucose value", series.value)
                            )
                            .foregroundStyle(
                                Gradient(colors: [Color.gray.opacity(0.6),
                                                  Color.gray.opacity(0.2),
                                                  Color.gray.opacity(0.1),
                                                  Color.gray.opacity(0.0),
                                                  Color.gray.opacity(0.0)]))
                            .interpolationMethod(.cardinal)
                            LineMark(
                                x: .value("Date", series.date),
                                y: .value("Glucose value", series.value)
                            )
                            .foregroundStyle(Color.gray.opacity(0.8))
                            .lineStyle(StrokeStyle(lineWidth: 5.0))
                            .interpolationMethod(.cardinal)
                            PointMark(
                                x: .value("Date", series.date),
                                y: .value("Glucose value", series.value)
                            )
                            .symbolSize(50.0)
                            .foregroundStyle(getColor(value: series.value))
                        }
                        ForEach(controller.predictedValues, id: \.id) { series in
                            PointMark(
                                x: .value("Date", series.date),
                                y: .value("Glucose value", series.value)
                            )
                            .symbolSize(50.0)
                            .foregroundStyle(getColor(value: series.value))
                            .interpolationMethod(.cardinal)
                        }
                    }
                    .frame(height: 300)
                    .chartYScale(domain: 2.0...15.0)
                    .scrollDisabled(true)
                    // Overlay for the selected element
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    SpatialTapGesture()
                                        .onEnded { value in
                                            let element = findElement(location: value.location,
                                                                      proxy: proxy,
                                                                      geometry: geo)
                                            if controller.selectedElement?.date == element?.date {
                                                // If tapping the same element, clear the selection.
                                                controller.selectedElement = nil
                                            } else {
                                                controller.selectedElement = element
                                            }
                                        }
                                        .exclusively(before: DragGesture()
                                            .onChanged { value in
                                                controller.selectedElement = findElement(location: value.location,
                                                                              proxy: proxy,
                                                                              geometry: geo)
                                            })
                                )
                        }
                    }
                    .chartBackground { proxy in
                        ZStack(alignment: .topLeading) {
                            GeometryReader { geo in
                                if let selected = controller.selectedElement {
                                    // Find date span for the selected interval
                                    // Using callendar.current will display it in the correct time zone
                                    let dateInterval = Calendar.current.dateInterval(of: .minute, for: selected.date)!
                                    
                                    // Map date to chart X position
                                    let startPositionX = proxy.position(forX: dateInterval.start) ?? 0
                                    // Offset the chart X position by chart frame
                                    let midStartPositionX = startPositionX + geo[proxy.plotAreaFrame].origin.x
                                    let lineHeight = geo[proxy.plotAreaFrame].maxY
                                    let boxWidth: CGFloat = 75
                                    let boxOffset = max(0, min(geo.size.width - boxWidth, midStartPositionX - boxWidth / 2))
                                    
                                    // Draw the scan line
                                    Rectangle()
                                        .fill(.quaternary)
                                        .frame(width: 2, height: lineHeight)
                                        .position(x: midStartPositionX, y: lineHeight / 2)
                                    
                                    // Draw the data info box
                                    VStack(alignment: .center) {
                                        Text("\(selected.date, format: .dateTime.hour().minute())")
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                        Text(String(format: "%.1f", selected.value))
                                            .font(.title2.bold())
                                            .foregroundColor(.primary)
                                        Text("mmol/L")
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(width: boxWidth, alignment: .center)
                                    .background { // some styling
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(.background)
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(.quaternary.opacity(0.7))
                                        }
                                        .padding([.leading, .trailing], -8)
                                        .padding([.top, .bottom], -4)
                                    }
                                    .offset(x: boxOffset)
                                }
                            }
                        }
                    }
                }
                Section {
                    /*
                    VStack {
                        // Change basal rate insulin slider
                        HStack {
                            Text("Basal insulin")
                            Spacer()
                            Text("\(controller.tempBasal, specifier: "%.1f") U/hr")
                        }
                        Slider(value: $controller.tempBasal, in: 0...2.0, step: 0.1)
                    }*/
                    VStack {
                        // Add bolus insulin slider
                        HStack {
                            Text("Add insulin dose")
                            Spacer()
                            Text("\(controller.addedBolus, specifier: "%.1f") U")
                        }
                        Slider(value: $controller.addedBolus, in: 0...10, step: 0.1)
                    }
                    VStack {
                        // Add carbohydrate intake slider
                        HStack {
                            Text("Add carbohydrate intake")
                            Spacer()
                            Text("\(controller.addedCarbs, specifier: "%.0f") g")
                        }
                        Slider(value: $controller.addedCarbs, in: 0...100, step: 5)
                    }
                    VStack {
                        // Add picker menu for different prediction models
                        Picker("Select Model", selection: $controller.selectedModel) {
                            ForEach(["RidgeRegressor", "LSTM"], id: \.self) { model in
                                Text(model)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
            }
            .navigationBarTitle("Glucose Prediction")
        }
    }
    
    func findElement(location: CGPoint,
                     proxy: ChartProxy,
                     geometry: GeometryProxy) -> BloodGlucoseModel? {
        // Figure out the X position by offseting gesture location with chart frame
        let relativeXPosition = location.x - geometry[proxy.plotAreaFrame].origin.x
        // Use value(atX:) to find plotted value for the given X axis position.
        // Since FoodIntake chart plots `date` on the X axis, we'll get a Date back.
        if let date = proxy.value(atX: relativeXPosition) as Date? {
            // Find the closest date element.
            var minDistance: TimeInterval = .infinity
            var index: Int? = nil
            let completeList: [BloodGlucoseModel] = controller.pastValues + controller.predictedValues
            for dataIndex in completeList.indices {
                let nthDataDistance = completeList[dataIndex].date.distance(to: date)
                if abs(nthDataDistance) < minDistance {
                    minDistance = abs(nthDataDistance)
                    index = dataIndex
                }
            }
            if let index {
                return completeList[index]
            }
        }
        return nil
    }
    
    func getColor(value: Double) -> Color {
        if (value > 10.0 || value < 4.0) {
            return Color.red
        }
        else {
            return Color.green
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
