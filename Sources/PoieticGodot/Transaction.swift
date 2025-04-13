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
    func create_object(typeName: String, attributes: GDictionary) -> Int64? {
        guard let frame else {
            GD.pushError("Using transaction without a frame")
            return nil
        }
        
        guard let type = frame.design.metamodel.objectType(name: typeName) else {
            GD.pushError("Trying to create a node of unknown type '\(typeName)'")
            return nil
        }
        var lossyAttributes: [String:PoieticCore.Variant] = attributes.asLossyPoieticAttributes()
        let object = frame.create(type, attributes: lossyAttributes)
        
        return object.id.godotInt
    }

    @Callable
    func create_node(typeName: String, name: String?, attributes: GDictionary) -> Int64? {
        guard let frame else {
            GD.pushError("Using transaction without a frame")
            return nil
        }
        
        guard let type = frame.design.metamodel.objectType(name: typeName) else {
            GD.pushError("Trying to create a node of unknown type '\(typeName)'")
            return nil
        }

        var lossyAttributes: [String:PoieticCore.Variant] = attributes.asLossyPoieticAttributes()
        let object = frame.createNode(type, name: name, attributes: lossyAttributes)
        
        return object.id.godotInt
    }
    
    @Callable
    func create_edge(typeName: String, origin: Int64, target: Int64) -> Int64? {
        guard let frame else {
            GD.pushError("Using transaction without a frame")
            return nil
        }
        guard let originID = PoieticCore.ObjectID(origin) else {
            GD.pushError("Invalid origin ID")
            return nil
        }
        guard let targetID = PoieticCore.ObjectID(target) else {
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
        
        return object.id.godotInt
    }
    
    @Callable
    func remove_object(object_id: Int64) {
        guard let actual_id = PoieticCore.ObjectID(object_id) else {
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
    func set_attribute(object_id: Int64, attribute: String, value: SwiftGodot.Variant?) {
        guard let actual_id = PoieticCore.ObjectID(object_id) else {
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
    func set_numeric_attribute_from_string(object_id: Int64, attribute: String, stringValue: String) -> Bool {
        guard let actual_id = PoieticCore.ObjectID(object_id) else {
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
