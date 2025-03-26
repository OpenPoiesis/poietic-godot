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
class PoieticResult: SwiftGodot.Object {
    var plan: SimulationPlan? = nil
    var result: SimulationResult? = nil
    var objectSeries: [PoieticCore.ObjectID:PoieticTimeSeries]? = nil
    
    // TODO: Store time-series directly, instead of SimulationResult
    // var series: [Int:RegularTimeSeries]
    
    func set(plan: SimulationPlan, result: SimulationResult) {
        self.plan = plan
        self.result = result
        
        self.objectSeries = [:]
        for obj in plan.simulationObjects {
            let series = PoieticTimeSeries()
            series.series = result.unsafeTimeSeries(at: obj.variableIndex)
            self.objectSeries![obj.id] = series
        }
    }

    @Export var initial_time: Double? {
        get { result?.initialTime }
        set(value) { GD.pushError("Trying to set read-only variable") }
    }

    @Export var end_time: Double? {
        get { result?.endTime }
        set(value) { GD.pushError("Trying to set read-only variable") }
    }

    @Export var time_delta: Double? {
        get { result?.timeDelta }
        set(value) { GD.pushError("Trying to set read-only variable") }
    }

    @Export var count: Int {
        get { result?.count ?? 0 }
        set(value) { GD.pushError("Trying to set read-only variable") }
    }

    @Callable
    public func time_series(id: Int) -> PoieticTimeSeries? {
        guard let poieticID = PoieticCore.ObjectID(String(id)) else {
            GD.pushError("Invalid ID")
            return nil
        }
        guard let objectSeries else {
            GD.printErr("Empty result")
            return nil
        }
        return objectSeries[poieticID]
    }
}

@Godot
class PoieticTimeSeries: SwiftGodot.Object {
    var series: RegularTimeSeries? = nil
    
    @Export var is_empty: Bool {
        get { series?.isEmpty ?? true }
        set(value) { GD.pushError("Trying to set read-only variable") }
    }

    @Export var time_delta: Double {
        get { series?.timeDelta ?? 0}
        set(value) { GD.pushError("Trying to set read-only variable") }
    }
    @Export var time_start: Double {
        get { series?.startTime ?? 0}
        set(value) { GD.pushError("Trying to set read-only variable") }
    }
    @Export var time_end: Double {
        get { series?.endTime ?? 0}
        set(value) { GD.pushError("Trying to set read-only variable") }
    }
    @Export var data_min: Double {
        get { series?.dataMin ?? 0}
        set(value) { GD.pushError("Trying to set read-only variable") }
    }
    @Export var data_max: Double {
        get { series?.dataMax ?? 0}
        set(value) { GD.pushError("Trying to set read-only variable") }
    }

    @Export var first: Double? {
        get { series?.data.first ?? 0}
        set(value) { GD.pushError("Trying to set read-only variable") }
    }

    @Callable
    func get_points() -> PackedVector2Array {
        guard let series else {
            return PackedVector2Array()
        }
        var vectors: [Vector2] = series.points().map { $0.asGodotVector2() }

        return PackedVector2Array(vectors)
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
class PoieticPlayer: SwiftGodot.Node {
    #signal("simulation_player_started")
    #signal("simulation_player_stopped")
    #signal("simulation_player_step")
    #signal("simulation_player_restarted")
    
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
        emit(signal: PoieticPlayer.simulationPlayerRestarted)
    }
    
    @Callable
    public func run() {
        self.is_running = true
        emit(signal: PoieticPlayer.simulationPlayerStarted)
    }

    @Callable
    public func stop() {
        self.is_running = false
        emit(signal: PoieticPlayer.simulationPlayerStopped)
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
        emit(signal: PoieticPlayer.simulationPlayerStep)
        current_step += 1
    }

    /// Get a numeric value of computed object with given ID.
    @Callable
    public func numeric_value(id: Int) -> Double? {
        guard let poieticID = PoieticCore.ObjectID(String(id)) else {
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
