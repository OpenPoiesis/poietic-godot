//
//  DiagramConnector.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 18/08/2025.
//

import SwiftGodot
import Diagramming
import PoieticCore

class Handle {
    
}

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
    
    func updateContent(from connector: Connector) {
        self.objectID = connector.objectID
        self.connector = connector
        let tessellatedPath = connector.wirePath().tessellate()
        self.wire = PackedVector2Array(tessellatedPath.map { $0.asGodotVector2() })
        self.name = StringName(connector.godotName(prefix: DiagramConnectorNamePrefix))
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
        self.openCurves = curves
        self.filledCurves = []
        updateHandles()
        self.isDirty = false
        self.queueRedraw()
    }
    
    func updateHandles() {
        guard let connector else { return }
        
        guard !connector.midpoints.isEmpty else {
            let segment = LineSegment(from: connector.originPoint, to: connector.targetPoint)
            // TODO: Store the -1 as constant
            createMidpointHandle(tag: -1, position: segment.midpoint.asGodotVector2())
            return
        }
        var existingCount = midpointHandles.count
        
        for (index, midpoint) in connector.midpoints.enumerated() {
            if index < existingCount {
                let handle = midpointHandles[index]
                handle.tag = index
                handle.position = midpoint.asGodotVector2()
            }
            else {
                createMidpointHandle(tag: index, position: midpoint.asGodotVector2())
            }
        }
        let remaining = existingCount - connector.midpoints.count
        if remaining > 0 {
            for _ in 0..<remaining {
                guard let handle = midpointHandles.popLast() else { break }
                handle.queueFree()
            }
        }
    }
    
    @Callable(autoSnakeCase: true)
    func setMidpoint(index: Int, midpointPosition: Vector2) {
        guard let connector else {
            GD.pushError("Canvas connector has no diagram connector")
            return
        }

        if index == -1 {
            connector.midpoints = [Vector2D(midpointPosition)]
        }
        else {
            guard index < connector.midpoints.count else {
                GD.pushError("Trying to set out-of-bounds midpoint")
                return
            }
            connector.midpoints[index] = Vector2D(midpointPosition)
        }
        isDirty = true
    }
    
    @discardableResult
    func createMidpointHandle(tag: Int, position: Vector2) -> CanvasHandle {
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
        handle.tag = tag
        self.addChild(node: handle)
        handle.position = position
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

