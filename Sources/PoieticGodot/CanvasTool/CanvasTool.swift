//
//  CanvasTool.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 28/08/2025.
//

import SwiftGodot
import PoieticCore

// TODO: Implement "tool locking": When tool is clicked/selected twice, it is locked. Otherwise it returns to selection tool.

/// Abstract class for tools operating on diagram canvas.
///
/// Tool is an active object that can create transactions, update other nodes and run system
/// updates.
///
@Godot
class CanvasTool: SwiftGodot.Node {
    @Export var designController: DesignController?

    /// Shortcut for current runtime frame from the associated design controller.
    var runtimeFrame: AugmentedFrame? { designController?.runtimeFrame }

    /// Identifier of an item, selected in palette, to be placed.
    @Export var paletteItemIdentifier: String? {
        didSet { paletteItemChanged(paletteItemIdentifier) }
    }

    /// Bind the tool to a diagram controller.
    @Callable
    func bind(_ designController: DesignController) {
        self.designController = designController
    }
    
    @Callable
    func toolName() -> String { "default" }
    
    // TODO: This feel dirty
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
    open func handleInput(canvas: DiagramCanvas, event: InputEvent) -> Bool {
        var isConsumed: Bool = false
        switch event {
        case let event as InputEventMouseButton:
            if event.isPressed() {
                isConsumed = inputBegan(canvas: canvas, event: event, globalPosition: event.globalPosition)
            }
            else if event.isReleased() {
                isConsumed = inputEnded(canvas: canvas, event: event, globalPosition: event.globalPosition)
            }
        case let event as InputEventMouseMotion:
            if event.buttonMask == .left {
                isConsumed = inputMoved(canvas: canvas, event: event, globalPosition: event.globalPosition)
            }
            else {
                isConsumed = inputHover(canvas: canvas, event: event, globalPosition: event.globalPosition)
            }
        default:
            if event.isCanceled() {
                isConsumed = inputCancelled(canvas: canvas, event: event)
            }
        }
        return isConsumed
    }
    
    @Callable
    open func toolSelected() {
        // Do nothing
    }
    
    @Callable(autoSnakeCase: true)
    open func inputBegan(canvas: DiagramCanvas, event: InputEvent, globalPosition: Vector2) -> Bool {
        let callable = Callable(object: self, method: "_input_began")
        
        return false
    }
    
    @Callable
    open func inputEnded(canvas: DiagramCanvas, event: InputEvent, globalPosition: Vector2) -> Bool {
        return false
    }
    
    @Callable
    open func inputMoved(canvas: DiagramCanvas, event: InputEvent, globalPosition: Vector2) -> Bool {
        return false
    }
    
    @Callable
    open func inputCancelled(canvas: DiagramCanvas, event: InputEvent) -> Bool  {
        return false
    }
    
    @Callable
    open func inputHover(canvas: DiagramCanvas, event: InputEvent, globalPosition: Vector2) -> Bool {
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

    func updatePreview(canvas: DiagramCanvas) {
        guard let runtimeFrame
        else { return }
        
        let component = CanvasComponent(canvas: canvas)
        runtimeFrame.setComponent(component, for: .Frame)
        
        designController?.updatePreviewSystems()
    }
}
