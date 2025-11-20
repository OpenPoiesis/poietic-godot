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
    var midpointHandles: [CanvasHandle] = []
    // TODO: Rename to open strokes
    var openCurves: [SwiftGodot.Curve2D]
    var filledCurves: [SwiftGodot.Curve2D]

    @Export var fillColor: SwiftGodot.Color
    @Export var lineColor: SwiftGodot.Color
    @Export var lineWidth: Double = 1.0
    
    /// Connector's centre curve tessellated to a poly-line. Used for connector touch detection.
    ///
    @Export var wire: PackedVector2Array
    
    required init(_ context: InitContext) {
        self.openCurves = []
        self.filledCurves = []
        self.lineColor = SwiftGodot.Color(code: "green")
        self.fillColor = SwiftGodot.Color(code: "lime")
        self.fillColor.alpha = 0.5
        self.wire = PackedVector2Array()
        super.init(context)
    }
    
    public override func _draw() {
        for curve in self.openCurves {
            let points = curve.tessellate()
            self.drawPolyline(points: points, color: lineColor, width: lineWidth)
        }

        for curve in self.filledCurves {
            let points = curve.tessellate()
            // TODO: Investigate when this happens
            guard points.count >= 3 else { continue }
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
    
    func _coalescedColor(_ name: String, default defaultColor: Color = .white) -> Color {
        Color.fromString(str: name, default: defaultColor)
    }
   
#if false
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
#endif
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

