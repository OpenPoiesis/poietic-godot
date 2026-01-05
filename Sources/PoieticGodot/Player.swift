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
    let systems: SystemGroup
    
    @Signal var simulationPlayerStarted: SimpleSignal
    @Signal var simulationPlayerStopped: SimpleSignal
    @Signal var simulationPlayerStep: SimpleSignal
    
    var runtime: AugmentedFrame?
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

    required override init(_ context: InitContext) {
        self.systems = SystemGroup(RuntimePhase.simulationReplayStep.systems)
        super.init(context)
    }
    
    func setRuntime(_ frame: AugmentedFrame) {
        self.runtime = frame
        if let result: SimulationResult = frame.component(for: .Frame) {
            self.initialTime = result.initialTime
            self.timeDelta = result.timeDelta
            self.lastStep = result.count - 1
            coordinate()
        }
    }
    
    /// Run the systems for player step and then notify Godot through a signal.
    ///
    func coordinate() {
        guard let runtime else { return }
        let component = ReplayTime(step: currentStep, time: currentTime)
        runtime.setComponent(component, for: .Frame)

        do {
            try systems.update(runtime)
        }
        catch {
            GD.pushError("Player step systems update failed:", error.localizedDescription)
            return
        }
        simulationPlayerStep.emit()
    }
    
    /// Rewind the player to the first simulation step.
    @Callable(autoSnakeCase: true)
    func toFirstStep() {
        currentStep = 0
        coordinate()
    }
    
    /// Forward the player to the last simulation step.
    @Callable(autoSnakeCase: true)
    func toLastStep() {
        currentStep = lastStep
        coordinate()
    }

    @Callable
    public func run() {
        self.isRunning = true
        coordinate()
    }

    @Callable
    public func stop() {
        guard isRunning else { return }
        self.isRunning = false
        coordinate()
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
        coordinate()
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
        coordinate()
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
        coordinate()
    }
}
