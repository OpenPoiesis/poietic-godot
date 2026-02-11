//
//  DesignController+actions.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 01/12/2025.
//

import SwiftGodot
import PoieticCore

/// Extension that contains actions dispatched by the ``Application``.
/// 
extension DesignController {
    /// Delete objects in current frame.
    ///
    func deleteObjects(_ ids: [PoieticCore.ObjectID]) {
        let trans = self.newTransaction()
        let existing = trans.existing(from: ids)
        for id in existing {
            guard trans.contains(id) else { continue }
            trans.removeCascading(id)
        }
        self.accept(trans)
    }
    func removeConnectorMidpoints(_ ids: [PoieticCore.ObjectID]) {
        let trans = self.newTransaction()
        let existing = trans.existing(from: ids)
        for id in existing {
            guard trans.contains(id) else { continue }
            let obj = trans.mutate(id)
            guard obj.type.hasTrait(.DiagramConnector) else { continue }
            obj.removeAttribute(forKey: "midpoints")
        }
        self.accept(trans)
    }
}
