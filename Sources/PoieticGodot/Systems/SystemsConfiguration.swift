//
//  SystemsConfiguration.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 17/11/2025.
//

import PoieticCore
import PoieticFlows
import Diagramming

// FIXME: [REFACTORING] Rename to Phase

enum RuntimePhase {
    // Modeling

    /// Systems run when design changed.
    ///
    /// The systems in this phase are run when a design is loaded, or when a transaction is
    /// committed.
    case designChange

    /// Systems run during interactive editing such as selection movement or handle dragging.
    ///
    case interactivePreview
    case sceneUpdate
    
    // Simulation
    // Run when the simulation plan is ready or when an experiment is requested.
    // case simulationPrepare
    // Run on simulation step.
    // case simulationStep
    /// Systems run when simulation is finished.
    ///
    /// Example use-case:
    /// - Update value indicators
    /// - Update charts
    ///
    case simulationFinished

    /// Systems run when simulation is finished.
    ///
    /// Example use-case:
    /// - Update value indicators
    /// - Update time indicator
    ///
    case simulationPlayerStep
    
    var systems: [System.Type] {
        switch self {
        case .designChange:
            PoieticFlows.SimulationPresentationSystemGroup
            + [
                // From Diagramming
                BlockCreationSystem.self,
                TraitConnectorCreationSystem.self,
                ConnectorGeometrySystem.self,
                // Scene Update - systems from us - Poietic Godot
                BlockSyncSystem.self,
                ConnectorSyncSystem.self,
            ]
        case .interactivePreview:
            [
                // From Diagramming
                ConnectorGeometrySystem.self,
                // Scene Update - systems from us - Poietic Godot
                BlockSyncSystem.self,
                ConnectorSyncSystem.self,
            ]
        /// Refresh scene visuals.
        case .sceneUpdate:
            [
                BlockSyncSystem.self,
                ConnectorSyncSystem.self,
            ]
        case .simulationFinished:
            [
                SimulationObjectsResultsSystem.self,
                IndicatorRangeConfigurationSystem.self,
                IndicatorValueUpdateSystem.self,
            ]
        /// Run on each simulation player step, when player is running.
        case .simulationPlayerStep:
            [
                IndicatorValueUpdateSystem.self,
            ]
        }
    }
    
}

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
        PoieticFlows.SimulationPresentationSystemGroup
        + [
            // From Diagramming
            BlockCreationSystem.self,
            TraitConnectorCreationSystem.self,
            ConnectorGeometrySystem.self,
            // Populate canvas (Godot)
            BlockSyncSystem.self,
            ConnectorSyncSystem.self,
        ]

    // TODO: Update only dirty connectors
    nonisolated(unsafe) static let DraggingPreview: [System.Type] = [
        // From Diagramming
        ConnectorGeometrySystem.self,
        // From PoieticGodot
        BlockSyncSystem.self,
        ConnectorSyncSystem.self,
    ]
}
