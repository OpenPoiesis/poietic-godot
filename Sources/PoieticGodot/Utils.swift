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
    
    public func toSnakeCase() -> String {
        guard !self.isEmpty else { return self }
        
        var result = ""
        
        for (index, char) in self.enumerated() {
            if char.isUppercase && index > 0 {
                result += "_"
            }
            result += char.lowercased()
        }
        return result
    }
}

extension PackedVector2Array {
    public convenience init(_ points: [Vector2D]) {
        let gdPoints = points.map { $0.asGodotVector2() }
        self.init(gdPoints)
    }
}

extension Vector2 {
    public init(_ vector2D: Vector2D) {
        self.init(x: Float(vector2D.x), y: Float(vector2D.y))
    }
}

extension Rect2 {
    public init(_ rect2D: Rect2D) {
        self.init(position: Vector2(rect2D.origin), size: Vector2(rect2D.size))
    }
}
