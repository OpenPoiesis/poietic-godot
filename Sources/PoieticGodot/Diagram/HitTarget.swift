//
//  PoieticHitTarget.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 27/08/2025.
//
import SwiftGodot

enum HitTargetType: Int, CaseIterable {
    /// Object itself was hit.
    case object = 0
    /// Primary label, usually a name, was hit.
    case primaryLabel = 1
    /// Secondary label, typically a formula, was hit.
    case secondaryLabel = 2
    case errorIndicator = 3
    /// Handle of an object was hit. Tag provides additional information.
    case handle = 4
}

@Godot
public class CanvasHitTarget: SwiftGodot.Object {
    @Export var object: Node2D?
    @Export var type: HitTargetType = .object
    /// Custom tag associated with hit target.
    ///
    /// For example, if the object is a connector. then the handle is a midpoint and
    /// the tag is the midpoint index.
    @Export var tag: Int?
    
    required init(_ context: SwiftGodot.InitContext) {
        super.init(context)
    }
    
    convenience init(object: DiagramCanvasObject, type: HitTargetType, tag: Int? = nil) {
        self.init()
        self.object = object
        self.type = type
        self.tag = tag
    }
    
    public var debugDescription: String {
        "hit_target(\(object), type: \(type), tag: \(tag))"
    }
}
