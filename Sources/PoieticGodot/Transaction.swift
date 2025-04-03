//
//  Transaction.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 03/03/2025.
//

import SwiftGodot
import PoieticCore

@Godot
class PoieticTransaction: SwiftGodot.Object {
    var frame: TransientFrame?
    
    func setFrame(_ frame: TransientFrame){
        self.frame = frame
    }
    
    @Callable
    func create_node(typeName: String, name: SwiftGodot.Variant?, attributes: GDictionary) -> SwiftGodot.Variant? {
        guard let frame else {
            GD.pushError("Using transaction without a frame")
            return nil
        }
        
        guard let type = frame.design.metamodel.objectType(name: typeName) else {
            GD.pushError("Trying to create a node of unknown type '\(typeName)'")
            return nil
        }
        let actualName: String?
        if let name {
            guard let name = String(name) else {
                GD.pushError("Expected string for name")
                return nil
            }
            actualName = name
        }
        else {
            actualName = nil
        }
        
        var lossyAttributes: [String:PoieticCore.Variant] = attributes.asLossyPoieticAttributes()
        let object = frame.createNode(type, name: actualName, attributes: lossyAttributes)
        
        return object.id.gdVariant
    }
    
    @Callable
    func create_edge(typeName: String, origin: Int64, target: Int64) -> SwiftGodot.Variant? {
        guard let frame else {
            GD.pushError("Using transaction without a frame")
            return nil
        }
        guard let originID = PoieticCore.ObjectID(String(origin)) else {
            GD.pushError("Invalid origin ID")
            return nil
        }
        guard let targetID = PoieticCore.ObjectID(String(target)) else {
            GD.pushError("Invalid target ID")
            return nil
        }
        
        guard let type = frame.design.metamodel.objectType(name: typeName) else {
            GD.pushError("Trying to create a node of unknown type '\(typeName)'")
            return nil
        }
        guard frame.contains(originID) else {
            GD.pushError("Unknown object ID \(origin)")
            return nil
        }
        guard frame.contains(targetID) else {
            GD.pushError("Unknown object ID \(target)")
            return nil
        }
        
        let object = frame.createEdge(type, origin: originID, target: targetID)
        
        return object.id.gdVariant
    }
    
    @Callable
    func remove_object(object_id: Int) {
        guard let actual_id = PoieticCore.ObjectID(String(object_id)) else {
            GD.pushError("Invalid object ID type")
            return
        }
        guard let frame, frame.contains(actual_id) else {
            GD.pushError("Unknown object ID \(object_id)")
            return
        }
        
        frame.removeCascading(actual_id)
    }
    
    @Callable
    func set_attribute(object_id: Int, attribute: String, value: SwiftGodot.Variant?) {
        // FIXME: Use INT type (change in other ObjectID(String...))
        guard let actual_id = PoieticCore.ObjectID(String(object_id)) else {
            GD.pushError("Invalid object ID type")
            return
        }
        guard let frame, frame.contains(actual_id) else {
            GD.pushError("Unknown object ID \(object_id)")
            return
        }
        let object = frame.mutate(actual_id)
        if let value {
            var variant = PoieticCore.Variant(value)
            object[attribute] = variant
        }
        else {
            object[attribute] = nil
        }
    }

    @Callable
    func set_numeric_attribute_from_string(object_id: Int, attribute: String, stringValue: String) -> Bool {
        // FIXME: Use INT type (change in other ObjectID(String...))
        guard let actual_id = PoieticCore.ObjectID(String(object_id)) else {
            GD.pushError("Invalid object ID type")
            return false
        }
        guard let frame, frame.contains(actual_id) else {
            GD.pushError("Unknown object ID \(object_id)")
            return false
        }
        var metamodel = frame.design.metamodel
        var original = frame[actual_id]
        guard let valueType = original.type.attribute(attribute)?.type else {
            return false
        }
        
        let object = frame.mutate(actual_id)
        let variant: PoieticCore.Variant
        
        switch valueType {
        case .int:
            if let number = Int(stringValue) {
                variant = PoieticCore.Variant(number)
            }
            else {
                return false
            }
        case .double:
            if let number = Double(stringValue) {
                variant = PoieticCore.Variant(number)
            }
            else {
                return false
            }
        default:
            return false
        }

        object[attribute] = variant
        return true
    }

}
