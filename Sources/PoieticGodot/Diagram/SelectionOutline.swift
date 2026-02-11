//
//  SelectionOutline.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 09/09/2025.
//

import SwiftGodot

@Godot
public class SelectionOutline: SwiftGodot.Node2D {
    var curves: TypedArray<Curve2D?> {
        didSet {
            self.queueRedraw()
        }
    }
    
    @Export var outlineColor: Color
    @Export var fillColor: Color
    @Export var lineWidth: Double = 1.0
    
    required init(_ context: InitContext) {
        self.curves = []
        self.outlineColor = Color.blue
        self.fillColor = Color.azure
        super.init(context)
    }

    public override func _draw() {
        for curve in self.curves {
            guard let curve else { continue }
            let points = curve.tessellate()
            // TODO: Investigate when this happens
            guard points.count >= 3 else { continue }

            self.drawPolygon(points: points, colors: [fillColor])
            self.drawPolyline(points: points, color: outlineColor, width: lineWidth)
        }
    }
}
