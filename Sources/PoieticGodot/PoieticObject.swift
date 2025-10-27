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
    
    @Export var objectID: EntityIDValue? {
        get { object?.objectID.rawValue }
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
    
    @Export var label: String? {
        get { object?.label }
        set { readOnlyAttributeError() }
    }
    
    @Export var secondaryLabel: String? {
        get { object?.secondaryLabel }
        set { readOnlyAttributeError() }
    }

    @Export var origin: EntityIDValue? {
        get {
            guard let object,
                  case let .edge(origin, _) = object.structure
            else { return nil }
            return origin.rawValue
        }
        set { readOnlyAttributeError() }
    }

    @Export var target: EntityIDValue? {
        get {
            guard let object,
                  case let .edge(_, target) = object.structure
            else { return nil }
            return target.rawValue
        }
        set { readOnlyAttributeError() }
    }

    @Callable(autoSnakeCase: true)
    func getTraits() -> PackedStringArray {
        guard let type = object?.type else { return PackedStringArray() }
        return PackedStringArray(type.traits.map { String($0.name) })
    }
    
    @Callable(autoSnakeCase: true)
    func hasTrait(_ traitName: String) -> Bool {
        guard let type = object?.type else { return false }
        return type.hasTrait(traitName)
    }

    @Callable(autoSnakeCase: true)
    func getAttribute(_ attribute: String) -> SwiftGodot.Variant? {
        guard let object,
              let value = object[attribute] else { return nil }
        return value.asGodotVariant()
    }
    
    @Callable(autoSnakeCase: true)
    func getAttributeKeys() -> PackedStringArray {
        guard let type = object?.type else { return PackedStringArray() }
        return PackedStringArray(type.attributes.map {$0.name})
    }
}
