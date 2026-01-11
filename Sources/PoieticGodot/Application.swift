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
    /// Signal emitted when an action has failed. For example when opening a corrupted file.
    ///
    /// The signal parameters are:
    /// - Failed action name
    /// - Error message
    /// - Additional information
    @Signal var commandFailed: SignalWithArguments<String,String,SwiftGodot.VariantDictionary>

    // MARK: - Tools
    @Export var currentTool: CanvasTool?
    @Export var previousTool: CanvasTool?
    @Signal var toolChanged: SignalWithArguments<CanvasTool>

    // TODO: Hide tools, use just their names
    var selectionTool: SelectionTool
    var placeTool: PlaceTool
    var connectTool: ConnectTool
    var panTool: PanTool

    // TODO: Allow more designs per application.
    @Export var designController: DesignController
    var currentDesign: Design? { designController.design }
    
    // MARK: - Methods

    required init(_ context: InitContext) {
        GD.print("==> Initialising Poietic Application", context)
        designController = DesignController()
        
        selectionTool = SelectionTool()
        placeTool = PlaceTool()
        connectTool = ConnectTool()
        panTool = PanTool()

        currentTool = selectionTool
        previousTool = selectionTool
        
        super.init(context)
        designController.application = self
        GD.print("<-- Poietic Application initialised.", self)
    }

    override func _ready() {
        GD.print("--- Poietic Application Ready.", self, "Parent: ", self.getParent())
        self.addChild(node: selectionTool)
        self.addChild(node: placeTool)
        self.addChild(node: connectTool)
        self.addChild(node: panTool)
    }

    // MARK: - Actions and Action Dispatch
    // TODO: Turn this into commands.
    
    @Callable(autoSnakeCase: true)
    func performObjectsAction(_ actionName: String, rawIDs: PackedInt64Array) {
        let ids: [PoieticCore.ObjectID] = rawIDs.asDesignEntityIDs()
        performAction(actionName, ids: ids)
    }

    @Callable(autoSnakeCase: true)
    func performSelectionAction(_ actionName: String) {
        let ids = designController.selectionManager.selection.ids
        guard !ids.isEmpty else {
            GD.print("Selection is empty. Required for action: ", actionName)
            return
        }
        performAction(actionName, ids: ids)
    }

    func performAction(_ actionName: String, ids: [PoieticCore.ObjectID]) {
        switch actionName {
        case "delete_objects":
            designController.deleteObjects(ids)
        case "remove_midpoints":
            designController.removeConnectorMidpoints(ids)
        default:
            GD.pushError("Unknown application action: ", actionName)
        }
    }

    // MARK: - Tool
    
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
                
        tool.bind(designController)
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
        guard designController.design.undo() else { return false }
        designController.run(schedule: FrameChangeSchedule.self)
        designController.simulate()
        return true
    }
    
    /// Redo last command. Returns `true` if something was redone, `false` when there was nothing
    /// to redo.
    @Callable
    func redo() -> Bool {
        guard designController.design.redo() else { return false }
        designController.run(schedule: FrameChangeSchedule.self)
        designController.simulate()
        return true
    }

}
