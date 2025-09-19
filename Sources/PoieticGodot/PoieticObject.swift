//
//  PoieticObject.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 13/04/2025.
//
import SwiftGodot
import PoieticFlows
import PoieticCore

/// Wrapper for the Design object.
///
@Godot
class PoieticObject: SwiftGodot.RefCounted {
    var object: ObjectSnapshot?
    
    @Export var objectID: PoieticCore.ObjectID? {
        get { object?.objectID }
        set { readOnlyAttributeError() }
    }

    @Export var objectName: String? {
        get { object?.name }
        set { readOnlyAttributeError() }
    }

    @Export var typeName: String? {
        get { object?.type.name }
        set { readOnlyAttributeError() }
    }
    
    @Export var origin: PoieticCore.ObjectID? {
        get {
            guard let object,
                  case let .edge(origin, _) = object.structure
            else {
                return nil
            }
            return origin
        }
        set { readOnlyAttributeError() }
    }

    @Export var target: PoieticCore.ObjectID? {
        get {
            guard let object,
                  case let .edge(_, target) = object.structure
            else {
                return nil
            }
            return target
        }
        set { readOnlyAttributeError() }
    }

    @Callable
    func get_traits() -> PackedStringArray {
        guard let type = object?.type else {
            return PackedStringArray()
        }
        return PackedStringArray(type.traits.map { String($0.name) })
    }
    
    @Callable
    func has_trait(trait_name: String) -> Bool {
        guard let type = object?.type else {
            return false
        }
        return type.hasTrait(trait_name)
    }

    @Callable
    func get_attribute(attribute: String) -> SwiftGodot.Variant? {
        guard let object else {
            GD.pushError("No object set")
            return nil
        }
        if let value = object[attribute] {
            return value.asGodotVariant()
        }
        else {
            return nil
        }
    }
    
    @Callable
    func get_attribute_keys() -> [String] {
        guard let object else { return [] }
        return object.type.attributeKeys
    }

    @Callable
    func get_position() -> SwiftGodot.Vector2? {
        guard let position = object?.position else {
            return nil
        }
        return position.asGodotVector2()
    }
}
