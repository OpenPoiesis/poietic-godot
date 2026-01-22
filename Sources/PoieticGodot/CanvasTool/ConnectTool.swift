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
    @Export var lastPointerPosition = Vector2()
    @Export var draggingConnector: DiagramCanvasConnector?

    @Export var originID: PoieticCore.RuntimeID?
//    @Export var originID: GodotRuntimeEntityID?
    var draggingGlyph: ConnectorGlyph?

    override func toolName() -> String { "connect" }
    override func paletteName() -> String? { ConnectToolPaletteName }

    override func toolSelected() {
        if paletteItemIdentifier == nil {
            paletteItemIdentifier = DefaultConnectorEdgeType
        }
    }
    
    override func paletteItemChanged(_ identifier: String?) {
        guard let identifier else {
            return
        }
        if !ConnectorEdgeTypes.contains(identifier) {
            GD.pushError("Invalid connector (edge) type:", identifier)
            return
        }
    }

    override func inputBegan(canvas: DiagramCanvas, event: InputEvent, globalPosition: Vector2) -> Bool {
        guard let origin = canvas.hitObject(globalPosition: globalPosition) as? DiagramCanvasBlock,
              let originID = origin.runtimeID
        else { return true }

        let typeName = paletteItemIdentifier ?? DefaultConnectorEdgeType
        // TODO: Validate type name
        
        let canvasPosition = canvas.toLocal(globalPoint: globalPosition)
        let targetPoint = Vector2D(canvasPosition)
        self.createDragConnector(canvas: canvas,
                                 type: typeName,
                                 origin: originID,
                                 targetPoint: targetPoint)
        self.originID = originID
        
        state = .connect
        Input.setDefaultCursorShape(.drag)
        return true
    }
    
    override func inputMoved(canvas: DiagramCanvas, event: InputEvent, globalPosition: Vector2) -> Bool {
        guard state == .connect else { return true }
        guard let originID = originID,
              let draggingConnector
        else { GD.pushError("Dragging connector not initialized") ; return false }

        let canvasPosition = canvas.toLocal(globalPoint: globalPosition)
        let targetPoint = Vector2D(canvasPosition)
        self.updateDragConnector(canvas: canvas, targetPoint: targetPoint)

        let canvasPoint = canvas.fromDesign(targetPoint)
        guard let target = canvas.hitObject(globalPosition: globalPosition),
              let targetID = target.runtimeID else
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
    
    func canConnect(typeName: String, from originID: RuntimeID, to targetID: RuntimeID) -> Bool {
        guard let ctrl = designController,
              let originObjectID = ctrl.world.entityToObject(originID),
              let targetObjectID = ctrl.world.entityToObject(targetID)
        else { return false }

        guard let type = ctrl.design.metamodel.objectType(name: typeName) else {
            GD.pushError("Invalid connector type: \(typeName)")
            return false
        }
        let flag = ctrl.checker.canConnect(type: type,
                                           from: originObjectID,
                                           to: targetObjectID,
                                           in: ctrl.currentFrame)
        return flag
    }
    
    override func inputEnded(canvas: DiagramCanvas, event: InputEvent, globalPosition: Vector2) -> Bool {
        defer {
            Input.setDefaultCursorShape(.arrow)
            cancelConnectSession()
        }

        guard state == .connect else { return false }
        guard let ctrl = designController,
              let target = canvas.hitObject(globalPosition: globalPosition) as? DiagramCanvasBlock,
              let originID,
              let targetID = target.runtimeID,
              let originObjectID = ctrl.world.entityToObject(originID),
              let targetObjectID = ctrl.world.entityToObject(targetID)
        else {
            // TODO: Do some puff animation here
            return true
        }
        let typeName = paletteItemIdentifier ?? DefaultConnectorEdgeType

        if self.canConnect(typeName: typeName, from: originID, to: targetID) {
            createEdge(typeName: typeName, from: originObjectID, to: targetObjectID)
            // TODO: Implement "tool locking"
            if let app = self.application {
                app.switchTool(app.selectionTool)
            }
        }
        else {
            // TODO: Puff!
        }
        return true
    }
    
    func cancelConnectSession() {
        self.originID = nil
        self.draggingGlyph = nil
        self.draggingConnector?.queueFree()
        self.draggingConnector = nil
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

// MARK: - Drag Connector
//
extension ConnectTool {
    /// Create a connector originating in a block and ending at a given point, typically
    /// a mouse position.
    ///
    /// Use this to make a connector that is being created using a mouse pointer or by a touch.
    ///
    /// - SeeAlso: ``updateDragConnector(connector:origin:targetPoint:)``
    ///
    public func createDragConnector(canvas: DiagramCanvas,
                                    type: String,
                                    origin originID: RuntimeID,
                                    targetPoint: Vector2D) -> DiagramCanvasConnector? {
        guard let world = designController?.world,
              let block: DiagramBlock = world.component(for:originID),
              let style = canvas.style
        else { return nil }

        let notation: Notation = world.singleton() ?? Notation.DefaultNotation
        let rules: NotationRules = world.singleton() ?? NotationRules()

        let drag = DiagramCanvasConnector()
        drag.ignoreAsTarget = true // This is just a decoration
        let originTouch = Geometry.touchPoint(shape: block.collisionShape.shape,
                                              position: block.position + block.collisionShape.position,
                                              from: targetPoint,
                                              towards: block.position)
        let glyph = notation.connectorGlyph(type)

        let geometry = DiagramConnectorGeometry(originTouch: originTouch,
                                                targetTouch: targetPoint,
                                                glyph: glyph)

        drag.updateGeometry(geometry)
        drag.fillColor = style.defaultConnectorFillColor
        drag.fillColor.alpha = DefaultFatConnectorFillAlpha
        drag.lineColor = style.defaultConnectorColor
        drag.lineWidth = style.defaultConnectorLineWidth
        drag.queueRedraw()

        canvas.addChild(node: drag)
        self.draggingGlyph = glyph
        self.originID = originID
        self.draggingConnector = drag
        return drag
    }
    
    
    /// Update a connector originating in a block and ending at a given point, typically
    /// a mouse position.
    ///
    /// Use this to update a connector that is being created using a mouse pointer or by a touch.
    ///
    /// - SeeAlso: ``createDragConnector(type:origin:targetPoint:)``
    ///
    public func updateDragConnector(canvas: DiagramCanvas, targetPoint: Vector2D)
    {
        guard let drag = draggingConnector,
              let originID,
              let glyph = draggingGlyph,
              let world = designController?.world,
              let block: DiagramBlock = world.component(for:originID),
              let style = canvas.style
        else { return }

        let originTouch = Geometry.touchPoint(shape: block.collisionShape.shape,
                                              position: block.position + block.collisionShape.position,
                                              from: targetPoint,
                                              towards: block.position)
        let geometry = DiagramConnectorGeometry(originTouch: originTouch,
                                                targetTouch: targetPoint,
                                                glyph: glyph)

        drag.updateGeometry(geometry)
        drag.fillColor = style.defaultConnectorFillColor
        drag.fillColor.alpha = DefaultFatConnectorFillAlpha
        drag.lineColor = style.defaultConnectorColor
        drag.lineWidth = style.defaultConnectorLineWidth

        drag.queueRedraw()
    }

}
