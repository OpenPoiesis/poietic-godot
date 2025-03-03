//
//  Selection.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 03/03/2025.
//

import SwiftGodot
import PoieticCore

@Godot
class PoieticSelection: SwiftGodot.Node {
    var selection: Selection = Selection()
    
    #signal("selection_changed", arguments: ["selection": PoieticSelection.self])

    @Callable
    func get_ids() -> PackedInt64Array {
        return PackedInt64Array(selection.map { $0.gdInt64 })
    }
    
    @Callable
    func is_empty() -> Bool {
        return selection.isEmpty ?? true
    }
    
    @Callable
    func count() -> Int {
        return selection.count ?? 0
    }
    
    @Callable
    func clear() {
        selection.removeAll()
        emit(signal: PoieticSelection.selectionChanged, self)
    }
    
    @Callable
    func contains(id: Int) -> Bool {
        guard let actual_id = ObjectID(Int64(id)) else {
            GD.pushError("Invalid ID: \(id)")
            return false
        }
        return selection.contains(actual_id) ?? false
    }
    
    @Callable
    func append(id: Int) {
        guard let actual_id = ObjectID(Int64(id)) else {
            GD.pushError("Invalid ID: \(id)")
            return
        }
        selection.append(actual_id)
        emit(signal: PoieticSelection.selectionChanged, self)
    }

    @Callable
    func replace(ids: PackedInt64Array) {
        var actualIDs: [PoieticCore.ObjectID] = ids.compactMap {
            PoieticCore.ObjectID(Int64($0))
        }
        guard ids.count == actualIDs.count else {
            GD.pushError("Some IDs are invalid")
            return
        }
        selection.replaceAll(actualIDs)
        emit(signal: PoieticSelection.selectionChanged, self)
    }
    
    @Callable
    func remove(id: Int) {
        guard let actual_id = ObjectID(Int64(id)) else {
            GD.pushError("Invalid ID: \(id)")
            return
        }
        selection.remove(actual_id)
        emit(signal: PoieticSelection.selectionChanged, self)
    }

    @Callable
    func toggle(id: Int) {
        guard let actual_id = ObjectID(Int64(id)) else {
            GD.pushError("Invalid ID: \(id)")
            return
        }
        selection.toggle(actual_id)
        emit(signal: PoieticSelection.selectionChanged, self)
    }
}
