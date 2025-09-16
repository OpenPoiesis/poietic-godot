//
//  Application.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 02/09/2025.
//

import SwiftGodot
import PoieticCore

public let AppNodePath = "/root/Main/PoieticApplication"

/// Main node for graphical Poietic applications and design editors.
@Godot
class PoieticApplication: SwiftGodot.Node {
    // MARK: - Tools
    @Export var currentTool: CanvasTool?
    @Export var previousTool: CanvasTool?
    @Signal var toolChanged: SignalWithArguments<CanvasTool>

    // TODO: Hide tools, use just their names
    @Export var selectionTool: SelectionTool
    @Export var placeTool: PlaceTool
    @Export var connectTool: ConnectTool
    @Export var panTool: PanTool

    // MARK: - Controllers
    // TODO: Not sure whether this should be here, but keeping it for now
    @Export var designController: DesignController?
    @Export var canvasController: CanvasController?
    var currentDesign: Design? { designController?.design }
    

    // var panTool: PanTool
    // MARK: - Methods

    required init(_ context: InitContext) {
        designController = DesignController()
        
        GD.print("--- BEGIN Tool init")
        selectionTool = SelectionTool()
        placeTool = PlaceTool()
        connectTool = ConnectTool()
        panTool = PanTool()
        GD.print("--- END Tool init")

        currentTool = selectionTool
        previousTool = selectionTool
        
        super.init(context)
    }

    @Callable(autoSnakeCase: true)
    func changeTool(_ tool: CanvasTool) {
        // TODO: Rename to set tool, and make a tool name based version
        if let currentTool {
            currentTool.toolReleased()
        }
        previousTool = currentTool
        currentTool = tool
        if let canvasController {
            tool.bind(canvasController)
        }
        else {
            GD.pushWarning("Unable to bind canvas tool: No diagram controller")
        }
        tool.toolSelected()
        toolChanged.emit(tool)
    }
    
    // MARK: - Undo/Redo
    
    @Callable(autoSnakeCase: true)
    func canUndo() -> Bool { currentDesign?.canUndo ?? false}
    @Callable(autoSnakeCase: true)
    func canRedo() -> Bool { currentDesign?.canRedo ?? false}
    
    /// Undo last command. Returns `true` if something was undone, `false` when there was nothing
    /// to undo.
    @Callable
    func undo() -> Bool {
        guard let ctrl = designController else { return false }
        guard ctrl.design.undo() else { return false }
        ctrl.validateAndCompile()
        return true
    }
    
    /// Redo last command. Returns `true` if something was redone, `false` when there was nothing
    /// to redo.
    @Callable
    func redo() -> Bool {
        guard let ctrl = designController else { return false }
        guard ctrl.design.redo() else { return false }
        ctrl.validateAndCompile()
        return true
    }

}
