//
//  CanvasIssueIndicator.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 19/11/2025.
//

import SwiftGodot

@Godot
public class CanvasIssueIndicator: SwiftGodot.Node2D {
    @Export var icon: SwiftGodot.Sprite2D?

    @Callable
    public override func _ready() {
        guard self.icon == nil else {
            return
        }
        let icon = Sprite2D()
        icon.texture = GD.load(path: IssueIndicatorIcon)
        var iconSize = icon.texture?.getSize() ?? .zero
        let scale = IssueIndicatorIconSize / iconSize.x
        icon.scale = SwiftGodot.Vector2(x: scale, y: scale)
        icon.position += IssueIndicatorIconOffset.asGodotVector2()
        icon.zIndex = IssueIndicatorZIndex
        self.addChild(node: icon)
        self.icon = icon
    }
    
    func containsPoint(globalPoint: SwiftGodot.Vector2) -> Bool {
        let localPoint = toLocal(globalPoint: globalPoint)
        return Geometry2D.isPointInCircle(point: localPoint,
                                          circlePosition: .zero,
                                          circleRadius: Double(IssueIndicatorIconSize) / 2.0)
    }
}

