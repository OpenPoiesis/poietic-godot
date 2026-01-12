//
//  ResultStepVisuals.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 25/11/2025.
//

import PoieticCore
import PoieticFlows

/// Synchronize indicators based on a simulation result.
///
/// The method sets initial value of indicators and sets indicator range from the
/// simulation result time series.
///
/// This method is typically called on design change.
///
/// - **Dependency:** No strict dependencies.
/// - **Input:** Objects with ``PoieticFlows/SimulationResult``.
/// - **Output:** Updates value indicator ranges in a canvas referenced in ``CanvasComponent``.
/// - **Forgiveness:** Nothing necessary.
struct IndicatorRangeConfigurationSystem: System {
    nonisolated(unsafe) public static let dependencies: [SystemDependency] = [
        .after(SimulationObjectsResultsSystem.self),
    ]
    public init() {}
    public func update(_ frame: AugmentedFrame) throws (InternalSystemError) {
        guard let result: SimulationResult = frame.component(for: .Frame),
              let canvasComponent: CanvasComponent = frame.component(for: .Frame)
        else { return }

        let canvas = canvasComponent.canvas
        
        for block in canvas.blocks {
            update(block: block, canvas: canvas, in: frame)
        }
    }
    public func update(block: DiagramCanvasBlock, canvas: DiagramCanvas, in frame: AugmentedFrame) {
        guard block.hasValueIndicator, // Whether we *should* have the indicator
              let valueIndicator = block.valueIndicator, // Whether we actually have it
              let id = block.objectID,
              let object = frame[id],
              let series: RegularTimeSeries = frame.component(for: id)
        else { return }

        let autoscaleFlag: Bool? = object["display_value_auto_scale"]

        // TODO: Rename to display_value_min, max, baseline (see poietic-flows metamodel)
        let rangeMin: Double? = object["indicator_min_value"]
        let rangeMax: Double? = object["indicator_max_value"]
        let baseline: Double? = object["indicator_mid_value"]

        let coalescedMin = coalesceRangeValue(requestedValue: rangeMin,
                                              autoValue: series.dataMin,
                                              defaultValue: ValueIndicatorRangeMinDefault,
                                              autoScale: autoscaleFlag)
        let coalescedMax = coalesceRangeValue(requestedValue: rangeMax,
                                              autoValue: series.dataMax,
                                              defaultValue: ValueIndicatorRangeMaxDefault,
                                              autoScale: autoscaleFlag)
        valueIndicator.baseline = coalesceRangeValue(requestedValue: baseline,
                                                     autoValue: series.dataMin,
                                                     defaultValue: coalescedMin,
                                                     autoScale: autoscaleFlag)

        // Safety range bounds swap
        valueIndicator.rangeMin = min(coalescedMin, coalescedMax)
        valueIndicator.rangeMax = max(coalescedMin, coalescedMax)
        // Clamp baseline within bounds
        valueIndicator.baseline = max(min(valueIndicator.baseline, valueIndicator.rangeMax), valueIndicator.rangeMin)

    }
    
}

/// - **Dependency:** No strict dependencies.
/// - **Input:** ``PoieticFlows/SimulationResult`` singleton, ``ResultPlayerState`` singleton.
/// - **Output:** Updates value indicators in ``DiagramCanvasBlock`` nodes.
/// - **Forgiveness:**
///     - If there is no player state, and the result is present, then first result value is used.
struct IndicatorValueUpdateSystem: System {
    nonisolated(unsafe) public static let dependencies: [SystemDependency] = [
        .after(SimulationObjectsResultsSystem.self),
        .after(IndicatorRangeConfigurationSystem.self),
    ]

    // public let dependencies: SystemDependency = [ /* after: simulation */ ]
    public init() {}
    public func update(_ frame: AugmentedFrame) throws (InternalSystemError) {
        guard let result: SimulationResult = frame.component(for: .Frame),
              let canvasComponent: CanvasComponent = frame.component(for: .Frame)
        else { return }

        let canvas = canvasComponent.canvas
        
        for block in canvas.blocks {
            update(block: block, canvas: canvas, in: frame)
        }
    }
    
    public func update(block: DiagramCanvasBlock, canvas: DiagramCanvas, in frame: AugmentedFrame) {
        guard block.hasValueIndicator, // Whether we *should* have the indicator
              let valueIndicator = block.valueIndicator // Whether we actually have it
        else { return }

        guard let id = block.objectID,
              let object = frame[id],
              let series: RegularTimeSeries = frame.component(for: id)
        else {
            valueIndicator.value = nil
            return
        }

        // Do not fail if there is no result player
        let time: ReplayTime? = frame.component(for: .Frame)
        let currentStep = time?.step ?? 0

        guard currentStep >= 0 && currentStep < series.data.count else {
            valueIndicator.value = nil
            return
        }
        
        valueIndicator.value = series.data[currentStep]
    }
}

func coalesceRangeValue(requestedValue: Double?, autoValue: Double, defaultValue: Double, autoScale: Bool?) -> Double {
    switch (requestedValue, autoScale) {
    case (.none,            .none):        defaultValue
    case (.none,            .some(false)): defaultValue
    case (.none,            .some(true)):  autoValue
    case (.some(let value), .none):        value
    case (.some(let value), .some(false)): value
    case (.some(_),         .some(true)):  autoValue
    }
}
