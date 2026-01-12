//
//  CanvasController.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 26/08/2025.
//

import SwiftGodot
import PoieticCore
import PoieticFlows
import Diagramming
import Foundation

// FIXME: [REFACTORING] Deprecated. Dissolve into canvas and other classes.

/// Canvas Controller synchronises design with canvas.
///
/// Responsibilities:
///
/// - Synchronisation of design with canvas: create and update canvas objects, their visuals based
///   on state of the design.
/// - Creates and manages temporary visuals, such as new connectors.
/// - Facilitates inline editing.
/// - (TODO) Manages selection
///
@available(*, deprecated, message: "DO NOT USE, use runtime frame and friends")
@Godot
public class CanvasController: SwiftGodot.Node {
    // TODO: Move selection management here
    /// Canvas scene node that the controller manages and synchronises diagrammatic representation
    /// of a design.
    @Export public var canvas: DiagramCanvas?
    /// Controller of a design that is composed as a diagram on canvas.
    @Export public var designController: DesignController?
    
    @Callable
    func initialize(designController: DesignController, canvas: DiagramCanvas) {
        self.designController = designController
        self.canvas = canvas
    }
    
   // MARK: - Value Indicators
    // Remove values from indicators
    //
    // This method is called when design fails validation or when the simulation fails.
    //
    @Callable(autoSnakeCase: true)
    func clearIndicators() {
        // FIXME: [PORTING] Requires attention after porting from Godot
        guard let canvas else { return }
        for block in canvas.blocks {
            guard let id = block.objectID else { continue }
            block.displayValue = nil
        }
    }

    @Callable(autoSnakeCase: true)
    func commitNameEdit(rawObjectID: EntityIDValue, newValue: String) {
        let objectID = PoieticCore.ObjectID(rawValue: rawObjectID)
        guard let ctrl = designController,
              let canvas,
              // FIXME: [REFACTORING] This is too long
              let block = canvas.block(id: .object(ObjectID(rawValue: rawObjectID)))
        else { return }
        
        block.finishLabelEdit()
#warning("REFACTORING: Implement this!")
        #if false
        guard block.label != newValue else { return } // Nothing changed
        
        var trans = ctrl.newTransaction()
        var obj = trans.mutate(objectID)
        obj["name"] = PoieticCore.Variant(newValue)
        ctrl.accept(trans)
        #endif
    }
    
    @Callable(autoSnakeCase: true)
    func cancelNameEdit(rawObjectID: EntityIDValue) {
        let objectID = PoieticCore.ObjectID(rawValue: rawObjectID)
        guard let canvas,
              // FIXME: [REFACTORING] This is too long
              let block = canvas.block(id: .object(ObjectID(rawValue: rawObjectID)))
        else { return }
#warning("REFACTORING: Implement this!")
        block.finishLabelEdit()
    }
    
    @Callable(autoSnakeCase: true)
    func commitFormulaEdit(rawObjectID: EntityIDValue, newFormulaText: String) {
        let objectID = PoieticCore.ObjectID(rawValue: rawObjectID)
        guard let ctrl = designController,
              let object = ctrl.object(objectID) else { return }
        
        if (object["formula"] as? String) == newFormulaText {
            return // Attribute not changed
        }
        
        var trans = ctrl.newTransaction()
        var obj = trans.mutate(objectID)
        obj["formula"] = PoieticCore.Variant(newFormulaText)
        ctrl.accept(trans)
    }
   
    @Callable(autoSnakeCase: true)
    func commitGraphicalCurvesEdit(rawObjectID: EntityIDValue, points: PackedVector2Array, interpolationMethod: String) {
        let objectID = PoieticCore.ObjectID(rawValue: rawObjectID)
        guard let ctrl = designController,
              let object = ctrl.object(objectID) else { return }
        let convertedPoints = points.map { Point($0) }
        
        if (object["graphical_function_points"] as? [Point]) == convertedPoints
            && object["interpolation_method"] == interpolationMethod
        {
            return // Attribute not changed
        }
        
        var trans = ctrl.newTransaction()
        var obj = trans.mutate(objectID)
        obj["graphical_function_points"] = PoieticCore.Variant(convertedPoints)
        obj["interpolation_method"] = PoieticCore.Variant(interpolationMethod)
        ctrl.accept(trans)
    }

    @Callable(autoSnakeCase: true)
    func commitNumericAttributeEdit(rawObjectID: EntityIDValue, attribute: String, newTextValue: String) {
        let objectID = PoieticCore.ObjectID(rawValue: rawObjectID)
        guard let ctrl = designController,
              let object = ctrl.object(objectID) else { return }
        
        if let value = object[attribute], (try? value.stringValue()) == newTextValue
        {
            return // Attribute not changed
        }
        
        var trans = ctrl.newTransaction()
        var obj = trans.mutate(objectID)
        if obj.setNumericAttribute(attribute, fromString: newTextValue) {
            ctrl.accept(trans)
        }
        else {
            GD.pushWarning("Numeric attribute '",attribute,"' was not set: '", newTextValue, "'")
            ctrl.discard(trans)
        }
    }
    
    // MARK: - Pictogram UI Support
    //
    
}
