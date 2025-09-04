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
   
    var midpointHandles: [PoieticCanvasHandle] = []
    
    // TODO: Rename to open strokes
    var openCurves: [SwiftGodot.Curve2D]
    var filledCurves: [SwiftGodot.Curve2D]
    var fillColor: SwiftGodot.Color
    var lineColor: SwiftGodot.Color
    var lineWidth: Double = 1.0

    /**
     Need:
     - connector style (arrow style)
     - line/shape style (colour, width, fill)
     - curves - for redrawing in different style
     */

    // FIXME: Implement this
    @Callable
    override func getHandles() -> [PoieticCanvasHandle] {
        return midpointHandles
    }

    
    required init(_ context: InitContext) {
        self.openCurves = []
        self.filledCurves = []
        self.lineColor = SwiftGodot.Color(code: "green")
        self.fillColor = SwiftGodot.Color(code: "lime")
        self.fillColor.alpha = 0.5
        super.init(context)
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
        self.contentChanged()
    }
    func contentChanged() {
        guard let connector else { return }
        let curves = connector.paths().flatMap { $0.asGodotCurves() }
        self.openCurves = curves
        self.filledCurves = []
        self.queueRedraw()
        updateHandles()
    }
    
    func updateHandles() {
        guard let connector else {
            GD.pushError("Canvas connector has no diagram connector")
            return
        }
        let handle: PoieticCanvasHandle
        if midpointHandles.isEmpty {
            let segment = LineSegment(from: connector.originPoint, to: connector.targetPoint)
            // TODO: Store the -1 as constant
            handle = createMidpointHandle(tag: -1, position: segment.midpoint.asGodotVector2())
        }
        else {
            for index in 0..<connector.midpoints.count {
                let midpoint = connector.midpoints[index]
                let handle: PoieticCanvasHandle
                if index < midpointHandles.count {
                    handle = midpointHandles[index]
                    handle.tag = index
                    handle.position = midpoint.asGodotVector2()
                }
                else {
                    handle = createMidpointHandle(tag: index, position: midpoint.asGodotVector2())
                }
            }
            let remaining = midpointHandles.count - connector.midpoints.count
            for _ in 0..<remaining {
                guard let handle = midpointHandles.popLast() else {
                    break
                }
                handle.queueFree()
            }
            
            assert(!midpointHandles.isEmpty)
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
        self.contentChanged()
    }
    
    func createMidpointHandle(tag: Int, position: Vector2) -> PoieticCanvasHandle {
        let theme = ThemeDB.getProjectTheme()
        let handle = PoieticCanvasHandle()
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
}

