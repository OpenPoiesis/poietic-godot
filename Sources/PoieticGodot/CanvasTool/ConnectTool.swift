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
    var selectedItemIdentifier: String?
    
    @Export var state: ConnectToolState = .empty
    @Export var typeName: String = "Parameter"
    // FIXME: Use real type, not just name
    
    @Export var lastPointerPosition = Vector2()
    @Export var originBlock: DiagramCanvasBlock?
    @Export var draggingConnector: DiagramCanvasConnector?
    
    override func toolName() -> String {
        return "connect"
    }
    
    override func toolSelected() {
        objectPalette?.show()
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
    func _on_object_selection_changed(identifier: String) {
        typeName = identifier
    }
    
    override func inputBegan(event: InputEvent, pointerPosition: Vector2) -> Bool {
        guard let target = canvas?.hitTarget(at: pointerPosition) else {
            return true
        }
        guard target.type == .object else {
            return true
        }
        
        guard let block = target.object as? DiagramCanvasBlock else {
            state = .empty
            return true
        }
        
        createDragConnector(origin: block, pointerPosition: pointerPosition)
        originBlock = block
        state = .connect
        Input.setDefaultCursorShape(.drag)
        return true
    }
    
    func createDragConnector(origin: DiagramCanvasBlock, pointerPosition: Vector2) {
        guard let canvas else { preconditionFailure("No canvas") }
        guard draggingConnector == nil else { fatalError("Dragging connector already set") }
        
        let node = DiagramCanvasConnector()
        guard let typeName = selectedItemIdentifier else {
            preconditionFailure("No selected item identifier")
        }
        // FIXME: Use centralised style
        let targetPoint = Vector2D(canvas.toLocal(globalPoint: pointerPosition))
        let originPoint: Vector2D
        
        if let block = origin.block {
            originPoint = Connector.touchPoint(touching: block.collisionShape,
                                               from: targetPoint,
                                               towards: block.position)
        }
        else {
            originPoint = Vector2D(origin.position)
        }
        
        let style = StockFlowConnectorStyles[typeName] ?? StockFlowConnectorStyles["_default"]!
        let connector = Connector(originPoint: originPoint,
                                  targetPoint: targetPoint,
                                  midpoints: [],
                                  style: style)
        node.connector = connector
        canvas.addChild(node: node)
        draggingConnector = node
        self.typeName = typeName
    }
    
    override func inputMoved(event: InputEvent, moveDelta: Vector2) -> Bool {
        guard state == .connect else { return true }
        guard let originID = self.originBlock?.objectID else { GD.pushError("No origin ID for dragging connector"); return true }
        guard let draggingConnector else { GD.pushError("No dragging connector") ; return true }
        guard let connector = draggingConnector.connector else { GD.pushError("Empty dragging connector"); return true }
        
        // TODO: To local?
        let newPosition = (connector.targetPoint + Vector2D(moveDelta))
        draggingConnector.connector!.targetPoint = newPosition
        draggingConnector.position = newPosition.asGodotVector2()
        
        guard let target = canvas?.hitObject(at: newPosition.asGodotVector2()),
              let targetID = target.objectID else
        {
            Input.setDefaultCursorShape(.drag)
            return true
        }
        guard targetID != originID else {
            Input.setDefaultCursorShape(.forbidden)
            return true
        }
        if self.canConnect(typeName: typeName, from: originID, to: targetID) {
            Input.setDefaultCursorShape(.canDrop)
        }
        else {
            Input.setDefaultCursorShape(.forbidden)
        }

        return true
    }
    func canConnect(typeName: String, from originID: PoieticCore.ObjectID, to targetID: PoieticCore.ObjectID) -> Bool {
        guard let ctrl = designController else {
            GD.pushError("Broken design controller")
            return false
        }
        guard let type = ctrl.design.metamodel.objectType(name: typeName) else {
            GD.pushError("Invalid connector type: \(typeName)")
            return false
        }
        return ctrl.checker.canConnect(type: type,
                                       from: originID,
                                       to: targetID,
                                       in: ctrl.currentFrame)
    }
    
    override func inputEnded(event: InputEvent, pointerPosition: Vector2) -> Bool {
        defer {
            Input.setDefaultCursorShape(.arrow)
            cancelConnectSession()
        }

        guard state == .connect else { return true }
        guard let originID = self.originBlock?.objectID else { GD.pushError("No origin ID for dragging connector"); return true }
        guard let draggingConnector else { GD.pushError("No dragging connector") ; return true }
        guard let someTarget = canvas?.hitObject(at: pointerPosition),
              let target = someTarget as? DiagramCanvasBlock,
              let targetID = target.objectID else
        {
            // TODO: Do some puff animation here
            return true
        }
        state = .empty
        createEdge(from: originID, to: targetID)
        return true
    }
    
    func cancelConnectSession() {
        originBlock = nil
        if let draggingConnector {
            draggingConnector.queueFree()
            self.draggingConnector = nil
        }
        state = .empty
    }
    
    func createEdge(from originID: PoieticCore.ObjectID, to targetID: PoieticCore.ObjectID) {
        // TODO: Make this a command
        guard let ctrl = designController else {
            GD.pushError("Design controller is not set up properly")
            return
        }
        guard let type = ctrl.design.metamodel.objectType(name: typeName) else {
            GD.pushError("Invalid connector type: \(typeName)")
            return
        }
        var trans = ctrl.newTransaction()
        guard trans.contains(originID) else {
            GD.pushError("Unknown object ID \(originID)")
            return
        }
        guard trans.contains(targetID) else {
            GD.pushError("Unknown object ID \(targetID)")
            return
        }
        let edge = trans.createEdge(type, origin: originID, target: targetID)
        ctrl.accept(trans)
    }
}
