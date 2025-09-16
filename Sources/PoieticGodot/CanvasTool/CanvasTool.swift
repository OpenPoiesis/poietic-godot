//
//  CanvasTool.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 28/08/2025.
//

import SwiftGodot

/// Abstract class for tools operating on diagram canvas.
///
@Godot
class CanvasTool: SwiftGodot.Node {
    @Export var canvas: DiagramCanvas?
    @Export var canvasController: CanvasController?
    @Export var designController: DesignController?
    
    var objectPalette: PanelContainer?
    
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
