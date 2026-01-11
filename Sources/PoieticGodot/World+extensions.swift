//
//  World.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 09/12/2025.
//

import PoieticCore
import SwiftGodot

extension World {
    /// Get a debug-friendly string from ID that can be used as a Godot node name.
    ///
    /// If the entity ID represents a design object then the name string will be `o` followed
    /// by persistent design object ID.
    /// If the entity ID is just any other ephemeral entity, then the string
    /// will be prefixed with `e` followed by the entity ID.
    func godotStringName(_ id: EphemeralID) -> String {
        if let objectID = self.entityToObject(id) {
            return "o" + objectID.stringValue
        }
        else {
            return "e" + id.description
        }
    }
}
