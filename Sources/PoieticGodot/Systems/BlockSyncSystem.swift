//
//  BlockSyncSystem.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 17/11/2025.
//
import PoieticCore
import SwiftGodot
import Diagramming

/// - **Dependency:** Must run after diagram block and connector components are created.
/// - **Input:** ...
/// - **Output:** ...
/// - **Forgiveness:** ...
public struct BlockSyncSystem: System {
    // TODO: Alternative names: DiagramSceneSystem
    nonisolated(unsafe) public static let dependencies: [SystemDependency] = [
        .after(BlockCreationSystem.self),
    ]
    public init() {}
    public func update(_ frame: AugmentedFrame) throws (InternalSystemError) {
        guard let canvasComponent: CanvasComponent = frame.component(for: .Frame) else {
            return
        }

        let canvas = canvasComponent.canvas
        var remaining = Set(canvas.blocks.compactMap { $0.runtimeID })
        var updated: [DiagramCanvasBlock] = []
        
        for (id, component) in frame.runtimeFilter(DiagramBlock.self) {
            sync(block: component,
                 id: id,
                 canvas: canvasComponent,
                 frame: frame)
            remaining.remove(id)
        }
        
        for id in remaining {
            canvas.removeBlock(id)
        }
    }
    
    public func sync(block: DiagramBlock,
                     id runtimeID: RuntimeEntityID,
                     canvas canvasComponent: CanvasComponent,
                     frame: AugmentedFrame) {
        // FIXME: Require style (this is just a quick hack to make swatches work)
        let style = canvasComponent.canvasStyle
        let canvas = canvasComponent.canvas
        
        let sceneNode: DiagramCanvasBlock
        if let node = canvas.block(id: runtimeID) {
            sceneNode = node
        }
        else {
            sceneNode = DiagramCanvasBlock()
            sceneNode.runtimeID = runtimeID
            canvas.insertBlock(sceneNode)
            
        }
        sceneNode._prepareChildren()
        sceneNode.name = StringName(DiagramBlockNamePrefix + runtimeID.godotNodeName)

        if let objectID = runtimeID.objectID,
           let object = frame[objectID] {
            sceneNode.hasValueIndicator = object.type.hasTrait(.NumericIndicator)
        }
        else {
            sceneNode.hasValueIndicator = false
        }

        if let objectID = runtimeID.objectID {
            sceneNode.hasIssues = frame.objectHasIssues(objectID)
        }
        else {
            sceneNode.hasIssues = false
        }


        let preview: BlockPreview? = frame.component(for: runtimeID)

        updateContent(sceneNode, runtimeID: runtimeID, block: block, style: style)
        updatePosition(sceneNode, block: block, preview: preview)
        updateLabels(sceneNode, block: block, style: style)
        updateBlockColorSwatch(sceneNode, colorName: block.accentColorName, style: style)
        updateIndicators(sceneNode)
    }

    func updateContent(_ node: DiagramCanvasBlock,
                       runtimeID: RuntimeEntityID,
                       block: DiagramBlock,
                       style: CanvasStyle)
    {
        if let pictogram = block.pictogram {
            updateBlockPictogram(node, pictogram: pictogram, style: style)
            node.pictogramBox = pictogram.pathBoundingBox
        }
        else {
            node.pictogram?.curves = TypedArray()
            node.pictogramBox = Rect2D()
        }
    }
    func updatePosition(_ node: DiagramCanvasBlock, block: DiagramBlock, preview: BlockPreview?) {
        let position = preview?.position ?? block.position
        node.position = Vector2(position)
    }
    
    func updateLabels(_ node: DiagramCanvasBlock, block: DiagramBlock, style: CanvasStyle)
    {
        // FIXME: Flipped y coords
        let bottom = LineSegment(from: node.pictogramBox.topLeft, to: node.pictogramBox.topRight)
        let mid = bottom.midpoint
        
        var labelOffset: Float = 0.0
        
        if let label = node.primaryLabel {
            node.setLabel(label, text: block.label,
                          emptyText: "(empty)",
                          settings: style.primaryLabelSettings,
                          emptySettings: style.invalidLabelSettings)
            let size = label.getMinimumSize()
            let center = Vector2(
                x: Float(mid.x) - size.x / 2.0,
                y: Float(mid.y) + PrimaryLabelOffset
            )
            label.setPosition(center)
            label.setSize(size)
            labelOffset = PrimaryLabelOffset + size.y
        }

        if let label = node.secondaryLabel {
            node.setLabel(label,
                          text: block.secondaryLabel,
                          emptyText: nil,
                          settings: style.secondaryLabelSettings,
                          emptySettings: style.invalidLabelSettings)
            let size = label.getMinimumSize()
            let center = Vector2(
                x: Float(mid.x) - size.x / 2.0,
                y: Float(mid.y) + labelOffset + SecondaryLabelOffset
            )
            label.setSize(size)
            label.setPosition(center)
        }
    }
    
    /// Requires pictogram box to be computed first. See ``updateBlockPictogram(...)``.
    ///
    public func updateBlockColorSwatch(_ node: DiagramCanvasBlock,
                                       colorName: String?,
                                       style: CanvasStyle) {
        guard let colorSwatch = node.colorSwatch else { return }
        // FIXME: Flipped y coords
        let bottom = LineSegment(from: node.pictogramBox.topLeft, to: node.pictogramBox.topRight)
        let mid = bottom.midpoint

        if let label = node.primaryLabel {
            let size = label.getSize()
            let position = label.getPosition() + Vector2(x: -ColorSwatchSize, y: size.y / 2)
            colorSwatch.position = position
        }
        else {
            colorSwatch.position = Vector2(mid)
        }
        if let colorName {
            colorSwatch.color = style.getAdaptableColor(name: colorName, defaultColor: Color.gray)
            colorSwatch.show()
        }
        else {
            colorSwatch.color = Color.gray
            colorSwatch.hide()
        }
    }

    public func updateBlockPictogram(_ node: DiagramCanvasBlock,
                              pictogram: Pictogram,
                              style: CanvasStyle)
    {
        node.pictogram?.setPictogram(pictogram)
        node.pictogram?.lineWidth = style.getLineWidth(pictogram.name)
        node.pictogram?.color = style.pictogramColor
        let pictoCollision = pictogram.collisionShape

        node.collisionShape?.shape = pictoCollision.shape.asGodotShape2D()
        node.collisionShape?.position = Vector2(pictoCollision.position)

        if let selectionOutline = node.selectionOutline {
            let curves = pictogram.mask.asGodotCurves()
            selectionOutline.curves = TypedArray(curves)
            selectionOutline.fillColor = style.selectionFillColor
            selectionOutline.outlineColor = style.selectionOutlineColor
            selectionOutline.queueRedraw()
            selectionOutline.visible = node._isSelected
        }
    }
    
    /// Update issue and value indicator based on pictogram bounding box.
    func updateIndicators(_ node: DiagramCanvasBlock)
    {
        let box = node.pictogramBox
        if let indicator = node.issueIndicator {
            let midTop = box.bottomLeft + Vector2D(box.width / 2, 0)
            indicator.position = Vector2(midTop)
        }
        
        if let indicator = node.valueIndicator {
            let offset = Vector2D(box.width / 2,
                                  -(Double(indicator.size.y) + ValueIndicatorVerticalOffset))
            indicator.position = Vector2(box.bottomLeft + offset)
            
            if !node.hasValueIndicator {
                indicator.hide()
            }
        }

    }
}
