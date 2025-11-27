//
//  PlaceTool.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 02/09/2025.
//

import SwiftGodot
import PoieticCore
import Diagramming

@Godot
class PlaceTool: CanvasTool {
    var lastPointerPosition = Vector2()
    /// Shadow rendering of a node that is intended to be placed.
    var intentShadow: Pictogram2D?

    required init(_ context: SwiftGodot.InitContext) {
        super.init(context)
    }
    
    override func toolName() -> String { "place" }
    override func paletteName() -> String? { PlaceToolPaletteName }

    override func toolSelected() {
        if paletteItemIdentifier == nil {
            paletteItemIdentifier = DefaultBlockNodeType
        }
    }
    
    override func toolReleased() {
        removeIntentShadow()
    }
    
    override func paletteItemChanged(_ identifier: String?) {
        if intentShadow != nil {
            removeIntentShadow()
        }
        guard let identifier else { return }
    }
    
    func placeObject(canvas: DiagramCanvas, typeName: String, globalPosition: Vector2) {
        // TODO: Make this a Command
        guard let ctrl = designController
        else {
            GD.pushError("PlaceTool is not set up properly")
            return
        }
        guard let type = ctrl._metamodel.objectType(name: typeName) else {
            GD.pushError("Unknown object type `\(typeName)`")
            return
        }
        let frame = ctrl.currentFrame

        var trans = ctrl.newTransaction()
        var count = frame.filter(type: type).count
        var name = typeName.toSnakeCase() + String(count)
        var localPosition = canvas.toLocal(globalPoint: globalPosition)
        var node = trans.createNode(type)
        node.position = Point(localPosition)
        node["name"] = Variant(name)
        ctrl.accept(trans)
        ctrl.selectionManager.replaceAll([node.objectID])
        // TODO: Select currently created node
    }
    
    override func inputBegan(canvas: DiagramCanvas, event: InputEvent, globalPosition: Vector2) -> Bool {
        guard let identifier = paletteItemIdentifier else {
            GD.pushError("No selected item identifier for placement tool")
            return true
        }
        let canvasPosition = canvas.toLocal(globalPoint: globalPosition)
        createIntentShadow(canvas: canvas, typeName: identifier, canvasPosition: canvasPosition)
        return true
    }
    
    override func inputEnded(canvas: DiagramCanvas, event: InputEvent, globalPosition: Vector2) -> Bool {
        guard let paletteItemIdentifier else {
            return true
        }
        placeObject(canvas: canvas, typeName: paletteItemIdentifier, globalPosition: globalPosition)
        // TODO: Implement "tool locking"
        if let app = self.application {
            app.switchTool(app.selectionTool)
        }
        return true
    }
    
    override func inputMoved(canvas: DiagramCanvas, event: InputEvent, globalPosition: Vector2) -> Bool {
        
        guard let intentShadow else { return true }
        let canvasPosition = canvas.toLocal(globalPoint: globalPosition)
        intentShadow.position = canvasPosition
        return true
    }
    
    override func inputHover(canvas: DiagramCanvas, event: InputEvent, globalPosition: Vector2) -> Bool {
        guard let identifier = paletteItemIdentifier else { return false }
        if intentShadow == nil {
            let canvasPosition = canvas.toLocal(globalPoint: globalPosition)
            createIntentShadow(canvas: canvas, typeName: identifier, canvasPosition: canvasPosition)
        }
        let canvasPosition = canvas.toLocal(globalPoint: globalPosition)
        intentShadow?.position = canvasPosition
        return true
    }
    
    func createIntentShadow(canvas: DiagramCanvas, typeName: String, canvasPosition: Vector2) {
        guard let designController else { return }

        if let intentShadow {
            intentShadow.queueFree()
            self.intentShadow = nil
        }
        // FIXME: Use block library for pictograms
        guard let pictogram = designController.notation?.pictogram(typeName) else {
            GD.pushError("No pictogram for type '\(typeName)'")
            return
        }

        let shadow = Pictogram2D()

        shadow.color = canvas.style?.intentShadowColor ?? DefaultIntentShadowColor
        shadow.setPictogram(pictogram)
        shadow.position = canvasPosition
        shadow.name = "placement-intent-shadow"
        canvas.addChild(node: shadow)
        self.intentShadow = shadow
    }
    
    func removeIntentShadow() {
        guard let intentShadow else { return }
        intentShadow.queueFree()
        self.intentShadow = nil
    }
}

