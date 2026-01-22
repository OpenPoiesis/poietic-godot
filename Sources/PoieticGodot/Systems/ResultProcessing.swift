//
//  ResultProcessing.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 25/11/2025.
//

import PoieticCore
import PoieticFlows

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
    public init(_ world: World) {}
    public func update(_ world: World) throws (InternalSystemError) {
        guard let result: SimulationResult = world.singleton(),
              let plan: SimulationPlan = world.singleton(),
              let frame = world.frame
        else { return }
        
        for object in plan.simulationObjects {
            guard frame.contains(object.objectID)
            else { continue }
            let series: RegularTimeSeries = result.unsafeTimeSeries(at: object.variableIndex)
            world.setComponent(series, for: object.objectID)
        }
    }
}

