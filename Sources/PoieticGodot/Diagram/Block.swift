//
//  DiagramBlock.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 18/08/2025.
//

import SwiftGodot
import Diagramming
import PoieticCore

// FIXME: Selection shape
// FIXME: Label positions
let TouchShapeRadius: Double = 2.0

@Godot
public class DiagramCanvasBlock: DiagramCanvasObject {
    var block: Block?
    var pictogramCurves: [SwiftGodot.Curve2D]

    @Export var pictogramColor: SwiftGodot.Color
    @Export var pictogramLineWidth: Double = 1.0
    
    @Export var collisionShape: SwiftGodot.CollisionShape2D?
    @Export var hasPrimaryLabel: Bool = true
    @Export var primaryLabel: SwiftGodot.Label?
    @Export var hasSecondaryLabel: Bool = false
    @Export var secondaryLabel: SwiftGodot.Label?
    
    @Export var hasValueIndicator: Bool = false
    @Export var valueIndicator: SwiftGodot.Node2D?

    required init(_ context: InitContext) {
        self.pictogramCurves = []
        self.pictogramColor = SwiftGodot.Color(code: "green")
        super.init(context)
    }
    
    public override func _process(delta: Double) {
        if isDirty {
            updateVisuals()
        }
    }
    
    /// Sets the object as needing to update visuals.
    ///
    /// - SeeAlso: ``updateVisuals()``
    ///
    @Callable(autoSnakeCase: true)
    public func setDirty() {
        self.isDirty = true
    }

    func _prepareChildren(for block: Block) {
        if self.primaryLabel == nil {
            self.primaryLabel = SwiftGodot.Label()
            self.primaryLabel!.horizontalAlignment = .center
            self.addChild(node: self.primaryLabel!)
        }
        if self.secondaryLabel == nil {
            self.secondaryLabel = SwiftGodot.Label()
            self.secondaryLabel!.horizontalAlignment = .center
            self.addChild(node: self.secondaryLabel!)
        }
        if self.collisionShape == nil {
            self.collisionShape = SwiftGodot.CollisionShape2D()
            self.addChild(node: self.collisionShape)
        }
    }
    
    func setLabel(_ label: SwiftGodot.Label, text: String?, emptyText: String? = nil, themeType: SwiftGodot.StringName = "Label") {
        let theme = ThemeDB.getProjectTheme()
        guard let text else {
            label.text = ""
            label.visible = false
            return
        }
        
        if let emptyText, text.isVisuallyEmpty {
            if let font = theme?.getFont(name: SwiftGodot.StringName(EmptyLabelTextFontKey), themeType: themeType) {
                label.addThemeFontOverride(name: "font", font: font)
            }
            if let color = theme?.getColor(name: SwiftGodot.StringName(EmptyLabelTextFontColorKey), themeType: themeType) {
                label.addThemeColorOverride(name: "font_color", color: color)
            }
            label.text = emptyText
        }
        else {
            label.removeThemeFontOverride(name: "font")
            label.removeThemeColorOverride(name: "font_color")
            label.text = text
        }
    }

    public override func _draw() {
        for curve in self.pictogramCurves {
            let points = curve.tessellate()
            self.drawPolyline(points: points, color: pictogramColor, width: pictogramLineWidth)
        }
    }
    
    func updateContent(from block: Block) {
        _prepareChildren(for: block)
        
        // 1. Basics
        self.objectID = block.objectID
        self.block = block
        self.name = StringName(block.godotName(prefix: DiagramBlockNamePrefix))
        self.updateVisuals()

        // 2. Pictogram
        if let pictogram = block.pictogram {
            let shape = pictogram.collisionShape.shape.asGodotShape2D()
            
            // TODO: We are not using it
            if let collisionShape = self.collisionShape {
                collisionShape.shape = shape
                collisionShape.position = (-pictogram.origin).asGodotVector2()
            }
            
            let translatedPath = pictogram.path.transform(AffineTransform(translation: -pictogram.origin))
            self.pictogramCurves = translatedPath.asGodotCurves()
        }
        else {
            self.collisionShape = nil
            self.pictogramCurves = []
        }
        // 3. Labels
        
        if let label = self.primaryLabel {
            setLabel(label, text: block.label, emptyText: "(empty)", themeType: "PrimaryLabel")
        }

        if let label = self.secondaryLabel {
            setLabel(label, text: block.secondaryLabel, emptyText: nil, themeType: "SecondaryLabel")
        }

//        if object.type.hasTrait(.NumericIndicator) {
//            // TODO: Implement value indicators
//        }

        self.queueRedraw()
    }
    
    func updateVisuals() {
        guard let block else { return }
        guard let canvas = self.getParent() as? DiagramCanvas else { return }
        self.position = canvas.fromDesign(block.position)
    }
    
    var savedPrimaryLabelEditVisible: Bool = false
    
    func beginLabelEdit() {
        savedPrimaryLabelEditVisible = self.primaryLabel?.visible ?? false
        self.primaryLabel?.visible = false
    }
    
    func finishLabelEdit() {
        self.primaryLabel?.visible = savedPrimaryLabelEditVisible
    }

    override public func containsTouch(globalPoint: SwiftGodot.Vector2) -> Bool {
        guard let collisionShape else { return false }
        let localTouch = toLocal(globalPoint: globalPoint)
        let touchShape = CircleShape2D()
        touchShape.radius = TouchShapeRadius
        let touchTransform = self.transform.translated(offset: localTouch)
        let localTransform = self.transform.translated(offset: collisionShape.position)
        return collisionShape.shape!.collide(localXform: localTransform,
                                             withShape: touchShape,
                                             shapeXform: touchTransform)
    }
}
