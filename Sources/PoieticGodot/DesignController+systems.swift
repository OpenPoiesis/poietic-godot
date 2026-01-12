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
    func updateSystems(debugReason: String) {
        guard let currentFrame = design.currentFrame else { return }
        let runtimeFrame = AugmentedFrame(currentFrame)
        self.runtimeFrame = runtimeFrame
        
        // 1. Augment the frame with some well-known objects and components
        //
        prepareForUpdate()
        
        // 2. Run the system group
        //
        do {
            GD.print("=== Running systems update: \(debugReason)")
            try designChangeSystems.updateWithGodotDebug(runtimeFrame)
        }
        catch {
            GD.pushError("Internal system error:", String(describing: error))
            self.application?.commandFailed.emit("design-change", error.localizedDescription, SwiftGodot.VariantDictionary())
            // Let us not return here but try to continue. Systems are unlikely to modify
            // user design or anything related to the persisted objects.
            // We might re-consider this if the user experience will be really bad.
        }
        
        // 3. Notify
        //
        designChanged.emit(runtimeFrame.hasIssues)
    }
    
    /// Prepare the runtime frame for systems update.
    ///
    /// Augment the frame with well-known objects and components, such as:
    ///
    /// - notation (see ``PoieticCore/Notation``)
    /// - diagram canvas (see ``CanvasComponent``)
    ///
    func prepareForUpdate() {
        guard let runtimeFrame else { return }
        
        if let notation {
            runtimeFrame.setComponent(notation, for: .Frame)
        }
        if let canvas {
            // TODO: Allow multiple canvases.
            let component = CanvasComponent(canvas: canvas)
            runtimeFrame.setComponent(component, for: .Frame)
        }
    }

    
    /// Run simulation once the simulation plan is ready.
    ///
    /// - Note: This method will be moved into a system in the future. It is kept here as is as a
    ///         result of evolution.
    ///
    func simulate() {
        // TODO: Change to a system
        guard let runtimeFrame,
              let simulationPlan: SimulationPlan = runtimeFrame.component(for: .Frame)
        else {
            return
        }
        
        // 1. Clean-up
        //
        runtimeFrame.removeComponent(SimulationResult.self, for: .Frame)

        // 2. Prepare simulator
        //
        let simulation = StockFlowSimulation(simulationPlan)
        let simulator = Simulator(simulation: simulation,
                                  parameters: simulationPlan.simulationParameters)
        
        simulationStarted.emit()
        
        // 3. Initialise
        //
        do {
            try simulator.initializeState()
        }
        catch {
            GD.pushError("Simulation initialisation failed: \(error)")
            simulationFailed.emit()
            self.application?.commandFailed.emit("simulation-init", error.localizedDescription, SwiftGodot.VariantDictionary())
            return
        }
        
        // 4. Run
        //
        do {
            try simulator.run()
        }
        catch {
            GD.pushError("Simulation failed at step \(simulator.currentStep): \(error)")
            simulationFailed.emit()
            self.application?.commandFailed.emit("simulation", error.localizedDescription, SwiftGodot.VariantDictionary())
            return
        }
        
        // 5. Populate runtime
        //
        runtimeFrame.setComponent(simulator.result, for: .Frame)

        // 6. Run the follow-up systems
        //
        do {
            GD.print("Running after-simulation systems.")
            try simulationFinishedSystems.updateWithGodotDebug(runtimeFrame)
        }
        catch {
            GD.pushError("Internal system error:", String(describing: error))
            self.application?.commandFailed.emit("simulation", error.localizedDescription, SwiftGodot.VariantDictionary())
            return
        }

    }
   
    /// Run after simulation was successfully finished and before signal was emitted.
    ///
    /// Add simulation result to the runtime frame.
    ///
    func finaliseSimulation() {
        guard let runtimeFrame else { return }
        // TODO: Run simulationFinished
    }

    /// Called on interactive preview (dragging), usually by a ``CanvasTool``.
    ///
    func updatePreviewSystems() {
        guard let runtimeFrame else { return }
        
        do {
            GD.print("=== Running preview update")
            try interactivePreviewSystems.updateWithGodotDebug(runtimeFrame)
        }
        catch {
            GD.pushError("Internal system error:", String(describing: error))
            // No alert here, just in case something is really messed up. We do not want to flood.
            //
            // Let us not return here but try to continue. Systems are unlikely to modify
            // user design or anything related to the persisted objects.
            // We might re-consider this if the user experience will be really bad.
        }
    }
}

extension SystemGroup {
    public func updateWithGodotDebug(_ frame: AugmentedFrame) throws (InternalSystemError) {
        try debugUpdate(frame) { (system, frame) in
            let name = String(describing: type(of: system))
            GD.print("--> Updating system ", name)
            return
        } after: { (system, frame) in
            let name = String(describing: type(of: system))
            // GD.print("    Done updating system ", name)
            return
        }
    }
}
