//
//  Pictogram2D.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 21/09/2025.
//

import SwiftGodot
import PoieticCore
import Diagramming

@Godot
class Pictogram2D: SwiftGodot.Node2D {
    @Export var curves: TypedArray<SwiftGodot.Curve2D?>
    @Export var boundingBox: Rect2 = Rect2()
    @Export var size: Vector2 = .zero
    @Export var color: SwiftGodot.Color = .white
    @Export var lineWidth: Double = 1.0

    
    required init(_ context: InitContext) {
        let theme = ThemeDB.getProjectTheme()
        self.curves = TypedArray()
        super.init(context)
    }
    
    func setPictogram(_ pictogram: Pictogram) {
        // FIXME: Do not translate. Currently we must. See also: DiagramCanvasBlock
        self.curves = TypedArray(pictogram.path.asGodotCurves())
        self.size = Vector2(pictogram.pathBoundingBox.size)
        self.boundingBox = Rect2(pictogram.pathBoundingBox)
    }
    
    public override func _draw() {
        for curve in self.curves {
            guard let curve else { continue }
            let points = curve.tessellate()
            self.drawPolyline(points: points, color: color, width: lineWidth)
        }
    }
}
