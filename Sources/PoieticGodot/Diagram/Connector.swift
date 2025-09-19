//
//  DiagramConnector.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 18/08/2025.
//

import SwiftGodot
import Diagramming
import PoieticCore

/// Tag of a handle representing the first midpoint if the connector has no midpoints.
let InitiatingMidpointHandleTag: Int = -1

@Godot
public class DiagramCanvasConnector: DiagramCanvasObject {
    var connector: Diagramming.Connector?
   
    var midpointHandles: [CanvasHandle] = []
   
    /// ID of the origin object if the origin represents a design object.
    ///
    /// It is recommended to set the ID for connectors that are used in interactive
    /// user interfaces.
    ///
    public var originID: PoieticCore.ObjectID?

    /// ID of the target object if the target represents a design object.
    ///
    /// It is recommended to set the ID for connectors that are used in interactive
    /// user interfaces.
    ///
    public var targetID: PoieticCore.ObjectID?

    // TODO: Rename to open strokes
    var openCurves: [SwiftGodot.Curve2D]
    var filledCurves: [SwiftGodot.Curve2D]
    @Export var fillColor: SwiftGodot.Color
    @Export var lineColor: SwiftGodot.Color
    @Export var lineWidth: Double = 1.0
    
    /// Connector's centre curve tessellated to a poly-line. Used for connector touch detection.
    ///
    @Export var wire: PackedVector2Array
    
    @Callable
    override func getHandles() -> [CanvasHandle] {
        return midpointHandles
    }
    
    required init(_ context: InitContext) {
        self.openCurves = []
        self.filledCurves = []
        self.lineColor = SwiftGodot.Color(code: "green")
        self.fillColor = SwiftGodot.Color(code: "lime")
        self.fillColor.alpha = 0.5
        self.wire = PackedVector2Array()
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
    
    public override func _draw() {
        for curve in self.openCurves {
            let points = curve.tessellate()
            self.drawPolyline(points: points, color: lineColor, width: lineWidth)
        }

        for curve in self.filledCurves {
            let points = curve.tessellate()
            self.drawPolygon(points: points, colors: [lineColor])
            // TODO: Close shape
            self.drawPolyline(points: points, color: lineColor, width: lineWidth)
        }
    }
    
    func _prepareChildren() {
        if self.selectionOutline == nil {
            let outline = SelectionOutline()
            outline.visible = self._isSelected
            self.selectionOutline = outline
            self.addChild(node: outline)
        }
    }
    
    // FIXME: [IMPORTANT] Move this to canvas controller.
    func updateContent(connector: Connector) {
        _prepareChildren()
        
        self.objectID = connector.objectID
        self.connector = connector
        let tessellatedPath = connector.wirePath().tessellate()
        self.wire = PackedVector2Array(tessellatedPath.map { $0.asGodotVector2() })
        self.name = StringName(connector.godotName(prefix: DiagramConnectorNamePrefix))

        self.fillColor = Color(code: connector.shapeStyle.fillColor)
        self.fillColor.alpha = DefaultFatConnectorFillAlpha
        self.lineColor = Color(code: connector.shapeStyle.lineColor)
        self.lineWidth = connector.shapeStyle.lineWidth
        
        self.updateVisuals()
    }
    
    /// Update the visual representation of the Godot node from underlying block data.
    ///
    /// Called on ``_process()`` when ``isDirty`` flag is set.
    ///
    @Callable(autoSnakeCase: true)
    public func updateVisuals() {
        guard let connector else { return }
        let curves = connector.paths().flatMap { $0.asGodotCurves() }
        switch connector.style {
        case .fat(let style):
            self.openCurves = []
            self.filledCurves = curves
        case .thin(let style):
            self.openCurves = curves
            self.filledCurves = []
        }
        updateSelectionOutline()
        updateHandles()
        self.isDirty = false
        self.queueRedraw()
    }
    
    public func updateSelectionOutline() {
        guard let connector,
              let selectionOutline else { return }
        let curves = connector.paths().flatMap {
            $0.inflated(by: SelectionMargin).asGodotCurves()
        }
        selectionOutline.curves = TypedArray(curves)
    }
    
    func updateHandles() {
        guard let connector else { return }
        
        let existingCount = midpointHandles.count
        let requiredCount = connector.midpoints.count
        let removeCount: Int
        
        if requiredCount == 0 {
            let segment = LineSegment(from: connector.originPoint, to: connector.targetPoint)
            let handle: CanvasHandle
            if existingCount == 0 {
                handle = createMidpointHandle()
                removeCount = 0
            }
            else {
                handle = midpointHandles[0]
                removeCount = existingCount - 1
            }
            
            // Connector node position is always (0.0, 0.0). Midpoints are absolute, within diagram
            // canvas. Diagram canvas coordinates are the same as connector node-relative
            // coordinates.
            handle.position = Vector2(segment.midpoint)
            handle.tag = 0
        }
        else { // requiredCount > 0
            for (index, midpoint) in connector.midpoints.enumerated() {
                let handle: CanvasHandle
                if index < existingCount {
                    handle = midpointHandles[index]
                }
                else {
                    handle = createMidpointHandle()
                }
                handle.tag = index
                handle.position = Vector2(midpoint)
            }
            removeCount = existingCount - requiredCount
        }

        if removeCount > 0 {
            GD.print("--- Removing \(removeCount) handles")
        }
        for _ in 0..<removeCount {
            let handle = midpointHandles.removeLast()
            handle.queueFree()
        }
    }
    
    @Callable(autoSnakeCase: true)
    func moveMidpoint(tag: Int, canvasDelta: Vector2) {
        guard let connector else {
            GD.pushError("Canvas connector has no diagram connector")
            return
        }
        guard tag >= 0 && tag < midpointHandles.count else {
            GD.pushError("Invalid midpoint handle tag \(tag)")
            return
        }
        let handle = midpointHandles[tag]
        let newPosition = handle.position + canvasDelta
        
        if tag == 0 {
            let midpoint = Vector2D(handle.position + canvasDelta)
            connector.midpoints = [Vector2D(newPosition)]
        }
        else if tag > 0 && tag < connector.midpoints.count {
            connector.midpoints[tag] = Vector2D(newPosition)
        }
        else {
            GD.pushError("Trying to set out-of-bounds midpoint")
        }
        isDirty = true
    }

    @Callable(autoSnakeCase: true)
    func setMidpoint(tag: Int, canvasPosition: Vector2) {
        guard let connector else { return }
        guard tag >= 0 && tag < midpointHandles.count else { return }
        let handle = midpointHandles[tag]
        
        if tag == 0 {
            connector.midpoints = [Vector2D(canvasPosition)]
        }
        else if tag > 0 && tag < connector.midpoints.count {
            connector.midpoints[tag] = Vector2D(canvasPosition)
        }
        isDirty = true
    }

    func handle(withTag tag: Int) -> CanvasHandle? {
        return midpointHandles.first { $0.tag == tag }
    }

    func createMidpointHandle() -> CanvasHandle {
        let theme = ThemeDB.getProjectTheme()
        let handle = CanvasHandle()
        if let color = theme?.getColor(name: SwiftGodot.StringName(MidpointHandleFillColorKey), themeType: StringName(CanvasThemeType)) {
            handle.fillColor = color
        }
        else {
            handle.fillColor = Color.royalBlue
        }
        if let color = theme?.getColor(name: SwiftGodot.StringName(MidpointHandleOutlineColorKey), themeType: StringName(CanvasThemeType)) {
            handle.color = color
        }
        else {
            handle.color = Color.dodgerBlue
        }
        self.addChild(node: handle)
        midpointHandles.append(handle)
        return handle
    }
    
    override public func containsTouch(globalPoint: SwiftGodot.Vector2) -> Bool {
        guard wire.count >= 2 else { return false }
        let touchPoint = toLocal(globalPoint: globalPoint)
        
        for i in 0..<(wire.count-1) {
            let a = wire[i]
            let b = wire[i + 1]
            let pos = Geometry2D.segmentIntersectsCircle(segmentFrom: a,
                                                         segmentTo: b,
                                                         circlePosition: touchPoint,
                                                         circleRadius: TouchShapeRadius)
            // [Godot doc] If the segment does not intersect the circle, -1 is returned
            if pos != -1 {
                return true
            }
        }
        return false
    }
}

