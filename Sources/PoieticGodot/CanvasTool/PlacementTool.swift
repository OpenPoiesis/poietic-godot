//
//  PlaceTool.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 02/09/2025.
//

import SwiftGodot
import PoieticCore

typealias ObjectPalette = Int
typealias ObjectPanel = Int

@Godot
class PlaceTool: CanvasTool {
    var selectedItemIdentifier: String?
    var lastPointerPosition = Vector2()
    var intentShadow: CanvasShadow?

    required init(_ context: SwiftGodot.InitContext) {
        super.init(context)
    }
    
    override func toolName() -> String {
        return "place"
    }
    
    override func toolSelected() {
        objectPalette?.show()
        // FIXME: Add palette loading
//        object_panel.load_node_pictograms()
//        object_panel.selection_changed.connect(_on_object_selection_changed)
        
        if let _ = selectedItemIdentifier {
//            object_panel.selected_item = lastSelectedObjectIdentifier
        }
        else {
//            object_panel.selected_item = "Stock"
        }
    }
    
    override func toolReleased() {
//        lastSelectedObjectIdentifier = object_panel.selected_item
//        object_panel.selection_changed.disconnect(_on_object_selection_changed)
        removeIntentShadow()
    }
    
    func _on_object_selection_changed(identifier: String) {
        if intentShadow == nil {
            removeIntentShadow()
        }
        createIntentShadow(typeName: identifier, pointerPosition: Vector2.zero)
    }
    
        
    func _on_place_object(position: Vector2, typeName: String) {
        placeObject(at: position, typeName: typeName)
        objectPalette?.hide()
    }
    
    func placeObject(at position: Vector2, typeName: String) {
        // TODO: Make this a Command
        // FIXME: Bind type directly to the template block
        guard let ctrl = designController else {
            GD.pushError("Design controller is not set up properly")
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
        var localPosition = canvas?.toLocal(globalPoint: position)
        var node = trans.createNode(type)
        node.position = Point(position)
        ctrl.accept(trans)
        self.canvas?.selection.replace([node.objectID])
    }
    
    override func inputBegan(event: InputEvent, pointerPosition: Vector2) -> Bool {
        // TODO: Add shadow (also on input moved)
        // open_panel(pointer_position)
        // Global.set_modal(palette)
        guard let identifier = selectedItemIdentifier else {
            GD.pushError("No selected item identifier for placement tool")
            return true
        }
        createIntentShadow(typeName: identifier, pointerPosition: pointerPosition)
        return true
    }
    
    override func inputEnded(event: InputEvent, pointerPosition: Vector2) -> Bool {
        guard let selectedItemIdentifier else {
            removeIntentShadow()
            return true
        }
        placeObject(at: pointerPosition, typeName: selectedItemIdentifier)
        removeIntentShadow()
        return true
    }
    
    override func inputMoved(event: InputEvent, moveDelta: Vector2) -> Bool {
        guard let intentShadow else { return true }
        guard let canvas else { return false }
        intentShadow.position += canvas.toLocal(globalPoint: moveDelta)
        return true
    }
    
    override func inputHover(event: InputEvent, pointerPosition: Vector2) -> Bool {
        guard let intentShadow else { return true }
        guard let canvas else { return false }
        intentShadow.position = canvas.toLocal(globalPoint: pointerPosition)
        return true
    }
    
    func createIntentShadow(typeName: String, pointerPosition: Vector2) {
        // TODO: Handle error
        guard let canvas else { preconditionFailure("No canvas") }
        guard intentShadow == nil else { fatalError("Intent shadow is already set") }
        
        let shadow = CanvasShadow()
        
        guard let diagramController else { preconditionFailure("No diagram controller") }
        // FIXME: Use block library for pictograms
        guard let pictogram = diagramController.pictograms?.pictogram(typeName) else {
            preconditionFailure("No pictogram for type '\(typeName)'")
        }
        shadow.pictogramCurves = pictogram.path.asGodotCurves()
        shadow.position = canvas.toLocal(globalPoint: pointerPosition)

        canvas.addChild(node: shadow)
        intentShadow = shadow
    }
    
    func removeIntentShadow() {
        guard let intentShadow else { return }
        intentShadow.free()
    }
}

// TODO: Make this PictogramNode
class CanvasShadow: SwiftGodot.Node2D {
    // FIXME: Make this settable through godot
    var pictogramCurves:  [SwiftGodot.Curve2D]
    @Export var pictogramColor: SwiftGodot.Color
    @Export var pictogramLineWidth: Double = 1.0

    required init(_ context: InitContext) {
        let theme = ThemeDB.getProjectTheme()
        if let color = theme?.getColor(name: SwiftGodot.StringName(ShadowColorKey),
                                       themeType: SwiftGodot.StringName(CanvasThemeType))
        {
            pictogramColor = color
        }
        else {
            pictogramColor = SwiftGodot.Color(r: 0.5, g: 0.5, b: 0.1, a: 0.8)
        }

        self.pictogramCurves = []
        super.init(context)
    }

    public override func _draw() {
        for curve in self.pictogramCurves {
            let points = curve.tessellate()
            self.drawPolyline(points: points, color: pictogramColor, width: pictogramLineWidth)
        }
    }
}
