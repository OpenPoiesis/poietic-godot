//
//  DiagramBlock.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 18/08/2025.
//

import SwiftGodot
import Diagramming
import PoieticCore

// FIXME: Label positions

@Godot
public class DiagramCanvasBlock: DiagramCanvasObject {
    var debugHandle: CanvasHandle?
    
    
    // TODO: Remove inner Block, use something like DiagramBlock protocol with the composer
    var block: Block?
    var pictogramCurves: [SwiftGodot.Curve2D]

    @Export var pictogramColor: SwiftGodot.Color
    @Export var pictogramLineWidth: Double = 1.0
    
    @Export var collisionShape: SwiftGodot.CollisionShape2D?
    
    // TODO: Review necessity of has*Label
    @Export var hasPrimaryLabel: Bool = true
    /// Primary label of a block, typically a block name.
    @Export var primaryLabel: SwiftGodot.Label?
    /// Flag whether the primary label (usually a name) is shown regardless of its presence.
    ///
    /// Labels are typically hidden when a label editing prompt is present. Label visibility
    /// is set to this flag after editing is finished.
    @Export var showsPrimaryLabel: Bool = true

    @Export var hasSecondaryLabel: Bool = false
    /// Secondary label of a bloc, usually a formula or some relevant variable value.
    ///
    @Export var secondaryLabel: SwiftGodot.Label?
    /// Flag whether the secondary label (formula or some other attribute) is shown regardless of
    /// its presence.
    ///
    /// Labels are typically hidden when a label editing prompt is present. Label visibility
    /// is set to this flag after editing is finished.
    @Export var showsSecondaryLabel: Bool = true

    @Export var hasValueIndicator: Bool = false
    @Export var valueIndicator: SwiftGodot.Node2D?

    required init(_ context: InitContext) {
        self.pictogramCurves = []
        self.pictogramColor = SwiftGodot.Color(code: "white")
        super.init(context)
    }
    
    public override func _process(delta: Double) {
        if isDirty {
            updateVisuals()
        }
    }
    public override func _ready() {
        if let debugHandle {
            debugHandle.queueFree()
        }
        debugHandle = CanvasHandle()
        debugHandle?.color = Color.red
        debugHandle?.fillColor = Color.salmon
        debugHandle?.isFilled = true
        debugHandle?.size = 6
        self.addChild(node: debugHandle)
        
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
            let label = SwiftGodot.Label()
            label.horizontalAlignment = .center
            label.verticalAlignment = .top
            self.addChild(node: label)
            self.primaryLabel = label
        }
        if self.secondaryLabel == nil {
            let label = SwiftGodot.Label()
            label.horizontalAlignment = .center
            label.verticalAlignment = .top
            self.addChild(node: label)
            self.secondaryLabel = label
        }
        if self.collisionShape == nil {
            self.collisionShape = SwiftGodot.CollisionShape2D()
            self.addChild(node: self.collisionShape)
        }
        if self.selectionOutline == nil {
            let outline = SelectionOutline()
            outline.visible = self._isSelected
            self.selectionOutline = outline
            self.addChild(node: outline)
        }
    }
   
    /// Set the label visibility according to the label visibility flags ``showsPrimaryLabel``
    /// and ``showsSecondaryLabel``.
    ///
    /// - SeeAlso: ``hideLabels()``
    ///
    @Callable(autoSnakeCase: true)
    public func resetLabelVisibility() {
        if let primaryLabel {
            primaryLabel.visible = self.showsPrimaryLabel
        }
        if let secondaryLabel {
            secondaryLabel.visible = self.showsSecondaryLabel
        }
    }
    
    /// Make the labels hidden.
    ///
    /// - SeeAlso: ``resetLabelVisibility()``
    ///
    @Callable(autoSnakeCase: true)
    public func hideLabels() {
        if let primaryLabel {
            primaryLabel.visible = false
        }
        if let secondaryLabel {
            secondaryLabel.visible = false
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

        // 2. Pictogram and shape
        if let pictogram = block.pictogram {
            let translation = AffineTransform(translation: -pictogram.origin)
            let translatedPath = pictogram.path.transform(translation)
            self.pictogramCurves = translatedPath.asGodotCurves()

            let pictoCollision = pictogram.collisionShape

            if let selectionOutline {
                // FIXME: Use mask
                let outlinePath = pictoCollision.toPath().transform(translation)
                let curves = outlinePath.asGodotCurves()
                selectionOutline.curves = TypedArray(curves)
                selectionOutline.updateVisuals()
                selectionOutline.visible = self._isSelected
            }
            
            if let collisionShape = self.collisionShape {
                collisionShape.shape = pictoCollision.shape.asGodotShape2D()
                collisionShape.position = Vector2(pictoCollision.position - pictogram.origin)
                GD.print("--- B COL: \(pictoCollision.shape.typeName) P: \(pictogram.origin.prettyDescription) CS: \(pictoCollision.position.prettyDescription)")
            }
            
        }
        else {
            self.pictogramCurves = []
        }
        // 3. Labels
        let box = Rect2D(origin: block.pictogramBoundingBox.origin - block.position,
                         size: block.pictogramBoundingBox.size)
        // FIXME: Flipped y coords
        let bottom = LineSegment(from: box.topLeft, to: box.topRight)
        let mid = bottom.midpoint
        
        let primaryLabelOffset: Float = 0.0 // FIXME: Compute this
        let secondaryLabelOffset: Float = 16.0 // FIXME: Compute this
        
        
        if let label = self.primaryLabel {
            setLabel(label, text: block.label, emptyText: "(empty)", themeType: "PrimaryLabel")
            let size = label.getMinimumSize()
            GD.print("Label size: \(size)")
            let center = Vector2(
                x: Float(mid.x) - size.x / 2.0,
                y: Float(mid.y) + primaryLabelOffset
            )
            label.setPosition(center)
        }

        if let label = self.secondaryLabel {
            setLabel(label, text: block.secondaryLabel, emptyText: nil, themeType: "SecondaryLabel")
            let size = label.getMinimumSize()
            let center = Vector2(
                x: Float(mid.x) - size.x / 2.0,
                y: Float(mid.y) + secondaryLabelOffset
            )
            label.setPosition(center)
        }

//        if object.type.hasTrait(.NumericIndicator) {
//            // TODO: Implement value indicators
//        }

        self.updateVisuals()
        self.queueRedraw()
    }
    
    @Callable(autoSnakeCase: true)
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
