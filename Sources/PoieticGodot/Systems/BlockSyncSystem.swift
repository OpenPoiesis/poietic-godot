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
struct BlockSyncSystem: System {
    // TODO: Alternative names: CanvasBlockSyncSystem
    nonisolated(unsafe) public static let dependencies: [SystemDependency] = [
        .after(BlockCreationSystem.self),
    ]
    public init() {}
    public func update(_ world: World) throws (InternalSystemError) {
        guard let frame = world.frame,
              let canvasComponent: CanvasComponent = world.singleton()
        else {
            return
        }

        let canvas = canvasComponent.canvas
        var remaining = Set(canvas.blocks.compactMap { $0.entityID })
        var updated: [DiagramCanvasBlock] = []
        
        for (id, component) in world.query(DiagramBlock.self) {
            sync(block: component, id: id, canvas: canvasComponent, world: world, frame: frame)
            remaining.remove(id)
        }
        
        for id in remaining {
            canvas.removeBlock(id)
        }
    }
    
    public func sync(block: DiagramBlock,
                     id entityID: EphemeralID,
                     canvas canvasComponent: CanvasComponent,
                     world: World,
                     frame: DesignFrame) {
        // FIXME: Require style (this is just a quick hack to make swatches work)
        let canvas = canvasComponent.canvas
        let style = canvas.style ?? CanvasStyle()

        let sceneNode: DiagramCanvasBlock
        if let node = canvas.block(id: entityID) {
            sceneNode = node
        }
        else {
            sceneNode = DiagramCanvasBlock()
            sceneNode.entityID = entityID
            canvas.insertBlock(sceneNode)
            
        }
        sceneNode._prepareChildren()
        sceneNode.name = StringName(DiagramBlockNamePrefix + world.godotStringName(entityID))

        if let objectID = world.entityToObject(entityID) {
            if let object = frame[objectID] {
                sceneNode.hasValueIndicator = object.type.hasTrait(.NumericIndicator)
            }
            else {
                sceneNode.hasValueIndicator = false
            }

            sceneNode.hasIssues = world.objectHasIssues(objectID)
        }


        let preview: BlockPreview? = world.component(for: entityID)

        updateContent(sceneNode, block: block, style: style)
        updatePosition(sceneNode, block: block, preview: preview)
        updateLabels(sceneNode, block: block, style: style)
        updateBlockColorSwatch(sceneNode, colorName: block.accentColorName, style: style)
        updateIndicators(sceneNode)
    }

    func updateContent(_ node: DiagramCanvasBlock,
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
