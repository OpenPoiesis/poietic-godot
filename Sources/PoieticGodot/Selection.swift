//
//  Selection.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 03/03/2025.
//

import SwiftGodot
import PoieticCore

/// Controller object that is maintaining a selection state.
///
@Godot
class SelectionManager: SwiftGodot.Node {
    var designController: DesignController?
    var world: World? { designController?.world }
    var canvas: DiagramCanvas? { designController?.canvas }

    var selection: Selection = Selection()

    private func update() {
        guard let canvas,
              let designController
        else { return }

        let selected = Set(selection.ids)
        let contained = Set(designController.currentFrame.contained(selected))
        
        for child in canvas.getChildren() {
            guard var child = child as? DiagramCanvasObject,
                  let entityID = child.entityID,
                  let objectID = world?.entityToObject(entityID)
            else { continue }

            child.isSelected = contained.contains(objectID)
        }
        let ids = PackedInt64Array(selection.ids)
        designController.selectionChanged.emit(ids)
    }
    
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
    
    public func selectionOfOne() -> PoieticCore.ObjectID? {
        guard selection.count == 1 else { return nil }
        return selection.first
    }

    @Callable
    func get_ids() -> PackedInt64Array {
        return PackedInt64Array(selection)
    }
    
    @Callable
    func is_empty() -> Bool {
        return selection.isEmpty
    }
    
    @Callable
    func count() -> Int {
        return selection.count
    }
    
    @Callable
    func clear() {
        selection.removeAll()
        update()
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
        update()
    }

    @Callable(autoSnakeCase: true)
    func selectAll() {
        guard let canvas = self.canvas,
              let world
        else { return }
        
        let blockIDs: [PoieticCore.ObjectID] = canvas.blocks.compactMap {
            guard let entityID = $0.entityID else { return nil }
            return world.entityToObject(entityID)
        }
        let connectorIDs: [PoieticCore.ObjectID] = canvas.connectors.compactMap {
            guard let entityID = $0.entityID else { return nil }
            return world.entityToObject(entityID)
        }
        let selectable = blockIDs + connectorIDs
        self.replaceAll(selectable)
    }
    
    @Callable
    func replace(ids: PackedInt64Array) {
        var actualIDs: [PoieticCore.ObjectID] = ids.asDesignEntityIDs()
        guard ids.count == actualIDs.count else {
            GD.pushError("Some IDs are invalid")
            return
        }
        selection.replaceAll(actualIDs)
        update()
    }
    
    func replaceAll(_ ids: [PoieticCore.ObjectID]) {
        selection.replaceAll(ids)
        update()
    }
    
    @Callable
    func remove(id: EntityIDValue) {
        let actual_id = ObjectID(rawValue: id)
        selection.remove(actual_id)
        update()
    }

    @Callable
    func toggle(id: EntityIDValue) {
        let actual_id = ObjectID(rawValue: id)
        selection.toggle(actual_id)
        update()
    }
    
    func toggle(_ id: PoieticCore.ObjectID) {
        selection.toggle(id)
        update()
    }
}
