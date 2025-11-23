//
//  CanvasHandle.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 19/11/2025.
//

import PoieticCore
import SwiftGodot

@Godot
public class CanvasHandle: SwiftGodot.Node2D {
    /// ID of the owning object. If nil then it is owned by canvas.
    var runtimeIDs: RuntimeEntityID?
    /// Custom tag that specifies the handle if multiple handles are present within the canvas or
    /// within a canvas object.
    @Export var tag: Int?

    var shape: CircleShape2D
    
    @Export var size: Double = DefaultHandleSize {
        didSet {
            shape.radius = size / 2
        }
    }
    
    // TODO: Use theme
    @Export var color: Color = Color.indigo
    @Export var fillColor: Color = Color.blue
    @Export var lineWidth: Double = 2
    @Export var isFilled: Bool = true

    required init(_ context: SwiftGodot.InitContext) {
        shape = CircleShape2D()
        shape.radius = size / 2
        super.init(context)
        self.zIndex = DefaultHandleZIndex
    }
    
    public override func _draw() {
        if isFilled {
            self.drawCircle(position: .zero, radius: size/2, color: fillColor, filled: true)
        }
        self.drawCircle(position: .zero, radius: size/2, color: color, filled: false, width: lineWidth)
    }
    
    func containsPoint(globalPoint: SwiftGodot.Vector2) -> Bool {
        let localPoint = toLocal(globalPoint: globalPoint)
        return Geometry2D.isPointInCircle(point: localPoint,
                                          circlePosition: .zero,
                                          circleRadius: self.size / 2.0)
    }
}

