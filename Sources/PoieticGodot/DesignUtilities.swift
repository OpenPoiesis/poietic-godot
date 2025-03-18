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

/// Automatically connect parameters in a frame.
///
func autoConnectParameters(_ frame: TransientFrame) -> AutoConnectResult {
    let view = StockFlowView(frame)
    var added: [AutoConnectResult.ParameterInfo] = []
    var removed: [AutoConnectResult.ParameterInfo] = []
    var unknown: [String] = []
    
    let builtinNames: Set<String> = Set(BuiltinVariable.allCases.map {
        $0.name
    })

    let context = RuntimeContext(frame: frame)
    var formulaCompiler = FormulaCompilerSystem()
    formulaCompiler.update(context)

    for target in view.simulationNodes {
        guard let component: ParsedFormulaComponent = context.component(for: target.id) else {
            continue
        }
        let allNodeVars: Set<String> = Set(component.parsedFormula.allVariables)
        let required = Array(allNodeVars.subtracting(builtinNames))
        let resolved = view.resolveParameters(target.id, required: required)
        
        for name in resolved.missing {
            guard let paramNode = frame.object(named: name) else {
                unknown.append(name)
                continue
            }
            let edge = frame.createEdge(.Parameter, origin: paramNode.id, target: target.id)
            let info = AutoConnectResult.ParameterInfo(parameterName: name,
                                     parameterID: paramNode.id,
                                     targetName: target.name,
                                     targetID: target.id,
                                     edgeID: edge.id)
            added.append(info)
        }

        for edge in resolved.unused {
            let node = frame.object(edge.origin)
            frame.removeCascading(edge.id)
            
            let info = AutoConnectResult.ParameterInfo(parameterName: node.name,
                                     parameterID: node.id,
                                     targetName: target.name,
                                     targetID: target.id,
                                     edgeID: edge.id)
            removed.append(info)
        }
        
    }

    return AutoConnectResult(added: added, removed: removed, unknown: unknown)
}

struct ObjectDifference {
    let current: [PoieticCore.ObjectID]
    let added: [PoieticCore.ObjectID]
    
    // TODO: We do not need these, unless we mean "changed"
    let removed: [PoieticCore.ObjectID]
}

/// Get difference between expected list of objects and current list of objects.
///
/// Returns a structure containing three lists:
/// - `added`: Objects that are in current, not in expected.
/// - `removed`: Objects that are in expected, not in current.
/// - `current`: Objects that are bot in expected and current.
///
func difference(expected: [PoieticCore.ObjectID], current: [PoieticCore.ObjectID]) -> ObjectDifference {
    var added: [PoieticCore.ObjectID] = []
    var keep: [PoieticCore.ObjectID] = []

    var remaining = Set(expected)
    for id in current {
        if remaining.contains(id) {
            keep.append(id)
            remaining.remove(id)
        }
        else {
            added.append(id)
        }
    }

    return ObjectDifference(current: keep, added: added, removed: Array(remaining))
}
