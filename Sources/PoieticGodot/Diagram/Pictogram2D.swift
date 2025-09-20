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
    @Export var color: SwiftGodot.Color = .white
    @Export var lineWidth: Double = 1.0

    
    required init(_ context: InitContext) {
        let theme = ThemeDB.getProjectTheme()
        self.curves = TypedArray()
        super.init(context)
    }
    
    func setCurves(from pictogram: Pictogram) {
        // FIXME: Do not translate. Currently we must. See also: DiagramCanvasBlock
        let translation = AffineTransform(translation: -pictogram.origin)
        let translatedPath = pictogram.path.transform(translation)
        self.curves = TypedArray(translatedPath.asGodotCurves())
    }
    
    public override func _draw() {
        for curve in self.curves {
            guard let curve else { continue }
            let points = curve.tessellate()
            self.drawPolyline(points: points, color: color, width: lineWidth)
        }
    }
}
