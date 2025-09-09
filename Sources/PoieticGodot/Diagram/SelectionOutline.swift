//
//  SelectionOutline.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 09/09/2025.
//

import SwiftGodot

@Godot
public class SelectionOutline: SwiftGodot.Node2D {
    @Export var outline: Line2D
    @Export var polygon: Polygon2D

    required init(_ context: InitContext) {
        self.polygon = Polygon2D()
        self.outline = Line2D()
        super.init(context)
        self.addChild(node: self.polygon)
        self.addChild(node: self.outline)
        updateVisuals()
    }
    
    @Export var points: PackedVector2Array {
        set(value) {
            outline.points = value
            polygon.polygon = value
        }
        get {
            outline.points ?? PackedVector2Array()
        }
    }
    
    override public func _ready() {
        updateVisuals()
    }
    
    @Callable(autoSnakeCase: true)
    func updateVisuals() {
        self.outline.width = -1
        self.outline.jointMode = .round

        let theme = ThemeDB.getProjectTheme()
        if let color = theme?.getColor(name: SwiftGodot.StringName(SelectionOutlineColorKey),
                                       themeType: SwiftGodot.StringName(CanvasThemeType)) {
            self.outline.defaultColor = color
        }
        else {
            var color = Color.blue
            color.alpha = 0.7
            self.outline.defaultColor = color
        }

        if let color = theme?.getColor(name: SwiftGodot.StringName(SelectionFillColorKey),
                                       themeType: SwiftGodot.StringName(CanvasThemeType)) {
            self.polygon.color = color
        }
        else {
            var color = Color.lightBlue
            color.alpha = 0.3
            self.polygon.color = color
        }

    }
}
