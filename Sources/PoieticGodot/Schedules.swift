//
//  Schedules.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 05/01/2026.
//

import PoieticCore
import PoieticFlows
import Diagramming
import SwiftGodot

// Inherited schedules:
// - FrameChangeSchedule
// - SimulationSchedule

/// Synchronise world with Godot scene
enum SceneSyncSchedule: ScheduleLabel { }

/// Synchronise result visualisation.
enum ResultSyncSchedule: ScheduleLabel { }

/// Result player step update.
enum ReplayStepSchedule: ScheduleLabel { }
enum UpdateVisualsSchedule: ScheduleLabel { }

/// Systems run during interactive editing such as selection movement or handle dragging.
///
enum InteractivePreviewSchedule: ScheduleLabel { }

// Action-specific schedules
enum ParameterResolutionSchedule: ScheduleLabel { }
enum DiagramExportSchedule: ScheduleLabel { }

let UpdateVisualsSystems: [System.Type] = [
    // From Diagramming
    BlockCreationSystem.self,
    TraitConnectorCreationSystem.self,
    ConnectorGeometrySystem.self,
    // Scene Update - systems from us - Poietic Godot
    BlockSyncSystem.self,
    ConnectorSyncSystem.self,
]
extension World {
    // FIXME: Add "queueSchedule" to be run on next Godot _update()
    // FIXME: Make this default
    func addSchedule(label: ScheduleLabel.Type, systems: [System.Type]) {
        self.setSystems(schedule: label, systems: SystemGroup(systems))
    }
}
extension DesignController {
    
    func setupSchedules() {
        world.addSchedule(
            label: FrameChangeSchedule.self,
            systems:
                PoieticFlows.SimulationPlanningSystems
                + PoieticFlows.SimulationPresentationSystems
                + [
                    // From Diagramming
                    BlockCreationSystem.self,
                    TraitConnectorCreationSystem.self,
                    ConnectorGeometrySystem.self,
                    // Scene Update - systems from us - Poietic Godot
                    BlockSyncSystem.self,
                    ConnectorSyncSystem.self,
                ]
        )
        world.addSchedule(
            label: UpdateVisualsSchedule.self,
            systems: [
                    // From Diagramming
                    BlockCreationSystem.self,
                    TraitConnectorCreationSystem.self,
                    ConnectorGeometrySystem.self,
                    // Scene Update - systems from us - Poietic Godot
                    BlockSyncSystem.self,
                    ConnectorSyncSystem.self,
                ]
        )

        world.addSchedule(
            label: SceneSyncSchedule.self,
            systems: [
                BlockSyncSystem.self,
                ConnectorSyncSystem.self,
            ]
        )

        world.addSchedule(
            label: InteractivePreviewSchedule.self,
            systems: [
                // From Diagramming
                ConnectorGeometrySystem.self,
                // Scene Update - systems from us - Poietic Godot
                BlockSyncSystem.self,
                ConnectorSyncSystem.self,
            ]
        )

        world.addSchedule(
            label: SimulationSchedule.self,
            systems: PoieticFlows.SimulationRunningSystems
        )
        
        world.addSchedule(
            label: ResultSyncSchedule.self,
            systems: [
                SimulationObjectsResultsSystem.self,
                IndicatorRangeConfigurationSystem.self,
                IndicatorValueUpdateSystem.self,
            ]
        )

        world.addSchedule(
            label: ReplayStepSchedule.self,
            systems: [
                IndicatorValueUpdateSystem.self,
            ]
        )
        
        world.addSchedule(
            label: DiagramExportSchedule.self,
            systems: [
                BlockCreationSystem.self,
                TraitConnectorCreationSystem.self,
                ConnectorGeometrySystem.self
            ]
        )

        world.addSchedule(
            label: ParameterResolutionSchedule.self,
            systems: [
                ComputationOrderSystem.self,
                NameResolutionSystem.self,
                ExpressionParserSystem.self,
                ParameterResolutionSystem.self,
                ParameterConnectionProposalSystem.self,
            ]
        )
    }
    
    /// Convenience runner of a schedule that handles errors and displays an error panel through
    /// the application.
    ///
    /// World runs a given schedule. If an error occurs then it is displayed to the user through
    /// the application.
    ///
    /// - Returns: `true` on successful run, `false` on error.
    ///
    func run(schedule: ScheduleLabel.Type) -> Bool {
        let label = String(describing: schedule)
        GD.print("Running schedule: \(label)")
        do {
            try self.world.run(schedule: schedule)
        }
        catch {
            GD.pushError("Internal system error:", String(describing: error))
            self.application?.commandFailed.emit(label, error.localizedDescription, SwiftGodot.VariantDictionary())
            return false
        }
        return true
    }
}
