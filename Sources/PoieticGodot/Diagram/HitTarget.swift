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
    case handle = 4
}

@Godot
public class CanvasHitTarget: SwiftGodot.Object {
    @Export var object: Node?
    @Export var type: HitTargetType = .object
    
    required init(_ context: SwiftGodot.InitContext) {
        super.init(context)
    }
    
    convenience init(object: Node, type: HitTargetType) {
        self.init()
        self.object = object
        self.type = type
    }
}
