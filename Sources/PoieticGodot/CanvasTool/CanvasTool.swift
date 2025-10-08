//
//  CanvasTool.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 28/08/2025.
//

import SwiftGodot

// TODO: Implement "tool locking": When tool is clicked/selected twice, it is locked. Otherwise it returns to selection tool.

/// Abstract class for tools operating on diagram canvas.
///
@Godot
class CanvasTool: SwiftGodot.Node {
    @Export var canvas: DiagramCanvas?
    @Export var canvasController: CanvasController?
    @Export var designController: DesignController?
    /// Auxiliary palette that provides selection of tool items
    /// such as placeable objects or possible connectors.
//    @Export var palette: GridContainer?
    
    
    /// Identifier of an item, selected in palette, to be placed.
    @Export var paletteItemIdentifier: String? {
        didSet { paletteItemChanged(paletteItemIdentifier) }
    }

    /// Bind the tool to a diagram controller.
    @Callable
    func bind(_ canvasController: CanvasController) {
        self.canvasController = canvasController
        self.canvas = canvasController.canvas
        self.designController = canvasController.designController
        
        // FIXME: Missing object palette
    }
    
    @Callable
    func toolName() -> String { "default" }
    
    var application: PoieticApplication? {
        var parent: Node? = self.getParent()
        while parent != nil {
            if let app = parent as? PoieticApplication {
                return app
            }
            parent = parent?.getParent()
        }
        return nil
    }
    
    /// Name of an object palette to be used with the tool.
    ///
    /// If the tool has multiple options, such as different kinds of connections or
    /// objects to be placed, then the palette provides a way to select the option.
    ///
    @Callable(autoSnakeCase: true)
    func paletteName() -> String? { nil }
    
    /// Called when a palette object is selected.
    ///
    @Callable
    func paletteItemChanged(_ identifier: String?) {
        // Let the tools handle this.
    }
    
    @Callable
    open func handleInput(event: InputEvent) -> Bool {
        guard let canvas else { return false }
        
        var isConsumed: Bool = false
        switch event {
        case let event as InputEventMouseButton:
            if event.isPressed() {
                isConsumed = inputBegan(event: event, globalPosition: event.globalPosition)
            }
            else if event.isReleased() {
                isConsumed = inputEnded(event: event, globalPosition: event.globalPosition)
            }
        case let event as InputEventMouseMotion:
            if event.buttonMask == .left {
                isConsumed = inputMoved(event: event, globalPosition: event.globalPosition)
            }
            else {
                isConsumed = inputHover(event: event, globalPosition: event.globalPosition)
            }
        default:
            if event.isCanceled() {
                isConsumed = inputCancelled(event: event)
            }
        }
        return isConsumed
    }
    
    @Callable
    open func toolSelected() {
        // Do nothing
    }
    
    @Callable(autoSnakeCase: true)
    open func inputBegan(event: InputEvent, globalPosition: Vector2) -> Bool {
        let callable = Callable(object: self, method: "_input_began")
        
        return false
    }
    
    @Callable
    open func inputEnded(event: InputEvent, globalPosition: Vector2) -> Bool {
        return false
    }
    
    @Callable
    open func inputMoved(event: InputEvent, globalPosition: Vector2) -> Bool {
        return false
    }
    
    @Callable
    open func inputCancelled(event: InputEvent) -> Bool  {
        return false
    }
    
    @Callable
    open func inputHover(event: InputEvent, globalPosition: Vector2) -> Bool {
        return false
    }
    
    /// Perform clean-up operation when another tool is selected.
    ///
    /// Use this method to hide tool-related visuals.
    ///
    @Callable
    open func toolReleased() {
        // Do nothing
    }
}
