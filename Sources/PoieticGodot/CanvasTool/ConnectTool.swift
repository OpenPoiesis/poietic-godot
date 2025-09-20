//
//  ConnectTool.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 03/09/2025.
//
import SwiftGodot
import PoieticCore
import Diagramming


enum ConnectToolState: Int, CaseIterable {
    case empty
    case connect
}

@Godot
class ConnectTool: CanvasTool {
    @Export var state: ConnectToolState = .empty
    // FIXME: Use real type, not just name
    
    @Export var lastPointerPosition = Vector2()
    @Export var origin: DiagramCanvasBlock?
    @Export var draggingConnector: DiagramCanvasConnector?
    
    override func toolName() -> String { "connect" }
    override func paletteName() -> String? { ConnectToolPaletteName }

    override func toolSelected() {
        if paletteItemIdentifier == nil {
            paletteItemIdentifier = DefaultConnectorEdgeType
        }
        // object_panel.load_connector_pictograms()
        // object_panel.selection_changed.connect(_on_object_selection_changed)
        //        if last_selected_object_identifier {
        //            object_panel.selected_item = last_selected_object_identifier
        //        }
        //        else {
        //            object_panel.selected_item = "Flow"
        //        }
    }
    override func toolReleased() {
        // last_selected_object_identifier = object_panel.selected_item
        // object_panel.selection_changed.disconnect(_on_object_selection_changed)
    }
    override func paletteItemChanged(_ identifier: String?) {
        GD.print("--- Connect tool palette item changed: ", identifier ?? "(nil)")

        guard let identifier else {
            return
        }
        if !ConnectorEdgeTypes.contains(identifier) {
            GD.pushError("Invalid connector (edge) type:", identifier)
            return
        }
    }

    override func inputBegan(event: InputEvent, globalPosition: Vector2) -> Bool {
        guard let ctrl = canvasController else { return false }
        guard let canvas else { return false }
        guard let origin = canvas.hitObject(globalPosition: globalPosition) as? DiagramCanvasBlock
        else { return true }

        let typeName = paletteItemIdentifier ?? DefaultConnectorEdgeType
        // TODO: Validate type name
        
        let canvasPosition = canvas.toLocal(globalPoint: globalPosition)
        let targetPoint = Vector2D(canvasPosition)
        draggingConnector = ctrl.createDragConnector(type: typeName,
                                                     origin: origin,
                                                     targetPoint: targetPoint)
        self.origin = origin
        state = .connect
        Input.setDefaultCursorShape(.drag)
        return true
    }
    
    override func inputMoved(event: InputEvent, globalPosition: Vector2) -> Bool {
        guard let ctrl = canvasController else { return false }
        guard let canvas else { return false }
        guard state == .connect else { return true }
        guard let origin = self.origin,
              let originID = origin.objectID else { GD.pushError("Invalid connect drag origin"); return false }
        guard let draggingConnector,
              let connector = draggingConnector.connector else { GD.pushError("No dragging connector") ; return false }

        let canvasPosition = canvas.toLocal(globalPoint: globalPosition)
        let targetPoint = Vector2D(canvasPosition)
        ctrl.updateDragConnector(draggingConnector,
                                 origin: origin,
                                 targetPoint: targetPoint)

        let canvasPoint = canvas.fromDesign(targetPoint)
        guard let target = canvas.hitObject(globalPosition: globalPosition),
              let targetID = target.objectID else
        {
            Input.setDefaultCursorShape(.drag)
            return true
        }
        guard targetID != originID else {
            Input.setDefaultCursorShape(.forbidden)
            return true
        }
        let typeName = paletteItemIdentifier ?? DefaultConnectorEdgeType
        if self.canConnect(typeName: typeName, from: originID, to: targetID) {
            Input.setDefaultCursorShape(.canDrop)
        }
        else {
            Input.setDefaultCursorShape(.forbidden)
        }

        return true
    }
    func canConnect(typeName: String, from originID: PoieticCore.ObjectID, to targetID: PoieticCore.ObjectID) -> Bool {
        guard let ctrl = designController else { return false }
        guard let type = ctrl.design.metamodel.objectType(name: typeName) else {
            GD.pushError("Invalid connector type: \(typeName)")
            return false
        }
        let flag = ctrl.checker.canConnect(type: type,
                                       from: originID,
                                       to: targetID,
                                       in: ctrl.currentFrame)
        if let origin = ctrl.getObject(originID),
           let target = ctrl.getObject(targetID)
        {
            GD.print("--? can connect: \(typeName) from: \(origin.object!.type.name) to: \(target.object!.type.name) -> \(flag)")
        }
        else {
            GD.print("--? can connect: \(typeName) from: \(originID) to: \(targetID) -> \(flag)")
        }
        return flag
    }
    
    override func inputEnded(event: InputEvent, globalPosition: Vector2) -> Bool {
        defer {
            Input.setDefaultCursorShape(.arrow)
            cancelConnectSession()
        }

        guard state == .connect else { return false }
        guard let originID = self.origin?.objectID else { GD.pushError("No origin ID for dragging connector"); return false }
        guard let draggingConnector else { GD.pushError("No dragging connector") ; return false }
        guard let target = canvas?.hitObject(globalPosition: globalPosition) as? DiagramCanvasBlock,
              let targetID = target.objectID else
        {
            // TODO: Do some puff animation here
            return true
        }
        let typeName = paletteItemIdentifier ?? DefaultConnectorEdgeType
        if self.canConnect(typeName: typeName, from: originID, to: targetID) {
            createEdge(typeName: typeName, from: originID, to: targetID)
        }
        else {
            // TODO: Puff!
        }
        return true
    }
    
    func cancelConnectSession() {
        self.origin = nil
        if let draggingConnector {
            draggingConnector.queueFree()
            self.draggingConnector = nil
        }
        state = .empty
    }
    
    func createEdge(typeName: String, from originID: PoieticCore.ObjectID, to targetID: PoieticCore.ObjectID) {
        // TODO: Make this a command
        guard let ctrl = designController else { return }
        guard let type = ctrl.design.metamodel.objectType(name: typeName) else {
            GD.pushError("Invalid connector type: \(typeName)")
            return
        }
        var trans = ctrl.newTransaction()
        guard trans.contains(originID) else {
            GD.pushError("Unknown origin ID \(originID)")
            ctrl.discard(trans)
            return
        }
        guard trans.contains(targetID) else {
            GD.pushError("Unknown target ID \(targetID)")
            ctrl.discard(trans)
            return
        }
        let edge = trans.createEdge(type, origin: originID, target: targetID)
        ctrl.accept(trans)
    }
}
