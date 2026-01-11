//
//  PoieticCanvasObject.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 27/08/2025.
//
import SwiftGodot
import PoieticCore
import Diagramming

extension RuntimeEntityID {
    /// Runtime entity as a Godot node name suffix. Caller is expected to prefix the ID with
    /// appropriate object type.
    ///
    /// Object ID is just string value of the ID. Ephemeral ID has suffix "e" added to the string
    /// value of the ID.
    public var godotNodeName: String {
        switch self {
        case .object(let id): id.stringValue
        case .ephemeral(let id): id.description + "e"
        }
    }
}

protocol GodotConvertibleComponent {
    func asGodotDictionary() -> TypedDictionary<String, SwiftGodot.Variant?>
}

@Godot
public class DiagramCanvasObject: SwiftGodot.Node2D {
    var entityID: EphemeralID?
//    var objectID: PoieticCore.ObjectID? {
//        get { runtimeID?.objectID }
//        set(value) {
//            if let value {
//                runtimeID = .object(value)
//            }
//            else {
//                runtimeID = nil
//            }
//        }
//    }
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

    /// Flag whether touch detection is ignored.
    ///
    /// Use this for non-selectable shadows, dragged items or other decorative diagram visuals.
    ///
    @Export var ignoreAsTarget: Bool = false

    func update(from: ObjectSnapshot) {
        fatalError("Subclasses should override \(#function)")
    }
    
    func handle(tag: Int) -> CanvasHandle? {
        for child in self.findChildren(pattern: "*", type: "CanvasHandle") {
            guard let child = child as? CanvasHandle else { continue }
            if child.tag == tag {
                return child
            }
        }
        return nil
    }
    
    // FIXME: make explicit that this uses global point
    @Callable(autoSnakeCase: true)
    open func containsTouch(globalPoint: SwiftGodot.Vector2) -> Bool {
        GD.printErr("Subclasses of canvas object must override containsTouch")
        return false
    }
}

