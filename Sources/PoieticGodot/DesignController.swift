//
//  FrameController.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 22/02/2025.
//

import SwiftGodot
import Foundation
import PoieticFlows
import PoieticCore

@Godot
public class PoieticIssue: SwiftGodot.RefCounted {
    var issue: DesignIssue! = nil

    @Export var domain: String {
        get { issue.domain.description}
        set { GD.pushError("Trying to set read-only PoieticIssue attribute") }
    }
    @Export var severity: String {
        get { issue.severity.description }
        set { GD.pushError("Trying to set read-only PoieticIssue attribute") }
    }
    @Export var identifier: String {
        get { issue.identifier }
        set { GD.pushError("Trying to set read-only PoieticIssue attribute") }
    }
    @Export var message: String {
        get { issue.message }
        set { GD.pushError("Trying to set read-only PoieticIssue attribute") }
    }
    @Export var hint: String? {
        get { issue.hint }
        set { GD.pushError("Trying to set read-only PoieticIssue attribute") }
    }
    @Export var details: GDictionary {
        get {
            var dict = GDictionary()
            for (key, value) in issue.details {
                dict[key] = value.asGodotVariant()
            }
            return dict
        }
        set { GD.pushError("Trying to set read-only PoieticIssue attribute") }
    }
}

@Godot
public class PoieticActionResult: SwiftGodot.RefCounted {
    var issues: DesignIssueCollection? = nil
    var createdObjects: [PoieticCore.ObjectID] = []
    var removedObjects: [PoieticCore.ObjectID] = []
    var modifiedObjects: [PoieticCore.ObjectID] = []

    convenience init(fatalError message: String) {
        self.init()

        let issue = DesignIssue(domain: .validation,
                                severity: .fatal,
                                identifier: "internal_error",
                                message: message,
                                hint: "Let the developers know about this error")
        var issues = DesignIssueCollection()
        issues.append(issue)
        self.issues = issues
    }
    required init() {
        super.init()
        onInit()
    }

    required init(nativeHandle: UnsafeRawPointer) {
        super.init(nativeHandle: nativeHandle)
        onInit()
    }
    
    func onInit() {}
    
    @Callable
    func is_success() -> Bool {
        issues?.isEmpty ?? true
    }

    @Callable
    func is_fatal() -> Bool {
        guard let issues else {
            return false
        }
        return issues.designIssues.contains { $0.severity == .fatal }
    }
}

// Single-thread.
/// Manages design context, typically for a canvas and an inspector.
@Godot
public class PoieticDesignController: SwiftGodot.Node {
    var design: Design
    var checker: ConstraintChecker
    var currentFrame: DesignFrame { self.design.currentFrame! }
    var issues: DesignIssueCollection? = nil
    var validatedFrame: ValidatedFrame? = nil

    var metamodel: Metamodel { design.metamodel }
    // let canvas: PoieticCanvas?
   
    // Called on: accept, undo, redo
    #signal("design_changed")

    required init() {
        self.design = Design(metamodel: Metamodel.StockFlow)
        self.checker = ConstraintChecker(design.metamodel)
        super.init()
        onInit()
    }

    required init(nativeHandle: UnsafeRawPointer) {
        self.design = Design(metamodel: Metamodel.StockFlow)
        self.checker = ConstraintChecker(design.metamodel)
        super.init(nativeHandle: nativeHandle)
        onInit()
    }

    func onInit() {
        let frame = self.design.createFrame()
        try! self.design.accept(frame, appendHistory: true)
    }

    @Callable
    func new_design() {
        self.design = Design(metamodel: Metamodel.StockFlow)
        self.checker = ConstraintChecker(design.metamodel)
        let frame = self.design.createFrame()
        try! self.design.accept(frame, appendHistory: true)
        emit(signal: PoieticDesignController.designChanged)
    }
    
    // MARK: - Issues
    @Callable
    func has_issues() -> Bool {
        guard let issues else {
            return false
        }
        return !issues.isEmpty
    }
    
    @Callable
    func issues_for_object(id: Int) -> [PoieticIssue] {
        guard let poieticID = PoieticCore.ObjectID(String(id)) else {
            GD.pushError("Invalid object ID")
            return []
        }

        guard let issues else {
            return []
        }
        guard let objectIssues = issues.objectIssues[poieticID] else {
            return []
        }
        return objectIssues.map {
            let issue = PoieticIssue()
            issue.issue = $0
            return issue
        }
    }
    
    // MARK: - Undo/Redo
    
    @Callable
    func can_undo() -> Bool {
        self.design.canUndo
    }

    @Callable
    func can_redo() -> Bool {
        self.design.canRedo
    }

    /// Undo last command. Returns `true` if something was undone, `false` when there was nothing
    /// to undo.
    @Callable
    func undo() -> Bool {
        if design.undo() {
            frameChanged()
            return true
        }
        else {
            return false
        }
    }

    /// Redo last command. Returns `true` if something was redone, `false` when there was nothing
    /// to redo.
    @Callable
    func redo() -> Bool {
        if design.redo() {
            frameChanged()
            return true
        }
        else {
            return false
        }
    }

    // MARK: - Content
    
    @Callable
    func get_diagram_nodes() -> PackedInt64Array {
        let nodes = currentFrame.nodes.filter { $0.type.hasTrait(.DiagramNode) }
        return PackedInt64Array(nodes.map { Int64($0.id.intValue) })
    }

    @Callable
    func get_diagram_edges() -> PackedInt64Array {
        let edges = currentFrame.edges.filter { _ in true /* FIXME: Use diagram edges only */ }
        return PackedInt64Array(edges.map { Int64($0.id.intValue) })
    }
    @Callable
    func get_object(id: Int) -> PoieticObject? {
        guard let poieticID = PoieticCore.ObjectID(String(id)) else {
            GD.pushError("Invalid origin ID")
            return nil
        }
        guard currentFrame.contains(poieticID) else {
            GD.pushError("Unknown object ID \(poieticID)")
            return nil
        }
        var object = PoieticObject()
        object.object = currentFrame[poieticID]
        return object
    }
    
    @Callable
    func can_connect(type_name: String, origin: Int, target: Int) -> Bool {
        guard let originID = PoieticCore.ObjectID(String(origin)) else {
            GD.pushError("Invalid origin ID")
            return false
        }
        guard let targetID = PoieticCore.ObjectID(String(target)) else {
            GD.pushError("Invalid target ID")
            return false
        }
        guard currentFrame.contains(originID) && currentFrame.contains(targetID) else {
            GD.pushError("Unknown connection endpoints")
            return false
        }
        guard let type = metamodel.objectType(name: type_name) else {
            GD.pushError("Unknown edge type '\(name)'")
            return false
        }
        return checker.canConnect(type: type, from: originID, to: targetID, in: currentFrame)
    }
    
    @Callable
    func new_transaction() -> PoieticTransaction {
        let frame = design.createFrame(deriving: design.currentFrame)
        let trans = PoieticTransaction()
        trans.setFrame(frame)
        return trans
    }
    
    // TODO: Signal design_frame_changed(errors) (also handle errors)
    /// Accept and validate the frame.
    ///
    @Callable
    func accept(transaction: PoieticTransaction) {
        guard let frame = transaction.frame else {
            GD.pushError("Using design without a frame")
            return
        }
        
        do {
            try design.accept(frame, appendHistory: true)
            GD.print("Design accepted. Current frame: \(frame.id), frame count: \(design.frames.count)")
        }
        catch /* StructuralIntegrityError */ {
            GD.pushError("Structural integrity error")
            return
        }
        frameChanged()
    }
    
    /// Called when current frame has been changed.
    ///
    /// Must be called on accept, undo, redo.
    ///
    func frameChanged() {
        guard let currentFrame = design.currentFrame else {
            GD.pushError("No current frame")
            return
        }
        self.validatedFrame = nil
        self.issues = nil
        
        do {
            self.validatedFrame = try design.validate(currentFrame)
        }
        catch let error as FrameValidationError {
            self.issues = error.asDesignIssueCollection()

            GD.printErr("Validation error")
            if let issues = self.issues {
                for issue in issues.designIssues {
                    GD.printErr("  \(issue)")
                }
                for (id, objIssues) in issues.objectIssues {
                    GD.printErr("  Object \(id):")
                    for issue in objIssues {
                        GD.printErr("      \(issue)")
                    }
                }
            }
        }

        // TODO: Store issues somewhere
        emit(signal: PoieticDesignController.designChanged)
    }
    
    @Callable
    func get_distinct_values(selection: PoieticSelection, attribute: String) -> SwiftGodot.Variant {
        guard let frame = design.currentFrame else {
            GD.pushError("Using design without a frame")
            return SwiftGodot.Variant(GArray())
        }
        let array = GArray()
        
        let values = frame.distinctAttribute(attribute, ids: selection.selection.ids)

        for value in values {
            array.append(value.asGodotVariant())
        }
        return SwiftGodot.Variant(array)
    }
    
    @Callable
    func get_distinct_types(selection: PoieticSelection) -> [String] {
        guard let frame = design.currentFrame else {
            GD.pushError("Using design without a frame")
            return []
        }
        let types = frame.distinctTypes(selection.selection.ids)
        return types.map { $0.name }
    }
    
    @Callable
    func get_shared_traits(selection: PoieticSelection) -> [String] {
        guard let frame = design.currentFrame else {
            GD.pushError("Using design without a frame")
            return []
        }
        let traits = frame.sharedTraits(selection.selection.ids)
        return traits.map { $0.name }
    }
    
    @Callable
    func save_to_path(path: String) {
        let url = URL(fileURLWithPath: path)
        let store = MakeshiftDesignStore(url: url)
        do {
            try store.save(design: design)
        }
        catch {
            GD.pushError("Unable to save design: \(error)")
        }
    }
    
    @Callable
    func load_from_path(path: String) {
        let url = URL(fileURLWithPath: path)
        let store = MakeshiftDesignStore(url: url)
        do {
            let design = try store.load(metamodel: FlowsMetamodel)
            self.design = design
            emit(signal: PoieticDesignController.designChanged)
        }
        catch {
            // TODO: Handle various load errors (as in ToolEnvironment of poietic-tool package)
            GD.pushError("Unable to open design: \(error)")
        }
    }
}

/// Wrapper for the Design object.
///
@Godot
class PoieticObject: SwiftGodot.RefCounted {
    var object: DesignObject?
    
    @Export var object_id: Int? {
        get {
            // TODO: Workaround, since SwiftGodot does not allow Int64 properties
            return object.map { Int($0.id.intValue) }
        }
        set { GD.pushError("Trying to set read-only PoieticObject attribute") }
    }

    @Export var name: String? {
        get { object?.name }
        set { GD.pushError("Trying to set read-only PoieticObject attribute") }
    }

    @Export var type_name: String? {
        get { object?.type.name }
        set { GD.pushError("Trying to set read-only PoieticObject attribute") }
    }
    
    @Export var origin: Int? {
        get {
            guard let object, case let .edge(origin, _) = object.structure else {
                return nil
            }
            return Int(origin.intValue)
        }
        set { GD.pushError("Trying to set read-only PoieticObject attribute") }
    }

    @Export var target: Int? {
        get {
            guard let object, case let .edge(_, target) = object.structure else {
                return nil
            }
            return Int(target.intValue)
        }
        set { GD.pushError("Trying to set read-only PoieticObject attribute") }
    }

    @Callable
    func get_id() -> Int64? {
        return object?.id.gdInt64
    }
    
    @Callable
    func get_attribute(attribute: String) -> SwiftGodot.Variant? {
        object?[attribute]?.asGodotVariant()
    }

    @Callable
    func get_position() -> SwiftGodot.Vector2? {
        guard let position = object?.position else {
            return nil
        }
        return position.asGodotVector2()
    }
}
