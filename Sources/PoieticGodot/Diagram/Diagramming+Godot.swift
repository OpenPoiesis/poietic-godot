//
//  Diagramming+Godot.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 18/08/2025.
//

import SwiftGodot
import Diagramming
import Foundation


extension Diagramming.ShapeType {
    func asGodotShape2D() -> SwiftGodot.Shape2D {
        switch self {
        case .circle(let r):
            let shape:CircleShape2D = SwiftGodot.CircleShape2D()
            shape.radius = r
            return shape
        case .polygon(let points):
            if Geometry.isConvex(polygon: points) {
                let shape = SwiftGodot.ConvexPolygonShape2D()
                shape.points = PackedVector2Array(points)
                return shape
            }
            else {
                let shape = SwiftGodot.ConcavePolygonShape2D()
                var result: [Vector2D] = []
                for segment in Geometry.toSegments(polygon: points) {
                    result.append(segment.start)
                    result.append(segment.end)
                }
                shape.segments = PackedVector2Array(result)
                return shape
            }
        case .rectangle(let size):
            let shape: RectangleShape2D = SwiftGodot.RectangleShape2D()
            shape.size = size.asGodotVector2()
            return shape
        }
    }
}

extension BezierPath {
    func asGodotCurves() -> [SwiftGodot.Curve2D] {
        let curves = godotCurves()
        var result: [SwiftGodot.Curve2D] = []
        for curvePoints in godotCurves() {
            let curve = SwiftGodot.Curve2D()
            for item in curvePoints {
                curve.addPoint(position: item.position.asGodotVector2(),
                               in: item.inControl.asGodotVector2(),
                               out: item.outControl.asGodotVector2())
            }
            result.append(curve)
        }
        return result
    }
}

