//
//  CanvasTool.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 28/08/2025.
//

import SwiftGodot

@Godot
class CanvasTool: SwiftGodot.Node {
    @Export var canvas: DiagramCanvas?
    @Export var diagramController: PoieticDiagramController?
    @Export var designController: PoieticDesignController?
    
    var objectPalette: PanelContainer?
    
    required init(_ context: SwiftGodot.InitContext) {
        super.init(context)
    }
    
    @Callable
    func initialize(diagramController: PoieticDiagramController,
                    designController: PoieticDesignController) {
        self.diagramController = diagramController
        self.canvas = diagramController.canvas
        self.designController = designController
    }
    
    @Callable
    func toolName() -> String { "default" }
    
    @Callable
    open func handleInput(event: InputEvent) -> Bool {
        var isConsumed: Bool = false
        switch event {
        case let event as InputEventMouseButton:
            let mousePosition = event.globalPosition
            if event.isPressed() {
                isConsumed = inputBegan(event: event, pointerPosition: mousePosition)
            }
            else if event.isReleased() {
                isConsumed = inputEnded(event: event, pointerPosition: mousePosition)
            }
        case let event as InputEventMouseMotion:
            let mousePosition = event.globalPosition
            if event.buttonMask == .left {
                isConsumed = inputMoved(event: event, moveDelta: event.relative / Double(canvas?.zoomLevel ?? 1.0))
            }
            else {
                isConsumed = inputHover(event: event, pointerPosition: mousePosition)
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
    open func inputBegan(event: InputEvent, pointerPosition: Vector2) -> Bool {
        let callable = Callable(object: self, method: "_input_began")
        
        return false
    }
    
    @Callable
    open func inputEnded(event: InputEvent, pointerPosition: Vector2) -> Bool {
        return false
    }
    
    @Callable
    open func inputMoved(event: InputEvent, moveDelta: Vector2) -> Bool {
        return false
    }
    
    @Callable
    open func inputCancelled(event: InputEvent) -> Bool  {
        return false
    }
    
    @Callable
    open func inputHover(event: InputEvent, pointerPosition: Vector2) -> Bool {
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
