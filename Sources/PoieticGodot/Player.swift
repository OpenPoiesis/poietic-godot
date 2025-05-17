//
//  Simulator.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 23/02/2025.
//

import SwiftGodot
import PoieticCore
import PoieticFlows


@Godot
class PoieticPlayer: SwiftGodot.Node {
    @Signal var simulationPlayerStarted: SimpleSignal
    @Signal var simulationPlayerStopped: SimpleSignal
    @Signal var simulationPlayerStep: SimpleSignal
    @Signal var simulationPlayerRestarted: SimpleSignal
    
    @Export var result: PoieticResult?
    @Export var is_running: Bool = false
    @Export var is_looping: Bool = true
    @Export var time_to_step: Double = 0
    @Export var step_duration: Double = 0.1
    @Export var current_step: Int = 0
    @Export var current_time: Double? {
        get {
            guard let result = result?.result else { return nil }
            return result.initialTime + Double(current_step) * result.timeDelta
        }
        set(value) {
            GD.pushError("Trying to set read-only attribute")
        }
    }

    @Callable
    func restart() {
        current_step = 0
        simulationPlayerRestarted.emit()
    }
    
    @Callable
    public func run() {
        self.is_running = true
        simulationPlayerStarted.emit()
    }

    @Callable
    public func stop() {
        self.is_running = false
        simulationPlayerStopped.emit()
    }

    @Callable
    override public func _process(delta: Double) {
        if is_running {
            if time_to_step <= 0 {
                step()
                time_to_step = step_duration
            }
            else {
                time_to_step -= delta
            }
        }
    }
    
    func step() {
        guard let result = result?.result  else {
            return
        }
        if current_step >= result.count {
            if is_looping {
                current_step = 0
            }
            else {
                stop()
                return
            }
        }
        simulationPlayerStep.emit()
        current_step += 1
    }

    /// Get a numeric value of computed object with given ID.
    @Callable
    public func numeric_value(id: Int64) -> Double? {
        guard let poieticID = PoieticCore.ObjectID(id) else {
            GD.pushError("Invalid ID")
            return nil
        }
        guard let wrappedResult = result?.result, let plan = result?.plan else {
            GD.printErr("Playing without result or plan")
            return nil
        }
        guard let index = plan.variableIndex(of: poieticID) else {
            GD.printErr("Can not get numeric value of unknown object ID \(poieticID)")
            return nil
        }
        guard let state = wrappedResult[current_step] else {
            GD.printErr("No current player state for step: \(current_step)")
            return nil
        }
        
        return try? state[index].doubleValue()
    }
}
