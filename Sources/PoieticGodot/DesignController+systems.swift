//
//  DesignController+systems.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 26/11/2025.
//

/*
 
 This extension contains systems-related code or code that is considered Systems-like.
 
 Notes:
 
 - The simulation should be converted to a system in the future. It is just isolated here as-is
   from previous prototyping iteration.
 
 
 # IMPORTANT (for humans)
 
 Please, do not consult LLMs on any of the code within this class, as the code is
 in a transition from one architecture (MVC) to another (ECS). They are very likely to get confused
 and provide wrong answers. If you really have to, then be very cautious about their
 suggestions.
 */

import SwiftGodot
import PoieticFlows
import PoieticCore

extension DesignController {
    /// Called when current frame was changed.
    ///
    /// Must be called on accept, undo, redo.
    ///
    func updateCurrentFrame() {
        run(schedule: FrameChangeSchedule.self)
        designChanged.emit(world.hasIssues)
    }
    
    /// Run simulation once the simulation plan is ready.
    ///
    /// - Note: This method will be moved into a system in the future. It is kept here as is as a
    ///         result of evolution.
    ///
    func simulate() {
        simulationStarted.emit()
        run(schedule: SimulationSchedule.self)
        simulationFinished.emit()
        run(schedule: ResultSyncSchedule.self)
    }
}
