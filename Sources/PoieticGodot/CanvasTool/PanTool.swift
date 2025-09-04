//
//  PanTool.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 04/09/2025.
//

import SwiftGodot

enum PanToolState: Int, CaseIterable {
    case idle
    case panning
}

@Godot
class PanTool: CanvasTool {

    @Export var state: PanToolState = .idle
    @Export var startCanvasOffset: Vector2 = .zero
    @Export var previousPosition: Vector2 = .zero

    override func toolName() -> String { "pan" }
    
    override func toolSelected() {
        Input.setDefaultCursorShape(.pointingHand)
    }
    
    override func toolReleased() {
        Input.setDefaultCursorShape(.arrow)
    }

    override func inputBegan(event: InputEvent, pointerPosition: Vector2) -> Bool {
        guard let canvas else { return false }
        guard let event = event as? InputEventMouseButton else { return false }
        guard event.buttonIndex == .left else { return false }
        
        startCanvasOffset = canvas.canvasOffset
        previousPosition = pointerPosition
        state = .panning
        Input.setDefaultCursorShape(.drag)
        return true
    }
    
    override func inputMoved(event: InputEvent, moveDelta: Vector2) -> Bool {
        guard state == .panning else { return false }
        guard let canvas else { return false }
        
        previousPosition += moveDelta
        canvas.canvasOffset += moveDelta * Double(canvas.zoomLevel)
        canvas.updateCanvasView()
        
        return true
    }
    

    override func inputEnded(event: InputEvent, pointerPosition: Vector2) -> Bool {
        guard state == .panning else { return false }
        guard let canvas else { return false }
        
        canvas.canvasOffset += (pointerPosition - previousPosition) * Double(canvas.zoomLevel)
        canvas.updateCanvasView()
        state = .idle
        Input.setDefaultCursorShape(.pointingHand)
        return true
    }
    
    override func inputCancelled(event: InputEvent) -> Bool  {
        state = .idle
        return true
    }
}
