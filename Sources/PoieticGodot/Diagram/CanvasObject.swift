//
//  PoieticCanvasObject.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 27/08/2025.
//
import SwiftGodot
import PoieticCore

@Godot
public class PoieticCanvasObject: SwiftGodot.Node2D {
    var objectID: PoieticCore.ObjectID?
    @Export
    var hasIssues: Bool = false
    var issue_indicator: SwiftGodot.CanvasItem?
    
    func update(from: ObjectSnapshot) {
        fatalError("Subclasses should override \(#function)")
    }
    
    @Callable
    func contains_point(point: SwiftGodot.Vector2) -> Bool {
        GD.printErr("Subclasses of canvas object must override contains_point")
        return false
    }
    
    func getHandles() -> [PoieticCanvasHandle]{
        return []
    }
    
}

@Godot
public class PoieticCanvasHandle: SwiftGodot.Node2D {
    var shape: CircleShape2D
    var tag: Int?
    
    @Export var size: Double = DefaultHandleSize {
        didSet {
            shape.radius = size / 2
        }
    }
    
    @Export var color: Color = Color.gray
    @Export var fillColor: Color = Color.gray
    @Export var lineWidth: Double = 2
    @Export var isFilled: Bool = false

    required init(_ context: SwiftGodot.InitContext) {
        shape = CircleShape2D()
        shape.radius = size / 2
        super.init(context)
        self.zIndex = DefaultHandleZIndex
    }
    
    public override func _draw() {
        if isFilled {
            self.drawCircle(position: position, radius: size/2, color: fillColor, filled: true)
        }
        self.drawCircle(position: position, radius: size/2, color: color, filled: false, width: lineWidth)
    }
    
    func containsPoint(point: SwiftGodot.Vector2) -> Bool {
        return false
    }
}

@Godot
public class PoieticIssueIndicator: SwiftGodot.Node2D {
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
    
    @Callable
    func contains_point(_ point: SwiftGodot.Vector2) -> Bool {
        return self.position.distanceTo(point) <= Double(IssueIndicatorIconSize)
    }
}

