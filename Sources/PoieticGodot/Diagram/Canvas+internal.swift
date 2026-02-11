//
//  Canvas+private.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 11/01/2026.
//

import PoieticCore
import PoieticFlows
import Diagramming
import SwiftGodot
import Foundation

extension DiagramCanvas {
    func currentTool() -> CanvasTool? {
        guard let app = getNode(path: NodePath(AppNodePath)) as? PoieticApplication else {
            GD.pushWarning("Unable to get app")
            return nil
        }
        return app.currentTool
    }
    
    func updateBackground() {
        guard let viewport = getViewport(),
              let background = self.background else { return }
        let size = viewport.getVisibleRect().size
        background.setSize(size / Double(zoomLevel))
        background.setPosition(-canvasOffset / Double(zoomLevel))
    }
    
    // MARK: - Geometry

    // TODO: Observe how we are using it and adjust types accordingly
    // TODO: Add screen scaling (retina)
    /// Converts a point from canvas coordinates to design coordinates.
    func toDesign(canvasPoint: SwiftGodot.Vector2) -> Vector2D {
        let inDesign = canvasPoint / Double(zoomLevel)
        return Vector2D(inDesign)
    }
    /// Converts a point from design coordinates to canvas coordinates.
    func fromDesign(_ position: Vector2D) -> SwiftGodot.Vector2 {
        return position.asGodotVector2()
    }

    func promptPosition(for entityID: RuntimeID) -> Vector2 {
        guard let block = _blocks[entityID] else { return .zero }

        let position: Vector2
        if let primaryLabel = block.primaryLabel {
            return primaryLabel.getGlobalPosition()
        }
        else {
            return self.toGlobal(localPoint: block.position)
        }
    }

    // MARK: - Content
    func clear() {
        for child in getChildren() {
            guard let child = child as? DiagramCanvasObject else { continue }
            child.queueFree()
        }
        _blocks.removeAll()
        _connectors.removeAll()
    }

    /// Add a block that represents a design node. The block must have `ObjectID` set to a non-nil
    /// value. Existing block with the same ID will be replaced.
    ///
    func insertBlock(_ block: DiagramCanvasBlock) {
        guard let id = block.runtimeID else { return }
        
        if let existing = _blocks[id] {
            removeChild(node: existing)
        }
        addChild(node: block)
        _blocks[id] = block
    }

    func removeBlock(_ id: RuntimeID) {
        guard let node = _blocks.removeValue(forKey: id) else {
            return
        }
        node.queueFree()
    }
    
    func insertConnector(_ connector: DiagramCanvasConnector) {
        guard let id = connector.runtimeID else { return }
        
        if let existing = _connectors[id] {
            removeChild(node: existing)
        }
        addChild(node: connector)
        _connectors[id] = connector
    }
    
    func removeConnector(_ id: RuntimeID) {
        guard let object = _connectors.removeValue(forKey: id) else {
            return
        }
        object.queueFree()
    }

    // - MARK: Handles
    func addHandle(_ handle: CanvasHandle) {
        self.addChild(node: handle)
        handles.append(handle)
    }
    func removeHandles() {
        for handle in handles {
            handle.queueFree()
        }
        handles.removeAll()
    }
}
