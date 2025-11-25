//
//  ResultProcessing.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 25/11/2025.
//

import PoieticCore
import PoieticFlows

struct ResultReplayState: Component {
    let isRunning: Bool = false
    let isLooping: Bool = true
    let timeToStep: Double = 0
    let stepDuration: Double = 0.1
    let currentStep: Int = 0
}

/// System that associates objects with time value series.
///
/// - **Dependency:** ...
/// - **Input:** Object with ``PoieticFlows/SimulationResult``and ``PoieticFlows/SimulationPlan``.
/// - **Output:** Updates value indicators in a canvas referenced in ``CanvasComponent``.
/// - **Forgiveness:**
///     - Connectors with missing geometry are ignored
struct SimulationObjectsResultsSystem: System {
    // public let dependencies: SystemDependency = [ /* after: simulation */ ]
    // TODO: Find a better name
    public init() {}
    public func update(_ frame: AugmentedFrame) throws (InternalSystemError) {
        guard let result: SimulationResult = frame.component(for: .Frame),
              let plan: SimulationPlan = frame.component(for: .Frame)
        else { return }
        
        for object in plan.simulationObjects {
            guard frame.contains(object.objectID)
            else { continue }
            let series = result.unsafeTimeSeries(at: object.variableIndex)
            frame.setComponent(series, for: object.objectID)
        }
    }
}

