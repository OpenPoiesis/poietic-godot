//
//  SelectionTool.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 28/08/2025.
//

import SwiftGodot
import Diagramming
import PoieticCore

enum SelectToolState: Int, CaseIterable {
    case empty
    case objectHit
    case objectSelect
    case objectMove
    case handleHit
    case handleMove
}

@Godot
class SelectionTool: CanvasTool {
    // TODO: Target Priority
    // 1. Selection -> Handles
    // 2. Objects
    // 3. Prompts
    // Canvas should sort by (is selected?, z-index, target type)
    // Where:
    // selected > not selected
    // handle > object > prompt

//    @Export var lastPointerPosition = Vector2()
    @Export var state: SelectToolState = .empty
    @Export var draggingHandle: CanvasHandle?
    
    var previousCanvasPosition: Vector2 = .zero
    var initialCanvasPosition: Vector2 = .zero

    override func toolName() -> String {
        "select"
    }

    override func toolReleased() {
        // TODO: Close prompt
    }
    override func inputBegan(event: InputEvent, globalPosition: Vector2) -> Bool {
        // TODO: Move this to tool
        guard let event = event as? InputEventWithModifiers else { return false }
        guard let canvas else { return false }
        guard let selectionManager = designController?.selectionManager else { return false }
        guard let target = canvas.hitTarget(globalPosition: globalPosition) else {
            selectionManager.clear()
            state = .objectSelect
            return true
        }
        initialCanvasPosition = canvas.toLocal(globalPoint: globalPosition)
        previousCanvasPosition = initialCanvasPosition
        
        switch target.type {
        case .object:
            guard let object = target.object as? DiagramCanvasObject, let objectID = object.objectID else {
                GD.pushWarning("Hit object is not a diagram canvas object")
                return false
            }
            if event.shiftPressed {
                selectionManager.toggle(objectID)
            }
            else {
                if !selectionManager.contains(objectID) {
                    selectionManager.replaceAll([objectID])
                }
                else {
//                    let position = canvas.toLocal(globalPoint: canvasPosition)
                    GD.pushWarning("Context menu not implemented yet")
                    // TODO: Make this some clever canvas.get_context_menu_position(click_position)
                    // FIXME: prompt_manager.open_context_menu(canvas.selection, canvas.to_global(position))
                }
            }
//            lastPointerPosition = pointerPosition
            state = .objectHit
        case .handle:
            guard let handle = target.object as? CanvasHandle else {
                return false
            }
            state = .handleHit
            draggingHandle = handle
        case .primaryLabel:
            // TODO: Move this to Canvas
            guard let block = target.object as? DiagramCanvasBlock,
                  let id = block.objectID else
            {
                return false
            }
            selectionManager.replaceAll([id])
            GD.pushError("Name editor not reimplemented")
            // FIXME: prompt_manager.open_name_editor_for(node.object_id)
        case .secondaryLabel:
            guard let block = target.object as? DiagramCanvasBlock,
                  let id = block.objectID else
            {
                return false
            }
            selectionManager.replaceAll([id])
            GD.pushError("formula editor not implemented")
            // FIXME: prompt_manager.open_formula_editor_for(node.object_id)
        case .errorIndicator:
            guard let block = target.object as? DiagramCanvasBlock,
                  let id = block.objectID else
            {
                return false
            }
            selectionManager.replaceAll([id])
            GD.pushError("Issue inspector not implemented")
            // FIXME: prompt_manager.open_issues_for(node.object_id)
        }
        GD.print("--- selection began: \(state)")
        return true
    }
    
    override func inputMoved(event: InputEvent, globalPosition: Vector2) -> Bool {
        guard let event = event as? InputEventMouse else { return false }
        guard let canvas else { return false }
        // FIXME: add this
        // prompt_manager.close()
        
        switch state {
        case .empty: break
        case .objectSelect: break
        case .objectHit:
            Input.setDefaultCursorShape(.drag)
            state = .objectMove
        case .objectMove:
            let canvasPosition = canvas.toLocal(globalPoint: globalPosition)
            let delta = canvasPosition - previousCanvasPosition
            previousCanvasPosition = canvasPosition
            Input.setDefaultCursorShape(.drag)
            moveSelection(byCanvasDelta: delta)
        case .handleHit:
            Input.setDefaultCursorShape(.drag)
//            self.canvas.begin_drag_handle(dragging_handle, mouse_position)
            state = .handleMove
            GD.pushError("Handle hit not implemented")
        case .handleMove:
            Input.setDefaultCursorShape(.drag)
//            self.canvas.drag_handle(dragging_handle, move_delta)
            GD.pushError("Handle move not implemented")
        }
        return true
    }
    func moveSelection(byCanvasDelta canvasDelta: Vector2) {
        guard let canvas else { return }
        guard let ctrl = designController else { return }
        guard let diagramCtrl = diagramController else { return }
        let selection = ctrl.selectionManager.selection
        var dependentEdges: Set<PoieticCore.ObjectID> = Set()
        var designDelta = Vector2D(canvasDelta)
        
        let blocks: [DiagramCanvasBlock] = selection.compactMap {
            canvas.representedBlock(id: $0)
        }
        let connectors: [DiagramCanvasConnector] = selection.compactMap {
            canvas.representedConnector(id: $0)
        }
        for block in blocks {
            block.block?.position += designDelta
            block.setDirty()
            if let objectID = block.objectID {
                let deps = ctrl.currentFrame.dependentEdges(objectID)
                dependentEdges.formUnion(deps)
            }
        }

        for connector in connectors {
            guard let diagramConnector = connector.connector else { continue }
            guard !diagramConnector.midpoints.isEmpty else { continue }
            let movedMidpoints = diagramConnector.midpoints.map {
                $0 + designDelta
            }
            connector.connector?.midpoints = movedMidpoints
            diagramCtrl.updateConnectorPreview(connector)
            connector.setDirty()
        }
        // TODO: Gather the mid-point changed connectors as well, not to have duplicate update
        for id in dependentEdges {
            guard let connector = canvas.representedConnector(id: id) else { continue }
            diagramCtrl.updateConnectorPreview(connector)
            connector.setDirty()
        }
        
        
        canvas.queueRedraw()
    }
    override func inputEnded(event: InputEvent, globalPosition: Vector2) -> Bool {
        guard let canvas else { return false }
        guard let selection = designController?.selectionManager.selection else { return false }
        Input.setDefaultCursorShape(.arrow)

        let canvasPosition = canvas.toLocal(globalPoint: globalPosition)
        let canvasMoveDelta = canvasPosition - initialCanvasPosition
        let designMoveDelta = Vector2D(canvasMoveDelta)
        
        switch state {
        case .objectMove:
            diagramController?.moveSelection(selection, by: designMoveDelta)
        case .handleMove:
            GD.pushError("Handle move commit not implemented")
        case .empty: break
        case .handleHit: break
        case .objectHit: break
        case .objectSelect: break
        }
        return true
    }
}
