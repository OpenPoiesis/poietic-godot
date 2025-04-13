//
//  Result.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 09/04/2025.
//
import SwiftGodot
import PoieticFlows
import PoieticCore

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
            series._object_id = obj.id
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
    public func time_series(id: Int64) -> PoieticTimeSeries? {
        guard let poieticID = PoieticCore.ObjectID(id) else {
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
    var _object_id: PoieticCore.ObjectID? = nil
    var series: RegularTimeSeries? = nil
    
    @Export var object_id: Int64? {
        get {
            if let _object_id { _object_id.godotInt }
            else { nil }
        }
        set(value) { GD.pushError("Trying to set read-only variable") }
    }

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
