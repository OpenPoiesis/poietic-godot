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
    var metamodel: Metamodel { design.metamodel }
    var design: Design
    var checker: ConstraintChecker
    var currentFrame: DesignFrame { self.design.currentFrame! }
    var issues: DesignIssueCollection? = nil
    var validatedFrame: ValidatedFrame? = nil
    var simulationPlan: SimulationPlan? = nil
    var result: SimulationResult? = nil
    
    // Called on: accept, undo, redo
    #signal("design_changed", arguments: ["has_issues": Bool.self])

    #signal("simulation_started")
    #signal("simulation_failed")
    #signal("simulation_finished", arguments: ["result": PoieticResult.self])

    required init() {
        self.design = Design(metamodel: FlowsMetamodel)
        self.checker = ConstraintChecker(design.metamodel)
        super.init()
        onInit()
    }
    
    required init(nativeHandle: UnsafeRawPointer) {
        self.design = Design(metamodel: FlowsMetamodel)
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
        self.design = Design(metamodel: FlowsMetamodel)
        self.checker = ConstraintChecker(design.metamodel)
        let frame = self.design.createFrame()
        try! self.design.accept(frame, appendHistory: true)
        emit(signal: PoieticDesignController.designChanged, false)
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
            validateAndCompile()
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
            validateAndCompile()
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
        let edges = currentFrame.edges.filter { $0.object.type.hasTrait(.DiagramConnection) }
        return PackedInt64Array(edges.map { Int64($0.id.intValue) })
    }
    @Callable
    func get_object(id: Int) -> PoieticObject? {
        guard let poieticID = PoieticCore.ObjectID(String(id)) else {
            GD.pushError("Invalid object ID")
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
    func get_difference(nodes: PackedInt64Array, edges: PackedInt64Array) -> PoieticDiagramChange {
        let change = PoieticDiagramChange()
  
        let nodes = nodes.compactMap { ObjectID(String($0)) }
        let currentNodes = currentFrame.nodes.filter {
            $0.type.hasTrait(.DiagramNode)
        }.map { $0.id }
        let nodeDiff = difference(expected: nodes, current: currentNodes)

        change.added_nodes = PackedInt64Array(nodeDiff.added.map {$0.gdInt64})
        change.removed_nodes = PackedInt64Array(nodeDiff.removed.map {$0.gdInt64})

        let edges = edges.compactMap { ObjectID(String($0)) }
        let currentEdges = currentFrame.edges.filter {
            $0.object.type.hasTrait(.DiagramConnection)
        }.map { $0.id }
        let edgeDiff = difference(expected: edges, current: currentEdges)

        change.added_edges = PackedInt64Array(edgeDiff.added.map {$0.gdInt64})
        change.removed_edges = PackedInt64Array(edgeDiff.removed.map {$0.gdInt64})

        return change
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
        accept(frame)
        
    }
    
    func accept(_ frame: TransientFrame) {
        guard frame.hasChanges else {
            GD.print("Nothing to do with transient frame, moving on")
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
        validateAndCompile()
    }
    
    /// Called when current frame has been changed.
    ///
    /// Must be called on accept, undo, redo.
    ///
    func validateAndCompile() {
        guard let currentFrame = design.currentFrame else {
            GD.pushError("No current frame")
            return
        }
        
        // Reset the controller
        self.issues = nil
        self.validatedFrame = nil
        self.simulationPlan = nil
        
        do {
            self.validatedFrame = try design.validate(currentFrame)
        }
        catch let error as FrameValidationError {
            self.issues = error.asDesignIssueCollection()
            debugPrintIssues(self.issues!)
        }

        if let frame = self.validatedFrame {
            // TODO: Sync with ToolEnviornment, make cleaner
            let compiler = Compiler(frame: frame)
            do {
                self.simulationPlan = try compiler.compile()
            }
            catch {
                switch error {
                case .issues(let issues):
                    self.issues = issues.asDesignIssueCollection()
                    debugPrintIssues(self.issues!)
                case .internalError(let error):
                    GD.pushError("INTERNAL ERROR (compiler): \(error)")
                }
            }
        }
        
        emit(signal: PoieticDesignController.designChanged, self.has_issues())
        
        // TODO: Simulate only when there are simulation-related changes.
        // Simulate
        if self.simulationPlan != nil {
            simulate()
        }
    }

    func debugPrintIssues(_ issues: DesignIssueCollection) {
        GD.printErr("Validation error")
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
    
    @Callable
    func get_distinct_values(selection: PoieticSelection, attribute: String) -> SwiftGodot.Variant {
        guard let frame = design.currentFrame else {
            GD.pushError("Using design without a frame")
            return SwiftGodot.Variant(GArray())
        }
        let array = GArray()
        
        let values = frame.distinctAttribute(attribute,
                                             ids: frame.contained(selection.selection.ids))
        
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
        let types = frame.distinctTypes(frame.contained(selection.selection.ids))
        return types.map { $0.name }
    }
    
    @Callable
    func get_shared_traits(selection: PoieticSelection) -> [String] {
        guard let frame = design.currentFrame else {
            GD.pushError("Using design without a frame")
            return []
        }
        let traits = frame.sharedTraits(frame.contained(selection.selection.ids))
        return traits.map { $0.name }
    }
   
    // MARK: - Design Graph Transfomrations
    
    @Callable
    func auto_connect_parameters() {
        guard design.currentFrame != nil else {
            GD.pushError("Using design without a frame")
            return
        }
        
        let trans = design.createFrame(deriving: design.currentFrame)
        let result = autoConnectParameters(trans)

        if !result.added.isEmpty {
            GD.print("Auto-connected parameters:")
            for info in result.added {
                GD.print("    \(info.parameterName ?? "(unnamed)") (\(info.parameterID)) to \(info.targetName ?? "(unnamed)") (\(info.targetID)), edge: \(info.edgeID)")
            }
        }

        if !result.removed.isEmpty {
            GD.print("Auto-disconnected parameters:")
            for info in result.removed {
                GD.print("    \(info.parameterName ?? "(unnamed)") (\(info.parameterID)) from \(info.targetName ?? "(unnamed)") (\(info.targetID)), edge: \(info.edgeID)")
            }
        }
        if !result.unknown.isEmpty {
            let list = result.unknown.joined(separator: ", ")
            GD.print("Unknown parameters: \(list)")
        }

        if trans.hasChanges {
            accept(trans)
        }
        else {
            GD.print("No changes applied.")
            design.discard(trans)
        }
    }
    
    // MARK: - File Actions
    
    @Callable
    func load_from_path(path: String) {
        let url = URL(fileURLWithPath: path)
        let store = MakeshiftDesignStore(url: url)
        do {
            let design = try store.load(metamodel: FlowsMetamodel)
            self.design = design
            validateAndCompile()
        }
        catch {
            // TODO: Handle various load errors (as in ToolEnvironment of poietic-tool package)
            GD.pushError("Unable to open design: \(error)")
        }
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
    
    func makeFileURL(fromPath path: String) -> URL? {
        // TODO: See same method in poietic-tool
        let url: URL
        let manager = FileManager()

        if !manager.fileExists(atPath: path) {
            return nil
        }
        
        // Determine whether the file is a directory or a file
        
        if let attrs = try? manager.attributesOfItem(atPath: path) {
            if attrs[FileAttributeKey.type] as? FileAttributeType == FileAttributeType.typeDirectory {
                url = URL(fileURLWithPath: path, isDirectory: true)
            }
            else {
                url = URL(fileURLWithPath: path, isDirectory: false)
            }
        }
        else {
            url = URL(fileURLWithPath: path)
        }

        return url
    }

    @Callable
    func import_from_path(path: String) -> Bool {
        guard let url = makeFileURL(fromPath: path) else {
            GD.printErr("Import file not found: \(path)")
            return false
        }
        
        let frame: TransientFrame = design.createFrame(deriving: design.currentFrame)
        
        // 1. Read
        GD.print("Importing from \(path)")
        let foreignFrame: any ForeignFrameProtocol
        let reader = JSONFrameReader()

        do {
            if url.hasDirectoryPath {
                foreignFrame = try reader.read(bundleAtURL: url)
            }
            else {
                foreignFrame = try reader.read(fileAtURL: url)
            }
        }
        catch {
            // TODO: Propagate error to the user
            GD.printErr("Unable to read frame '\(path)': \(error)")
            return false
        }

        // 2. Load
        let loader = ForeignFrameLoader()
        do {
            try loader.load(foreignFrame, into: frame)
        }
        catch {
            // TODO: Propagate error to the user
            GD.printErr("Unable to load frame \(path): \(error)")
            return false
        }

        accept(frame)
        return true
    }

    @Export var debug_stats: GDictionary {
        get {
            var dict = GDictionary()
            if let frame = design.currentFrame {
                dict["current_frame"] = SwiftGodot.Variant(frame.id.stringValue)
                dict["nodes"] = SwiftGodot.Variant(frame.nodes.count)
                dict["edges"] = SwiftGodot.Variant(frame.edges.count)
                dict["diagram_nodes"] = SwiftGodot.Variant(self.get_diagram_nodes().count)
                dict["edges"] = SwiftGodot.Variant(frame.edges.count)
            }
            else {
                dict["current_frame"] = SwiftGodot.Variant("none")
                dict["nodes"] = SwiftGodot.Variant(0)
                dict["diagram_nodes"] = SwiftGodot.Variant(0)
                dict["edges"] = SwiftGodot.Variant(0)
            }
            dict["frames"] = SwiftGodot.Variant(design.frames.count)
            dict["undo_frames"] = SwiftGodot.Variant(design.undoableFrames.count)
            dict["redo_frames"] = SwiftGodot.Variant(design.redoableFrames.count)
            if let issues {
                dict["design_issues"] = SwiftGodot.Variant(issues.designIssues.count)
                dict["object_issues"] = SwiftGodot.Variant(issues.objectIssues.count)
            }
            else {
                dict["design_issues"] = SwiftGodot.Variant(0)
                dict["object_issues"] = SwiftGodot.Variant(0)
            }
            return dict
        }
        set { GD.pushError("Trying to set read-only attribute") }
    }

    // MARK: - Simulation Result
    func simulate() {
        guard let simulationPlan else {
            GD.pushError("Trying to simulate without a plan")
            return
        }
        
        self.result = nil
        
        let simulation = StockFlowSimulation(simulationPlan)
        let simulator = Simulator(simulation: simulation,
                                  parameters: simulationPlan.simulationParameters)
        
//        GD.print("Simulation start...")
        emit(signal: PoieticDesignController.simulationStarted)
        
        do {
            try simulator.initializeState()
        }
        catch {
            GD.pushError("Simulation initialisation failed: \(error)")
            emit(signal: PoieticDesignController.simulationFailed)
            return
        }
        
        do {
            try simulator.run()
        }
        catch {
            GD.pushError("Simulation failed at step \(simulator.currentStep): \(error)")
            emit(signal: PoieticDesignController.simulationFailed)
            return
        }
        
        self.result = simulator.result
//        GD.print("Simulation end. Result states: \(simulator.result.count)")
        let wrap = PoieticResult()
        wrap.set(plan: simulationPlan, result: simulator.result)
        emit(signal: PoieticDesignController.simulationFinished, wrap)
        
    }

    @Callable
    public func result_time_series(id: Int) -> PackedFloat64Array? {
        guard let poieticID = PoieticCore.ObjectID(String(id)) else {
            GD.pushError("Invalid ID")
            return nil
        }
        guard let result, let plan = simulationPlan else {
            GD.printErr("Playing without result or plan")
            return nil
        }
        guard let index = plan.variableIndex(of: poieticID) else {
            GD.printErr("Can not get numeric value of unknown object ID \(poieticID)")
            return nil
        }
        let values = result.unsafeFloatValueTimeSeries(at: index)
        return PackedFloat64Array(values)
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

    @Export var object_name: String? {
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
        guard let object else {
            GD.pushError("No object set")
            return nil
        }
        return object[attribute]?.asGodotVariant()
    }
    
    @Callable
    func get_attribute_keys() -> [String] {
        guard let object else { return [] }
        return object.type.attributeKeys
    }

    @Callable
    func get_position() -> SwiftGodot.Vector2? {
        guard let position = object?.position else {
            return nil
        }
        return position.asGodotVector2()
    }
}

@Godot
class PoieticDiagramChange: SwiftGodot.Object {
    @Export var added_nodes: PackedInt64Array = PackedInt64Array()
    @Export var current_nodes: PackedInt64Array = PackedInt64Array()
    @Export var removed_nodes: PackedInt64Array = PackedInt64Array()
    
    @Export var added_edges: PackedInt64Array = PackedInt64Array()
    @Export var current_edges: PackedInt64Array = PackedInt64Array()
    @Export var removed_edges: PackedInt64Array = PackedInt64Array()
}
