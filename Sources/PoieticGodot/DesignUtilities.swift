//
//  DesignUtilities.swift
//
//
//  Created by Stefan Urbanek on 12/03/2024.
//

// FIXME: Shared with poietic-tool, move both to Flows

// INCUBATOR for design manipulation utilities.
//
// Most of the functionality is this file might be a candidate for inclusion
// in the Flows library.
//
// This file contains functionality that might be more complex, not always
// trivial manipulation of the frame.
//
// Once happy with the function/structure, consider moving to Flows or even Core
// library.
//

import SwiftGodot
import PoieticFlows
import PoieticCore

struct AutoConnectResult {
    public struct ParameterInfo {
        /// Name of the parameter
        let parameterName: String?
        /// ID of the parameter node
        let parameterID: PoieticCore.ObjectID
        /// Name of node using the parameter
        let targetName: String?
        /// ID of node using the parameter
        let targetID: PoieticCore.ObjectID
        /// ID of the edge from the parameter to the target
        let edgeID: PoieticCore.ObjectID
    }

    let added: [ParameterInfo]
    let removed: [ParameterInfo]
    let unknown: [String]
}

// FIXME: Sync with poietic-tool and actually make cleaner, shared in PoieticFlows
/// Automatically connect parameters in a frame.
///
func resolveParameters(objects: [ObjectSnapshot], view: StockFlowView) -> [PoieticCore.ObjectID:ResolvedParameters] {
    var result: [PoieticCore.ObjectID:ResolvedParameters] = [:]
    let builtinNames = Set(BuiltinVariable.allCases.map { $0.name })
    
    for object in objects {
        guard let formulaText = try? object["formula"]?.stringValue() else {
            continue
        }
        let parser = ExpressionParser(string: formulaText)
        guard let formula = try? parser.parse() else {
            continue
        }
        let variables: Set<String> = Set(formula.allVariables)
        let required = Array(variables.subtracting(builtinNames))
        let resolved = view.resolveParameters(object.objectID, required: required)
        result[object.objectID] = resolved
    }
    return result
}

/// Automatically connect parameters in a frame.
///
func autoConnectParameters(_ resolvedMap: [PoieticCore.ObjectID:ResolvedParameters], in frame: TransientFrame) {
    for (id, resolved) in resolvedMap {
        let object = frame[id]
        for name in resolved.missing {
            guard let paramNode = frame.object(named: name) else {
                continue
            }
            let edge = frame.createEdge(.Parameter, origin: paramNode.objectID, target: object.objectID)
        }

        for edge in resolved.unused {
            let node = frame.object(edge.origin)
            frame.removeCascading(edge.object.objectID)
        }
    }
}

struct ObjectDifference {
    let added: [PoieticCore.ObjectID]
    let removed: [PoieticCore.ObjectID]
}

/// Get difference between expected list of objects and current list of objects.
///
/// Returns a structure containing two lists:
/// - `added`: Objects that are in current, not in expected.
/// - `removed`: Objects that are in expected, not in current.
///
func difference(expected: [PoieticCore.ObjectID], current: [PoieticCore.ObjectID]) -> ObjectDifference {
    var added: [PoieticCore.ObjectID] = []
    var remaining = Set(expected)

    for id in current {
        if remaining.contains(id) {
            remaining.remove(id)
        }
        else {
            added.append(id)
        }
    }

    return ObjectDifference(added: added, removed: Array(remaining))
}

struct ObjectDifference2 {
    let added: [PoieticCore.ObjectID]
    let removed: [PoieticCore.ObjectID]
    let remaining: [PoieticCore.ObjectID]
}
func difference2(current: [PoieticCore.ObjectID], required: [PoieticCore.ObjectID])
-> ObjectDifference {
    var current = Set(current)
    var added: [PoieticCore.ObjectID] = []
    var remaining: [PoieticCore.ObjectID] = []

    for id in required {
        if current.contains(id) {
            current.remove(id)
            remaining.append(id)
        }
        else {
            added.append(id)
        }
    }

    return ObjectDifference(added: added, removed: Array(remaining))
}
