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
///
/// Responsibilities:
///
/// - Design: create, open, close, get current.
/// - Tools: current tool, tool change
/// - Focus: current design, current canvas, current selection.
///
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
    
    @Export var currentSelection: PackedInt64Array? {
        get {
            guard let ctrl = designController else { return nil }
            return ctrl.selectionManager.get_ids()
        }
        set(values) {
            guard let ctrl = designController else { return }
            if let values {
                ctrl.selectionManager.replace(ids: values)
            }
            else {
                ctrl.selectionManager.clear()
            }
        }
    }
    
    
    // var panTool: PanTool
    // MARK: - Methods

    required init(_ context: InitContext) {
        designController = DesignController()
        
        selectionTool = SelectionTool()
        placeTool = PlaceTool()
        connectTool = ConnectTool()
        panTool = PanTool()

        currentTool = selectionTool
        previousTool = selectionTool
        
        GD.print("Poietic Application initialised.")
        super.init(context)
    }

    override func _ready() {
        self.addChild(node: selectionTool)
        self.addChild(node: placeTool)
        self.addChild(node: connectTool)
        self.addChild(node: panTool)
    }
    
    @Callable(autoSnakeCase: true)
    func setTool(_ toolName: String) {
        switch toolName {
        case "selection": self.switchTool(self.selectionTool)
        case "place": self.switchTool(self.placeTool)
        case "connect": self.switchTool(self.connectTool)
        case "pan": self.switchTool(self.panTool)
        default:
            GD.pushWarning("Unknown tool: ", toolName)
            self.switchTool(self.selectionTool)
        }
    }

    @Callable(autoSnakeCase: true)
    func switchTool(_ tool: CanvasTool) {
        // TODO: Rename to setTool(...)
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
    
    @Callable(autoSnakeCase: true)
    func flipTool() {
        if let previousTool {
            switchTool(previousTool)
        }
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
