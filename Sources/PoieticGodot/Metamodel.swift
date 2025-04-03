//
//  Metamodel.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 23/02/2025.
//

import SwiftGodot
import PoieticCore

@Godot
public class PoieticMetamodel: SwiftGodot.Node {
    var metamodel: Metamodel! = nil
    
    @Callable
    public func has_type(typeName: String) -> Bool {
        return metamodel.types.contains { $0.name == typeName }
    }

    @Callable
    public func get_type_list() -> PackedStringArray {
        return PackedStringArray(metamodel.types.map { String($0.name) })
    }

    @Callable
    public func get_node_type_list() -> PackedStringArray {
        return PackedStringArray(metamodel.nodeTypes.map { String($0.name) })
    }

    @Callable
    public func get_edge_type_list() -> PackedStringArray {
        return PackedStringArray(metamodel.edgeTypes.map { String($0.name) })
    }

    @Callable
    public func get_type_list_with_trait(traitName: String) -> PackedStringArray {
        guard let trait = metamodel.trait(name: traitName) else {
            return PackedStringArray()
        }
        
        return PackedStringArray(
            metamodel.types.filter {
                $0.hasTrait(trait)
            }.map { String($0.name) }
        )
    }

    @Callable
    public func get_trait_list() -> PackedStringArray {
        return PackedStringArray(metamodel.traits.map { String($0.name) })
    }

    @Callable
    public func type_get_traits(typeName: String) -> PackedStringArray {
        guard let type = metamodel.objectType(name: typeName) else {
            return PackedStringArray()
        }
        return PackedStringArray(type.traits.map { String($0.name) })
    }
    
    @Callable
    public func type_has_trait(typeName: String, traitName: String) -> Bool {
        guard let type = metamodel.objectType(name: typeName) else {
            return false
        }
        guard let trait = metamodel.trait(name: traitName) else {
            return false
        }
        return type.hasTrait(trait)
    }
}
