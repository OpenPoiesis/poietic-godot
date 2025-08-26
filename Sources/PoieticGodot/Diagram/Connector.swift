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
public class PoieticConnector: PoieticCanvasObject {
    var connector: Diagramming.Connector?
    
    // TODO: Rename to open strokes
    var openCurves: [SwiftGodot.Curve2D]
    var filledCurves: [SwiftGodot.Curve2D]
    var fillColor: SwiftGodot.Color
    var lineColor: SwiftGodot.Color
    var lineWidth: Double = 1.0

    /**
     Need:
     - midpoints for handles and mid-indicator position
     - origin, target points for handle, indicators
     - connector style (arrow style)
     - line/shape style (colour, width, fill)
     - curves - for redrawing in different style
     */

    // FIXME: Implement this
    func getHandles() -> [Handle] {
        fatalError("\(#function) not implemented")
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

        let curves = connector.paths().flatMap { $0.asGodotCurves() }
        self.openCurves = curves
        self.filledCurves = []
        self.queueRedraw()
    }
}

