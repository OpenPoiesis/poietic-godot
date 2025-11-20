//
//  DiagramBlock.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 18/08/2025.
//

import SwiftGodot
import Diagramming
import PoieticCore

/// Offset of value indicator from the top of the pictogram
public let ValueIndicatorVerticalOffset: Double = 4.0

// FIXME: Rename to just "CanvasBlock"
@Godot
public class DiagramCanvasBlock: DiagramCanvasObject {
    @Export var pictogram: Pictogram2D?
    @Export var collisionShape: SwiftGodot.CollisionShape2D?
    @Export var colorSwatch: SwiftGodot.Polygon2D?

    var pictogramBox: Rect2D = Rect2D()
    
    // TODO: Remove show*Label
    // Discussion: We need "has*" so we know whether we can show it or not. Show* is redundant here.
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
    @Export var valueIndicator: ValueIndicator?

    @Export var displayValue: Double? {
        didSet {
            self.updateValueIndicator()
        }
    }

    /// Canvas owning the block. Nil if the block is not under a canvas hierarchy.
    ///
    public var canvas: DiagramCanvas? {
        var parent: Node? = self.getParent()
        while parent != nil {
            if let result = parent as? DiagramCanvas {
                return result
            }
            parent = parent?.getParent()
        }
        return nil
    }
    
    func _prepareChildren() {
        if self.issueIndicator == nil {
            let issueIndicator = CanvasIssueIndicator()
            issueIndicator.visible = hasIssues
            self.addChild(node: issueIndicator)
            self.issueIndicator = issueIndicator
        }
        if self.pictogram == nil {
            let pictogram = Pictogram2D()
            self.addChild(node: pictogram)
            self.pictogram = pictogram
        }
        if self.primaryLabel == nil {
            let label = SwiftGodot.Label()
            label.horizontalAlignment = .center
            label.verticalAlignment = .top
            label.themeTypeVariation = "PrimaryBlockLabel"
            self.addChild(node: label)
            self.primaryLabel = label
        }
        if self.secondaryLabel == nil {
            let label = SwiftGodot.Label()
            label.horizontalAlignment = .center
            label.verticalAlignment = .top
            label.themeTypeVariation = "SecondaryBlockLabel"
            self.addChild(node: label)
            self.secondaryLabel = label
        }
        if self.valueIndicator == nil {
            // TODO: Use Canvas value indicator prototype to get common style
            let indicator: ValueIndicator
            if let prototype = self.canvas?.valueIndicatorPrototype,
               let dupe = prototype.duplicate() as? ValueIndicator
            {
                indicator =  dupe
            }
            else {
                indicator = ValueIndicator()
            }
            self.addChild(node: indicator)
            indicator.show()
            self.valueIndicator = indicator
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
        
        if self.colorSwatch == nil {
            let swatch = Polygon2D()
            let halfSize = ColorSwatchSize / 2.0
            let points: [SwiftGodot.Vector2] = [
                SwiftGodot.Vector2(x: -halfSize, y: -halfSize),
                SwiftGodot.Vector2(x: +halfSize, y: -halfSize),
                SwiftGodot.Vector2(x: +halfSize, y: +halfSize),
                SwiftGodot.Vector2(x: -halfSize, y: +halfSize),
            ]
            swatch.polygon = PackedVector2Array(points)
            swatch.visible = false
            self.addChild(node: swatch)
            self.colorSwatch = swatch
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
    
    func setLabel(_ label: SwiftGodot.Label, text: String?, emptyText: String? = nil, settings: LabelSettings?=nil, emptySettings: LabelSettings?=nil) {
        let theme = ThemeDB.getProjectTheme()
        guard let text else {
            label.text = ""
            label.visible = false
            return
        }
        
        if let emptyText, text.isVisuallyEmpty {
            if let settings = emptySettings ?? settings {
                label.labelSettings = settings
            }
            else {
                label.labelSettings = nil
            }
            label.text = emptyText
        }
        else {
            label.labelSettings = settings
            label.text = text
        }
    }

    @Callable(autoSnakeCase: true)
    func updateValueIndicator() {
        guard let valueIndicator else { return }
        valueIndicator.value = displayValue
    }
    
    var savedPrimaryLabelEditVisible: Bool = false
    
    @Callable(autoSnakeCase: true)
    func beginLabelEdit() {
        savedPrimaryLabelEditVisible = self.primaryLabel?.visible ?? false
        self.primaryLabel?.visible = false
    }
    
    @Callable(autoSnakeCase: true)
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
