//
//  PoieticCanvasObject.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 27/08/2025.
//
import SwiftGodot
import PoieticCore
import Diagramming

@Godot
public class DiagramCanvasObject: SwiftGodot.Node2D {
    var objectID: PoieticCore.ObjectID?
    /// Flag denoting whether the node requires update of visuals.
    ///
    /// See also: ``updateVisuals()``
    ///
    @Export var isDirty: Bool = true
    
    @Export var hasIssues: Bool = false {
        didSet {
            if let issueIndicator {
                issueIndicator.visible = hasIssues
            }
        }
    }
    
    @Export var issueIndicator: SwiftGodot.Node2D?
   
    // Selection
    @Export var selectionOutline: SelectionOutline?
    var _isSelected: Bool = false
    @Export var isSelected: Bool {
        get { _isSelected }
        set(flag) {
            _isSelected = flag
            selectionOutline?.visible = flag
        }
    }

    func update(from: ObjectSnapshot) {
        fatalError("Subclasses should override \(#function)")
    }
    
    // FIXME: make explicit that this uses global point
    @Callable(autoSnakeCase: true)
    open func containsTouch(globalPoint: SwiftGodot.Vector2) -> Bool {
        GD.printErr("Subclasses of canvas object must override containsTouch")
        return false
    }
    
    func getHandles() -> [CanvasHandle]{
        return []
    }
    
}

extension DiagramObject {
    func godotName(prefix: String) -> String {
        var name: String = prefix
        if let objectID {
            name += objectID.stringValue
        }
        if let tag {
            name += "-" + String(tag)
        }
        return name
    }
}

@Godot
public class CanvasHandle: SwiftGodot.Node2D {
    var shape: CircleShape2D
    var tag: Int?
    
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

