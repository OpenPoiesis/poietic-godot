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

import PoieticFlows
import PoieticCore

struct AutoConnectResult {
    public struct ParameterInfo {
        /// Name of the parameter
        let parameterName: String?
        /// ID of the parameter node
        let parameterID: ObjectID
        /// Name of node using the parameter
        let targetName: String?
        /// ID of node using the parameter
        let targetID: ObjectID
        /// ID of the edge from the parameter to the target
        let edgeID: ObjectID
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
