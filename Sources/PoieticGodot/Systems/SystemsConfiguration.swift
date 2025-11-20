//
//  SystemsConfiguration.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 17/11/2025.
//

import PoieticCore
import PoieticFlows
import Diagramming

// FIXME: The SystemConfiguration is incubated idea.

// Phases/events:
// - on design change
//      - prepare simulation plan
//      - prepare visuals
// - on selection move
//      - update geometry
// - on simulation done
// - on player step
enum SystemConfiguration {
    /// Systems being run on each system change
    nonisolated(unsafe) static let DesignChange =
        PoieticFlows.SimulationPresentationSystemGroup + [
            // From Diagramming
            BlockCreationSystem.self,
            TraitConnectorCreationSystem.self,
            ConnectorGeometrySystem.self,
            // Populate canvas (Godot)
            BlockSyncSystem.self,
            ConnectorSyncSystem.self,
        ]

    nonisolated(unsafe) static let DraggingPreview: [System.Type] = [
        // From Diagramming
        ConnectorGeometrySystem.self,
        // From PoieticGodot
        BlockSyncSystem.self,
    ]
}
