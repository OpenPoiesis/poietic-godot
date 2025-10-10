//
//  Simulator.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 23/02/2025.
//

import SwiftGodot
import PoieticCore
import PoieticFlows

// FIXME: [PORTING] Review this
@Godot
class ResultPlayer: SwiftGodot.Node {
    @Signal var simulationPlayerStarted: SimpleSignal
    @Signal var simulationPlayerStopped: SimpleSignal
    @Signal var simulationPlayerStep: SimpleSignal
    
    @Export var result: PoieticResult?
    @Export var isRunning: Bool = false
    @Export var isLooping: Bool = true
    @Export var timeToStep: Double = 0
    @Export var stepDuration: Double = 0.1
    @Export var currentStep: Int = 0
    @Export var currentTime: Double? {
        get {
            guard let result = result?.result else { return nil }
            return result.initialTime + Double(currentStep) * result.timeDelta
        }
        set(value) {
            GD.pushError("Trying to set read-only attribute")
        }
    }

    /// Rewind the player to the first simulation step.
    @Callable(autoSnakeCase: true)
    func toFirstStep() {
        currentStep = 0
        simulationPlayerStep.emit()
    }
    
    /// Forward the player to the last simulation step.
    @Callable(autoSnakeCase: true)
    func toLastStep() {
        guard let result = result?.result  else { return }
        currentStep = result.count - 1
        simulationPlayerStep.emit()
    }

    @Callable
    public func run() {
        self.isRunning = true
        simulationPlayerStarted.emit()
    }

    @Callable
    public func stop() {
        guard isRunning else { return }
        self.isRunning = false
        simulationPlayerStopped.emit()
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
        guard let result = result?.result  else { return }
        let adjustedStep: Int
        if result.count == 0 {
            adjustedStep = 0
        }
        else {
            adjustedStep = min(max(step, 0), result.count - 1)
        }
        guard adjustedStep != currentStep else { return }
        currentStep = adjustedStep
        simulationPlayerStep.emit()
    }

    @Callable(autoSnakeCase: true)
    func toTime(_ time: Double) {
        guard let result = result?.result  else { return }
        let distance = time - result.initialTime
        let step = Int((distance / result.timeDelta).rounded())
        toStep(step)
    }

    @Callable(autoSnakeCase: true)
    func nextStep() {
        guard let result = result?.result  else { return }
        if currentStep >= result.count {
            guard isLooping else {
                stop()
                return
            }
            currentStep = 0
        }
        simulationPlayerStep.emit()
        currentStep += 1
    }

    @Callable(autoSnakeCase: true)
    func previousStep() {
        guard currentStep > 0 else { return }
        guard let result = result?.result  else { return }
        currentStep -= 1
        if currentStep <= 0 {
            guard isLooping else {
                currentStep = 0
                stop()
                return
            }
            currentStep = result.count - 1
        }
        simulationPlayerStep.emit()
    }

    /// Get a numeric value of computed object with given ID at the current step.
    @Callable(autoSnakeCase: true)
    public func numericValue(rawObjectID: EntityIDValue) -> Double? {
        let id = PoieticCore.ObjectID(rawValue: rawObjectID)
        guard let wrappedResult = result?.result,
              let plan = result?.plan else {
            return nil
        }
        guard let index = plan.variableIndex(of: id) else {
            GD.printErr("Can not get numeric value of unknown object ID \(id)")
            return nil
        }
        guard let state = wrappedResult[currentStep] else {
            GD.printErr("No current player state for step: \(currentStep)")
            return nil
        }
        
        return try? state[index].doubleValue()
    }
}
