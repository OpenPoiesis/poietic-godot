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
        updateVisuals()
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
    
    override public func _ready() {
        updateVisuals()
    }
    
    @Callable(autoSnakeCase: true)
    func updateVisuals() {
        let theme = ThemeDB.getProjectTheme()
        if let color = theme?.getColor(name: SwiftGodot.StringName(SelectionOutlineColorKey),
                                       themeType: SwiftGodot.StringName(CanvasThemeType)) {
            self.outlineColor = color
        }
        else {
            var color = Color.azure
            color.alpha = 0.7
            self.outlineColor = color
        }

        if let color = theme?.getColor(name: SwiftGodot.StringName(SelectionFillColorKey),
                                       themeType: SwiftGodot.StringName(CanvasThemeType)) {
            self.fillColor = color
        }
        else {
            var color = Color.lightBlue
            color.alpha = 0.3
            self.fillColor = color
        }
        self.queueRedraw()
    }
}
