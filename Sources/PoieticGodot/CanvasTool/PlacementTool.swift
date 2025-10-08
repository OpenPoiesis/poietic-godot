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
    
    // FIXME: This is a legacy binding to makeshift Godot implementation
    /// Auxiliary node that contains a collection of objects to be placed.
    ///
    /// The palette is to be provided by Godot caller.
    ///
    @Export var objectPanel: SwiftGodot.PanelContainer?
    
    var lastPointerPosition = Vector2()
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

        createIntentShadow(typeName: identifier, canvasPosition: Vector2.zero)
    }
    
        
    func placeObject(typeName: String, globalPosition: Vector2) {
        // TODO: Make this a Command
        // FIXME: Bind type directly to the template block
        guard let ctrl = designController,
              let canvas else {
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
    
    override func inputBegan(event: InputEvent, globalPosition: Vector2) -> Bool {
        guard let canvas else { return false }
        // TODO: Add shadow (also on input moved)
        // open_panel(pointer_position)
        // Global.set_modal(palette)
        guard let identifier = paletteItemIdentifier else {
            GD.pushError("No selected item identifier for placement tool")
            return true
        }
        let canvasPosition = canvas.toLocal(globalPoint: globalPosition)
        createIntentShadow(typeName: identifier, canvasPosition: canvasPosition)
        return true
    }
    
    override func inputEnded(event: InputEvent, globalPosition: Vector2) -> Bool {
        guard let canvas else { return false }
        guard let paletteItemIdentifier else {
            return true
        }
        placeObject(typeName: paletteItemIdentifier, globalPosition: globalPosition)
        // TODO: Implement "tool locking"
        if let app = self.application {
            app.switchTool(app.selectionTool)
        }
        return true
    }
    
    override func inputMoved(event: InputEvent, globalPosition: Vector2) -> Bool {
        guard let canvas,
              let intentShadow else { return true }
        let canvasPosition = canvas.toLocal(globalPoint: globalPosition)
        intentShadow.position = canvasPosition
        return true
    }
    
    override func inputHover(event: InputEvent, globalPosition: Vector2) -> Bool {
        guard let canvas,
              let intentShadow else { return false }
        let canvasPosition = canvas.toLocal(globalPoint: globalPosition)
        intentShadow.position = canvasPosition
        return true
    }
    
    func createIntentShadow(typeName: String, canvasPosition: Vector2) {
        guard let canvas,
              let canvasController else { return }

        if let intentShadow {
            intentShadow.queueFree()
            self.intentShadow = nil
        }
        // FIXME: Use block library for pictograms
        guard let pictogram = canvasController.pictograms?.pictogram(typeName) else {
            GD.pushError("No pictogram for type '\(typeName)'")
            return
        }

        let shadow = Pictogram2D()

        let theme = ThemeDB.getProjectTheme()
        if let color = theme?.getColor(name: SwiftGodot.StringName(ShadowColorKey),
                                       themeType: SwiftGodot.StringName(CanvasThemeType))
        {
            shadow.color = color
        }
        else {
            shadow.color = SwiftGodot.Color(r: 0.5, g: 0.5, b: 0.1, a: 0.8)
        }

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

