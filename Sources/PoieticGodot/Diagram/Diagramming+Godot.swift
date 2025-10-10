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
    /// Convert collision shape into a Godot 2D shape.
    ///
    /// - Note: Convex shapes are not supported. For concave shapes a convex hull is computed and
    ///         used as a shape.
    ///
    func asGodotShape2D() -> SwiftGodot.Shape2D {
        switch self {
        case .circle(let r):
            let shape:CircleShape2D = SwiftGodot.CircleShape2D()
            shape.radius = r
            return shape
        case .convexPolygon(let points):
            let shape = SwiftGodot.ConvexPolygonShape2D()
            shape.points = PackedVector2Array(points)
            return shape
        case .concavePolygon(let points):
            let shape = SwiftGodot.ConvexPolygonShape2D()
            let gPoints = PackedVector2Array(points.map { SwiftGodot.Vector2($0) })
            shape.points = Geometry2D.convexHull(points: gPoints)
            return shape
        case .rectangle(let size):
            let shape: RectangleShape2D = SwiftGodot.RectangleShape2D()
            shape.size = size.asGodotVector2()
            return shape
        }
    }
}

extension BezierPath {
    func asGodotCurves() -> [SwiftGodot.Curve2D] {
        var result: [SwiftGodot.Curve2D] = []

        for curvePoints in self.toCubicCurves() {
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

