//
//  Utils.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 18/08/2025.
//


import SwiftGodot
import Diagramming

extension String {
    /// Returns `true` if the string is empty or contains only whitespaces.
    public var isVisuallyEmpty: Bool {
        self.isEmpty || self.allSatisfy { $0.isWhitespace }
    }
}

extension PackedVector2Array {
    public convenience init(_ points: [Vector2D]) {
        let gdPoints = points.map { $0.asGodotVector2() }
        self.init(gdPoints)
    }
}
