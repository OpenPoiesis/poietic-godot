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


    /// Get an ID of a selected object if only one object is selected. Otherwise
    /// returns null.
    ///
    /// Use this method for actions that operate on single objects, such as name or formula
    /// editing.
    ///
    @Callable(autoSnakeCase: true)
    public func selectionOfOne() -> EntityIDValue? {
        guard selection.count == 1 else { return nil }
        return selection.first?.rawValue
    }
    
    @Callable
    func get_ids() -> PackedInt64Array {
        return PackedInt64Array(compactingValid: selection)
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
    func contains(id: EntityIDValue) -> Bool {
        let actual_id = ObjectID(rawValue: id)
        return selection.contains(actual_id) ?? false
    }
    
    func contains(_ id: PoieticCore.ObjectID) -> Bool {
        return selection.contains(id)
    }

    @Callable
    func append(id: EntityIDValue) {
        let actual_id = ObjectID(rawValue: id)
        selection.append(actual_id)
        selectionChanged.emit(self)
    }

    @Callable
    func replace(ids: PackedInt64Array) {
        var actualIDs: [PoieticCore.ObjectID] = ids.asValidEntityIDs()
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
    func remove(id: EntityIDValue) {
        let actual_id = ObjectID(rawValue: id)
        selection.remove(actual_id)
        selectionChanged.emit(self)
    }

    @Callable
    func toggle(id: EntityIDValue) {
        let actual_id = ObjectID(rawValue: id)
        selection.toggle(actual_id)
        selectionChanged.emit(self)
    }
    func toggle(_ id: PoieticCore.ObjectID) {
        selection.toggle(id)
        selectionChanged.emit(self)
    }
}
