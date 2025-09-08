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
        previousCanvasPosition = canvas.toLocal(globalPoint: globalPosition)
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
            GD.print("--> Begin drag selection")
        case .objectMove:
            let canvasPosition = canvas.toLocal(globalPoint: globalPosition)
            let delta = canvasPosition - previousCanvasPosition
            previousCanvasPosition = canvasPosition
            GD.print("--- Moving drag selection by \(delta)")
            Input.setDefaultCursorShape(.drag)
            moveSelection(byCanvasDelta: delta)
        case .handleHit:
            Input.setDefaultCursorShape(.drag)
//            self.canvas.begin_drag_handle(dragging_handle, mouse_position)
            state = .handleMove
            GD.print("--> Begin drag handle")
        case .handleMove:
            Input.setDefaultCursorShape(.drag)
//            self.canvas.drag_handle(dragging_handle, move_delta)
            GD.print("--- Moving drag handle")
        }
        return true
    }
    override func inputEnded(event: InputEvent, globalPosition: Vector2) -> Bool {
        // FIXME: Implement commit
        GD.printErr("Input ended for selection tool not yet implemented")
        return true
    }
    func moveSelection(byCanvasDelta canvasDelta: Vector2) {
        guard let canvas else { return }
        guard let ctrl = designController else { return }
        guard let diagramCtrl = diagramController else { return }
        let selection = ctrl.selectionManager.selection
        var dependentEdges: Set<PoieticCore.ObjectID> = Set()
        var designDelta = Vector2D(canvasDelta)
        
        GD.print("--- Move selection by: \(canvasDelta)")
        
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
            // FIXME: This is convoluted, simplify and make it more clear
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
    //
//    func input_ended(_event: InputEvent, mouse_position: Vector2) -> bool:
//        match state:
//            SelectToolState.OBJECT_SELECT:
//                pass
//            SelectToolState.OBJECT_HIT:
//                pass
//            SelectToolState.OBJECT_MOVE:
//                Input.set_default_cursor_shape(Input.CURSOR_ARROW)
//                self.canvas.finish_drag_selection(mouse_position)
//            SelectToolState.HANDLE_MOVE:
//                Input.set_default_cursor_shape(Input.CURSOR_ARROW)
//                self.canvas.finish_drag_handle(dragging_handle, mouse_position)
//                dragging_handle = null
//
//        state = SelectToolState.EMPTY
//        return true

}
