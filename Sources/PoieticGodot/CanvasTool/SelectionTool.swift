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
    /// Nothing hit, initial state
    case empty
    /// Direct hit of a single object, typically a block or a connector.
    case objectHit
    /// Object selection initiated.
    case objectSelect
    /// Dragging selection around.
    case objectMove
    /// Handle that can be moved was hit.
    case handleHit
    /// Dragging handle around.
    case handleMove
    /// Some other object child was hit, such as label or issue indicator.
    case childHit
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

    @Export var state: SelectToolState = .empty
    @Export var hitTarget: CanvasHitTarget?
    
    var previousCanvasPosition: Vector2 = .zero
    var initialCanvasPosition: Vector2 = .zero
    
    override func toolName() -> String { "select" }

    override func inputBegan(event: InputEvent, globalPosition: Vector2) -> Bool {
        // TODO: Move this to tool
        guard let event = event as? InputEventWithModifiers,
              let canvas,
              let selectionManager = designController?.selectionManager
        else { return false }

        canvasController?.closeInlinePopup()

        guard let target = canvas.hitTarget(globalPosition: globalPosition) else {
            selectionManager.clear()
            state = .objectSelect
            return true
        }
        
        initialCanvasPosition = canvas.toLocal(globalPoint: globalPosition)
        previousCanvasPosition = initialCanvasPosition
        
        switch target.type {
        case .object:
            // TODO: Defer opening of context menu on inputEnded
            guard let object = target.object as? DiagramCanvasObject, let objectID = object.objectID else {
                GD.pushWarning("Hit object is not a diagram canvas object")
                return false
            }
            if event.shiftPressed {
                selectionManager.toggle(objectID)
            }
            else {
                if selectionManager.contains(objectID) {
                    let ids = selectionManager.get_ids()
                    canvasController?.openContextMenu(ids, desiredGlobalPosition: globalPosition)
                }
                else {
                    selectionManager.replaceAll([objectID])
                }
            }
            state = .objectHit
        case .handle:
            hitTarget = target
            state = .handleHit
            selectionManager.clear()
        case .primaryLabel,
                .secondaryLabel,
                .errorIndicator:
            hitTarget = target
            state = .childHit
        }
        return true
    }
    
    override func inputMoved(event: InputEvent, globalPosition: Vector2) -> Bool {
        guard let event = event as? InputEventMouse else { return false }
        guard let canvas else { return false }
        canvasController?.closeInlinePopup()

        let canvasPosition = canvas.toLocal(globalPoint: globalPosition)
        let delta = canvasPosition - previousCanvasPosition
        previousCanvasPosition = canvasPosition

        // FIXME: add this
        // prompt_manager.close()
        
        switch state {
        case .empty: break
        case .objectSelect: break
        case .objectHit, .objectMove, .childHit:
            Input.setDefaultCursorShape(.drag)
            moveSelection(byCanvasDelta: delta)
            state = .objectMove

        case .handleHit, .handleMove:
            Input.setDefaultCursorShape(.drag)
            dragHandle(byCanvasDelta: delta)
            state = .handleMove
        }
        return true
    }
    func moveSelection(byCanvasDelta canvasDelta: Vector2) {
        guard let canvas else { return }
        guard let ctrl = designController else { return }
        guard let diagramCtrl = canvasController else { return }
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
    func dragHandle(byCanvasDelta canvasDelta: Vector2) {
        guard let hitTarget else { return }
        guard let canvas else { return }
        guard let diagramCtrl = canvasController else { return }

        if let object = hitTarget.object as? DiagramCanvasConnector {
            guard let tag = hitTarget.tag else { return }
            object.moveMidpoint(tag: tag, canvasDelta: canvasDelta)
            diagramCtrl.updateConnectorPreview(object)
        }
        else {
            GD.print("No proper parent")
        }

        canvas.queueRedraw()
    }

    override func inputEnded(event: InputEvent, globalPosition: Vector2) -> Bool {
        defer {
            state = .empty
            hitTarget = nil
        }
        guard let canvas else { return false }
        guard let selection = designController?.selectionManager.selection else { return false }
        Input.setDefaultCursorShape(.arrow)

        let canvasPosition = canvas.toLocal(globalPoint: globalPosition)
        let canvasMoveDelta = canvasPosition - initialCanvasPosition
        let designMoveDelta = Vector2D(canvasMoveDelta)
        
        switch state {
        case .objectMove:
            canvasController?.moveSelection(selection, by: designMoveDelta)
        case .handleMove:
            // FIXME: Last position
            guard let hitTarget,
                  let object = hitTarget.object as? DiagramCanvasConnector,
                  let objectID = object.objectID,
                  let connector = object.connector else
            {
                return false
            }

            canvasController?.setMidpoints(object: objectID,
                                            midpoints: connector.midpoints)
        case .empty: break
        case .handleHit: break
        case .objectHit: break
        case .objectSelect: break
        case .childHit:
            guard let hitTarget,
                  let block = hitTarget.object as? DiagramCanvasBlock,
                  let id = block.objectID,
                  let selectionManager = designController?.selectionManager
            else {
                break
            }
            
            switch hitTarget.type {
            case .primaryLabel:
                selectionManager.replaceAll([id])
                canvasController?.openInlineEditor("name", rawObjectID: id.rawValue, attribute: "name")
            case .secondaryLabel:
                selectionManager.replaceAll([id])
                canvasController?.openInlineEditor("formula", rawObjectID: id.rawValue, attribute: "formula")
            case .errorIndicator:
                selectionManager.replaceAll([id])
                // FIXME: Who has responsibility for filling in the popup info?
                canvasController?.openIssuesPopup(id.rawValue)
            case .object: break
            case .handle: break
            }
        }
        return true
    }
}
