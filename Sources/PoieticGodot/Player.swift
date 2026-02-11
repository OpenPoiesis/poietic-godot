//
//  Simulator.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 23/02/2025.
//

import SwiftGodot
import PoieticCore
import PoieticFlows

struct ReplayTime: Component {
    let step: Int
    let time: Double
}

/// Object that controls recurrent updates of visuals from simulation results.
///
@Godot
class ResultPlayer: SwiftGodot.Node {
    @Signal var simulationPlayerStarted: SimpleSignal
    @Signal var simulationPlayerStopped: SimpleSignal
    @Signal var simulationPlayerStep: SimpleSignal
    
    var controller: DesignController?

    @Export var isRunning: Bool = false
    @Export var isLooping: Bool = true

    /// Initial simulation time.
    @Export var initialTime: Double = 0.0   // From result
    /// Time delta of simulation time.
    @Export var timeDelta: Double = 1.0     // From result
    /// Number of steps.
    @Export var lastStep: Int = 0           // From result
    
    /// Remaining real time to next step.
    @Export var timeToStep: Double = 0
    /// Real-time duration of a step in seconds.
    @Export var stepDuration: Double = 0.1
    
    /// Number of currently replayed simulation step.
    @Export var currentStep: Int = 0
    /// Current simulation time.
    @Export var currentTime: Double {
        get {
            return initialTime + Double(currentStep) * timeDelta
        }
        set(value) {
            GD.pushError("Trying to set read-only attribute")
        }
    }

    func setController(_ controller: DesignController) {
        self.controller = controller
        if let result: SimulationResult = controller.world.singleton() {
            self.initialTime = result.initialTime
            self.timeDelta = result.timeDelta
            self.lastStep = result.count - 1
            updateWorld()
        }
    }
    
    /// Run the systems for player step and then notify Godot through a signal.
    ///
    func updateWorld() {
        guard let controller else { return }
        let component = ReplayTime(step: currentStep, time: currentTime)
        controller.world.setSingleton(component)
        guard controller.run(schedule: ReplayStepSchedule.self) else { return }
        simulationPlayerStep.emit()
    }
    
    /// Rewind the player to the first simulation step.
    @Callable(autoSnakeCase: true)
    func toFirstStep() {
        currentStep = 0
        updateWorld()
    }
    
    /// Forward the player to the last simulation step.
    @Callable(autoSnakeCase: true)
    func toLastStep() {
        currentStep = lastStep
        updateWorld()
    }

    @Callable
    public func run() {
        self.isRunning = true
        updateWorld()
    }

    @Callable
    public func stop() {
        guard isRunning else { return }
        self.isRunning = false
        updateWorld()
    }
    
    @Callable
    override public func _process(delta: Double) {
        if isRunning {
            if timeToStep <= 0 {
                nextStep()
                timeToStep = stepDuration
            }
            else {
                timeToStep -= delta
            }
        }
    }
    
    @Callable(autoSnakeCase: true)
    func toStep(_ step: Int) {
        let adjustedStep: Int = min(max(step, 0), lastStep)
        guard adjustedStep != currentStep else { return }
        currentStep = adjustedStep
        updateWorld()
    }

    @Callable(autoSnakeCase: true)
    func toTime(_ time: Double) {
        let distance = time - initialTime
        let step = Int((distance / timeDelta).rounded())
        toStep(step)
    }

    @Callable(autoSnakeCase: true)
    func nextStep() {
        if currentStep > lastStep {
            guard isLooping else {
                stop()
                return
            }
            currentStep = 0
        }
        updateWorld()
        currentStep += 1
    }

    @Callable(autoSnakeCase: true)
    func previousStep() {
        guard currentStep > 0 else { return }
        currentStep -= 1
        if currentStep <= 0 {
            guard isLooping else {
                currentStep = 0
                stop()
                return
            }
            currentStep = lastStep
        }
        updateWorld()
    }
}
