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
    @Signal var simulationPlayerRestarted: SimpleSignal
    
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

    @Callable
    func restart() {
        currentStep = 0
        simulationPlayerRestarted.emit()
    }
    
    @Callable
    public func run() {
        self.isRunning = true
        simulationPlayerStarted.emit()
    }

    @Callable
    public func stop() {
        self.isRunning = false
        simulationPlayerStopped.emit()
    }

    @Callable
    override public func _process(delta: Double) {
        if isRunning {
            if timeToStep <= 0 {
                step()
                timeToStep = stepDuration
            }
            else {
                timeToStep -= delta
            }
        }
    }
    
    func step() {
        guard let result = result?.result  else {
            return
        }
        if currentStep >= result.count {
            if isLooping {
                currentStep = 0
            }
            else {
                stop()
                return
            }
        }
        simulationPlayerStep.emit()
        currentStep += 1
    }

    /// Get a numeric value of computed object with given ID.
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
