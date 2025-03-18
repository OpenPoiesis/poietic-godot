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
class PoieticTimeSeries: SwiftGodot.Object {
    var series: RegularTimeSeries? = nil
    
    @Export var is_empty: Bool {
        get { series?.isEmpty ?? true }
        set(value) { GD.pushError("Trying to set read-only variable is_empty") }
    }

    @Export var start_time: Double {
        get { series?.startTime ?? 0}
        set(value) { GD.pushError("Trying to set read-only variable start_time") }
    }
    @Export var end_time: Double {
        get { series?.endTime ?? 0}
        set(value) { GD.pushError("Trying to set read-only variable end_time") }
    }
    @Export var data_min: Double {
        get { series?.dataMin ?? 0}
        set(value) { GD.pushError("Trying to set read-only variable data_min") }
    }
    @Export var data_max: Double {
        get { series?.dataMin ?? 0}
        set(value) { GD.pushError("Trying to set read-only variable data_max") }
    }
    
    @Callable
    func get_values() -> PackedFloat64Array {
        if let series {
            return PackedFloat64Array(series.data)
        }
        else {
            return PackedFloat64Array()
        }
    }
}

// TODO: Replace this with just plain timer?
@Godot
class PoieticReplayer: SwiftGodot.Node {
    var plan: SimulationPlan? = nil
    var result: SimulationResult? = nil
    
    #signal("simulation_player_started")
    #signal("simulation_player_stopped")
    #signal("simulation_player_step")
    #signal("simulation_player_restarted")
    
    @Export var is_running: Bool = false
    @Export var is_looping: Bool = true
    @Export var time_to_step: Double = 0
    @Export var step_duration: Double = 0.1
    
    @Export var current_step: Int = 0

    var currentState: SimulationState? {
        guard let result else { return nil }
        return result[current_step]
    }
    
    @Callable
    func restart() {
        current_step = 0
        emit(signal: PoieticReplayer.simulationPlayerRestarted)
    }
    
    @Callable
    public func run() {
        self.is_running = true
        emit(signal: PoieticReplayer.simulationPlayerStarted)
    }

    @Callable
    public func stop() {
        self.is_running = false
        emit(signal: PoieticReplayer.simulationPlayerStopped)
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
        guard let result else {
            GD.printErr("Playing without result")
            return
        }
        GD.print("Playing step ", current_step)
        
        if current_step >= result.count {
            if is_looping {
                current_step = 0
            }
            else {
                stop()
                return
            }
        }
        
        current_step += 1
        
        emit(signal: PoieticReplayer.simulationPlayerStep)
    }

    @Callable
    public func numeric_value(id: Int) -> Double? {
        guard let poieticID = PoieticCore.ObjectID(String(id)) else {
            GD.pushError("Invalid ID")
            return nil
        }
        guard let result, let plan else {
            GD.printErr("Playing without result or plan")
            return nil
        }
        guard let index = plan.variableIndex(of: poieticID) else {
            GD.printErr("Can not get numeric value of unknown object ID \(poieticID)")
            return nil
        }
        guard let state = result[current_step] else {
            GD.printErr("No current player state")
            return nil
        }
        
        return try? state[index].doubleValue()
    }
}
