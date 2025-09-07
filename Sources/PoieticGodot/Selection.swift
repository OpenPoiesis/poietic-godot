//
//  Selection.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 03/03/2025.
//

import SwiftGodot
import PoieticCore

struct PoieticSelectionTypeInfo {
    var distinct_types: [String]
    var shared_traits: [String]
    var count: Int
    var has_issues: Bool
    
    func is_empty() -> Bool {
        return count == 0
    }
    func matches(traits: [String], multiple: Bool, issues: Bool) -> Bool {
        return false
    }
}

@Godot
class SelectionManager: SwiftGodot.Node {
    // TODO: Consider removing this selection wrapper, just add get_ids() on Canvas
    var selection: Selection = Selection()
   
    @Signal var selectionChanged: SignalWithArguments<SelectionManager>

    @Callable
    func get_ids() -> PackedInt64Array {
        return PackedInt64Array(selection.map { $0.godotInt })
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
        selectionChanged.emit(self)
    }
    
    @Callable
    func contains(id: Int64) -> Bool {
        guard let actual_id = ObjectID(id) else {
            GD.pushError("Invalid ID: \(id)")
            return false
        }
        return selection.contains(actual_id) ?? false
    }
    
    func contains(_ id: PoieticCore.ObjectID) -> Bool {
        return selection.contains(id)
    }

    @Callable
    func append(id: Int64) {
        guard let actual_id = ObjectID(id) else {
            GD.pushError("Invalid ID: \(id)")
            return
        }
        selection.append(actual_id)
        selectionChanged.emit(self)
    }

    @Callable
    func replace(ids: PackedInt64Array) {
        var actualIDs: [PoieticCore.ObjectID] = ids.compactMap {
            PoieticCore.ObjectID($0)
        }
        guard ids.count == actualIDs.count else {
            GD.pushError("Some IDs are invalid")
            return
        }
        selection.replaceAll(actualIDs)
        selectionChanged.emit(self)
    }
    
    func replaceAll(_ ids: [PoieticCore.ObjectID]) {
        selection.replaceAll(ids)
        selectionChanged.emit(self)
    }
    
    @Callable
    func remove(id: Int64) {
        guard let actual_id = ObjectID(id) else {
            GD.pushError("Invalid ID: \(id)")
            return
        }
        selection.remove(actual_id)
        selectionChanged.emit(self)
    }

    @Callable
    func toggle(id: Int64) {
        guard let actual_id = ObjectID(id) else {
            GD.pushError("Invalid ID: \(id)")
            return
        }
        selection.toggle(actual_id)
        selectionChanged.emit(self)
    }
    func toggle(_ id: PoieticCore.ObjectID) {
        selection.toggle(id)
        selectionChanged.emit(self)
    }
}
