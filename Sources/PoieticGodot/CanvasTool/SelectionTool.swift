//
//  SelectionTool.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 28/08/2025.
//

import SwiftGodot

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

    @Export var lastPointerPosition = Vector2()
    @Export var state: SelectToolState = .empty
    @Export var draggingHandle: CanvasHandle?

    override func toolName() -> String {
        "select"
    }

    override func toolReleased() {
        // TODO: Close prompt
    }
    override func inputBegan(event: InputEvent, pointerPosition: Vector2) -> Bool {
        // TODO: Move this to tool
        guard let event = event as? InputEventWithModifiers else { return false }
        guard let canvas else { return false }
        guard let target = canvas.hitTarget(at: pointerPosition) else {
            canvas.selection.clear()
            state = .objectSelect
            return true
        }
        
        switch target.type {
        case .object:
            guard let object = target.object as? DiagramCanvasObject, let objectID = object.objectID else {
                GD.pushWarning("Hit object is not a diagram canvas object")
                return true
            }
            if event.shiftPressed {
                canvas.selection.toggle(objectID)
            }
            else {
                if canvas.selection.is_empty() || !canvas.selection.contains(objectID) {
                    canvas.selection.replace([objectID])
                }
                else {
                    let position = canvas.toLocal(globalPoint: pointerPosition)
                    // TODO: Make this some clever canvas.get_context_menu_position(click_position)
                    // FIXME: prompt_manager.open_context_menu(canvas.selection, canvas.to_global(position))
                }
            }
            lastPointerPosition = pointerPosition
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
            canvas.selection.replace([id])
            GD.pushError("Name editor not reimplemented")
            // FIXME: prompt_manager.open_name_editor_for(node.object_id)
        case .secondaryLabel:
            guard let block = target.object as? DiagramCanvasBlock,
                  let id = block.objectID else
            {
                return false
            }
            canvas.selection.replace([id])
            GD.pushError("formula editor not implemented")
            // FIXME: prompt_manager.open_formula_editor_for(node.object_id)
        case .errorIndicator:
            guard let block = target.object as? DiagramCanvasBlock,
                  let id = block.objectID else
            {
                return false
            }
            canvas.selection.replace([id])
            GD.pushError("Issue inspector not implemented")
            // FIXME: prompt_manager.open_issues_for(node.object_id)
        }
        return true
    }
    
//    func input_moved(event: InputEvent, move_delta: Vector2) -> bool:
//        var mouse_position = event.global_position
//        last_pointer_position += move_delta
//        # FIXME
//        #prompt_manager.close()
//
//        match state:
//            SelectToolState.OBJECT_SELECT:
//                pass
//            SelectToolState.OBJECT_HIT:
//                Input.set_default_cursor_shape(Input.CURSOR_DRAG)
//                self.canvas.begin_drag_selection(mouse_position)
//                state = SelectToolState.OBJECT_MOVE
//            SelectToolState.OBJECT_MOVE:
//                Input.set_default_cursor_shape(Input.CURSOR_DRAG)
//                self.canvas.drag_selection(move_delta)
//            SelectToolState.HANDLE_HIT:
//                Input.set_default_cursor_shape(Input.CURSOR_DRAG)
//                self.canvas.begin_drag_handle(dragging_handle, mouse_position)
//                state = SelectToolState.HANDLE_MOVE
//            SelectToolState.HANDLE_MOVE:
//                Input.set_default_cursor_shape(Input.CURSOR_DRAG)
//                self.canvas.drag_handle(dragging_handle, move_delta)
//        return true
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
