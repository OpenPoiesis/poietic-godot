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
    
    @Export var object_id: Int64? {
        get { object.map { $0.objectID.godotInt } }
        set { readOnlyAttributeError() }
    }

    @Export var object_name: String? {
        get { object?.name }
        set { readOnlyAttributeError() }
    }

    @Export var type_name: String? {
        get { object?.type.name }
        set { readOnlyAttributeError() }
    }
    
    @Export var origin: Int64? {
        get {
            guard let object, case let .edge(origin, _) = object.structure else {
                return nil
            }
            return origin.godotInt
        }
        set { readOnlyAttributeError() }
    }

    @Export var target: Int64? {
        get {
            guard let object, case let .edge(_, target) = object.structure else {
                return nil
            }
            return target.godotInt
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
