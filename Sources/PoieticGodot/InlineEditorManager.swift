//
//  InlineEditorManager.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 24/11/2025.
//

import SwiftGodot
import PoieticCore

// NOTE: This is an interim location to store inline editors. They were formerly in CanvasController.
// I am not quite sure where this should belong.
// - DiagramController: would be too polluted
// - Application: makes little sense
// Analogy is FieldEditor in Apple AppKit NSWindow

/// Provides inline editors for diagram canvas.
///
/// The node requires editors to be its children. The suffix `Editor` or `InlineEditor` is removed
/// from the node name.
///
/// Example scene tree:
///
/// ```
///  ...
///   - GUI
///       - InlineEditorManager
///           - NameInlineEditor
///           - FormulaInlineEditor
///
/// ```
///
@Godot
class InlineEditorManager: Node {
    var inlineEditors: [String:SwiftGodot.Control] = [:]
    @Export public var contextMenu: SwiftGodot.Control?
    @Export public var issuesPopup: SwiftGodot.Control?
    
    var designController: DesignController?
    var world: World? { designController?.world }
    var canvas: DiagramCanvas?
    /// A control that is shown alongside a node, such as inline editor or issue list.
    @Export var currentPopup: SwiftGodot.Control?

    public override func _ready() {
        let editors = self.findChildren(pattern: "*", type: "CanvasInlineEditor", recursive: false)
        for editor in editors {
            guard let editor = editor as? SwiftGodot.Control else { continue }
            GD.print("Registering editor: ", editor.name)

            // Check for pseudo-protocol conformance.
            //
            // This code is here because (to my knowledge) it is not possible to subclass extension
            // class in Godot script.
            //
            guard editor.hasMethod("open"),
                  editor.hasMethod("close") else
            {
                GD.pushError("Can not register editor '\(name)': missing required methods")
                return
            }

            let nodeName = String(editor.name)
            let name: String
            if nodeName.hasSuffix("InlineEditor") {
                name = String(nodeName.dropLast("InlineEditor".count))
            } else if nodeName.hasSuffix("Editor") {
                name = String(nodeName.dropLast("Editor".count))
            }
            else {
                name = nodeName
            }
            self.inlineEditors[name] = editor
        }
    }
    
    @Callable
    public func initialize(designController: DesignController, canvas: DiagramCanvas) {
        self.designController = designController
        self.canvas = canvas
    }
    
    // MARK: - Inline Editors and Pop-ups
    //
    
    @Callable(autoSnakeCase: true)
    func inlineEditor(_ name: String) -> SwiftGodot.Control? {
        guard let editor = inlineEditors[name] else {
            GD.pushError("No inline editor '\(name)'")
            return nil
        }
        return editor
    }
    @Callable(autoSnakeCase: true)
    func openContextMenu(_ selection: PackedInt64Array, desiredGlobalPosition: Vector2) {
        guard let contextMenu else { return }
        // TODO: Context menu needs to be populated before we call open
        contextMenu.call(method: "update", Variant(selection))
        let halfWidth = contextMenu.getSize().x / 2.0
        let position = Vector2(x: desiredGlobalPosition.x - halfWidth,
                               y: desiredGlobalPosition.y)
        openInlinePopup(control: contextMenu, position: position)
    }
    
    @Callable(autoSnakeCase: true)
    func openIssuesPopup(_ rawEntityID: EntityIDValue, issues: TypedArray<PoieticIssue?>) {
        let entityID = EphemeralID(rawValue: rawEntityID)
        guard let issuesPopup,
              let canvas,
              let block = canvas.block(id: entityID)
        else { return }
        guard issuesPopup.hasMethod("set_issues") else {
            GD.pushError("Invalid issues popup node: set_issues method missing")
            return
        }

        issuesPopup.call(method: "set_issues",
                         SwiftGodot.Variant(rawEntityID),
                         SwiftGodot.Variant(issues))

        let position: Vector2
        if let indicator =  block.issueIndicator {
            position = indicator.globalPosition
        }
        else {
            position = canvas.promptPosition(for: entityID)
        }
        openInlinePopup(control: issuesPopup, position: position)
    }
    
    @Callable(autoSnakeCase: true)
    func openInlineEditor(_ editorName: String,
                          rawEntityID: EntityIDValue,
                          attribute: String) {
        let entityID = EphemeralID(rawValue: rawEntityID)
        // TODO: Allow editing of not-yet-existing objects, such as freshly placed block
        guard let designController,
              let objectID = designController.world.entityToObject(entityID),
              let object = designController.currentFrame[objectID],
              let canvas,
              let editor = inlineEditor(editorName)
        else {
            GD.pushError("Inline editor is not satisfied")
            return
        }
        
        let value = object[attribute]
        var position = canvas.promptPosition(for: entityID)
        openInlinePopup(control: editor, position: position)
        
        var godotObject = PoieticObject()
        godotObject.object = object
        
        editor.call(method: "open",
                    SwiftGodot.Variant(godotObject),
                    SwiftGodot.Variant(attribute),
                    value?.asGodotVariant())
        self.currentPopup = editor
    }
    
    @Callable(autoSnakeCase: true)
    func openInlinePopup(control: SwiftGodot.Control, position: Vector2) {
        if let currentPopup {
            closeInlinePopup()
        }
        let size = control.getSize()
        let adjustedPosition = Vector2(x: position.x - size.x / 2.0, y: position.y)
        control.setGlobalPosition(adjustedPosition)
        control.setProcess(enable: true)
        control.show()
        self.currentPopup = control
    }
    
    @Callable(autoSnakeCase: true)
    func closeInlinePopup() {
        guard let currentPopup else { return }
        if currentPopup.hasMethod("close") {
            currentPopup.call(method: "close")
        }
        currentPopup.hide()
        currentPopup.setProcess(enable: false)
        self.currentPopup = nil
    }


}
