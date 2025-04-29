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
        set { readOnlyAttributeError() }
    }
    @Export var severity: String {
        get { issue.severity.description }
        set { readOnlyAttributeError() }
    }
    @Export var identifier: String {
        get { issue.identifier }
        set { readOnlyAttributeError() }
    }
    @Export var message: String {
        get { issue.message }
        set { readOnlyAttributeError() }
    }
    @Export var hint: String? {
        get { issue.hint }
        set { readOnlyAttributeError() }
    }
    @Export var attribute: String? {
        get { try? issue.details["attribute"]?.stringValue() }
        set { readOnlyAttributeError() }
    }
    @Export var details: GDictionary {
        get {
            var dict = GDictionary()
            for (key, value) in issue.details {
                dict[key] = value.asGodotVariant()
            }
            return dict
        }
        set { readOnlyAttributeError() }
    }
}

// Single-thread.
/// Manages design context, typically for a canvas and an inspector.
@Godot
public class PoieticDesignController: SwiftGodot.Node {
    static let DesignSettingsFrameName = "settings"
    
    var _metamodel: Metamodel { design.metamodel }
    let _gdMetamodelWrapper: PoieticMetamodel
    var design: Design
    var checker: ConstraintChecker
    var currentFrame: DesignFrame { self.design.currentFrame! }
    var issues: DesignIssueCollection? = nil
    var validatedFrame: ValidatedFrame? = nil
    var simulationPlan: SimulationPlan? = nil
    var result: SimulationResult? = nil
    
    // Called on: load from path
    #signal("design_reset")
    // Called on: accept, undo, redo
    #signal("design_changed", arguments: ["has_issues": Bool.self])

    #signal("simulation_started")
    #signal("simulation_failed")
    #signal("simulation_finished", arguments: ["result": PoieticResult.self])

    @Export var metamodel: PoieticMetamodel? {
        get { return _gdMetamodelWrapper }
        set { GD.pushError("Trying to set read-only attribute") }
    }

    required init() {
        self.design = Design(metamodel: StockFlowMetamodel)
        self.checker = ConstraintChecker(design.metamodel)
        self._gdMetamodelWrapper = PoieticMetamodel()
        self._gdMetamodelWrapper.metamodel = design.metamodel

        super.init()
        onInit()
    }
    
    required init(nativeHandle: UnsafeRawPointer) {
        self.design = Design(metamodel: StockFlowMetamodel)
        self.checker = ConstraintChecker(design.metamodel)
        self._gdMetamodelWrapper = PoieticMetamodel()
        self._gdMetamodelWrapper.metamodel = design.metamodel

        super.init(nativeHandle: nativeHandle)
        onInit()
    }
    
    func onInit() {
        let frame = self.design.createFrame()
        try! self.design.accept(frame, appendHistory: true)
    }
    
    @Callable
    func new_design() {
        self.design = Design(metamodel: StockFlowMetamodel)
        self.checker = ConstraintChecker(design.metamodel)
        let frame = self.design.createFrame()
        try! self.design.accept(frame, appendHistory: true)
        emit(signal: PoieticDesignController.designChanged, false)
    }
    
    // MARK: - Object Graph
    
    @Callable
    func get_object(id: Int64) -> PoieticObject? {
        guard let id = PoieticCore.ObjectID(id) else {
            GD.pushError("Invalid object ID")
            return nil
        }
        guard currentFrame.contains(id) else {
            GD.pushError("Unknown object ID \(id)")
            return nil
        }
        var object = PoieticObject()
        object.object = currentFrame[id]
        return object
    }

    @Callable
    func get_object_ids(type_name: String) -> PackedInt64Array {
        guard let type = design.metamodel.objectType(name: type_name) else {
            GD.pushError("Unknown object type '\(type_name)'")
            return PackedInt64Array()
        }
        var objects = currentFrame.filter { $0.type === type }
        return PackedInt64Array(objects.map { Int64($0.id.intValue) })
    }

    /// Order given IDs by the given attribute in ascending order.
    ///
    /// Rules:
    /// - If the object does not have the given attribute, it is ordered last
    /// - Attribute-less objects are ordered by a value derived from their ID,
    ///   which is arbitrary but consistent within design.
    ///
    @Callable
    func vaguely_ordered(ids: PackedInt64Array, order_attribute: String) -> PackedInt64Array {
        // TODO: Make this method Frame.vaguelyOrdered(ids, orderAttribute:)
        var objects:[DesignObject] = ids.compactMap {
            guard let id = ObjectID($0) else { return nil }
            return currentFrame[id]
        }
        if objects.count != ids.count {
            GD.pushError("Some IDs were not found in the frame")
        }
        objects.sort { (left, right) in
            switch (left[order_attribute], right[order_attribute]) {
            case let (.some(lvalue), .some(rvalue)):
                if let flag = lvalue.vaguelyInAscendingOrder(after: rvalue) {
                    return flag
                }
                else {
                    return left.id.intValue < right.id.intValue
                }
            case (.none, .some(_)): return false
            case (.some(_), .none): return true
            case (.none, .none):
                return left.id.intValue < right.id.intValue
            }
        }

        return PackedInt64Array(objects.map { Int64($0.id.intValue) })
    }
    
    @Callable
    func get_outgoing_ids(origin_id: Int64, type_name: String) -> PackedInt64Array {
        guard let origin_id = PoieticCore.ObjectID(origin_id) else {
            GD.pushError("Invalid object ID")
            return PackedInt64Array()
        }

        guard let type = design.metamodel.objectType(name: type_name) else {
            GD.pushError("Unknown object type '\(type_name)'")
            return PackedInt64Array()
        }
        
        let objects = currentFrame.outgoing(origin_id).filter { $0.object.type === type }
        return PackedInt64Array(objects.map { Int64($0.id.intValue) })
    }
    
    @Callable
    func get_diagram_nodes() -> PackedInt64Array {
        let nodes = currentFrame.nodes.filter { $0.type.hasTrait(.DiagramNode) }
        return PackedInt64Array(nodes.map { Int64($0.id.intValue) })
    }
    
    @Callable
    func get_diagram_edges() -> PackedInt64Array {
        let edges = currentFrame.edges.filter { $0.object.type.hasTrait(.DiagramConnector) }
        return PackedInt64Array(edges.map { Int64($0.id.intValue) })
    }

    @Callable
    func get_difference(nodes: PackedInt64Array, edges: PackedInt64Array) -> PoieticDiagramChange {
        let change = PoieticDiagramChange()
  
        let nodes = nodes.compactMap { ObjectID(String($0)) }
        let currentNodes = currentFrame.nodes.filter {
            $0.type.hasTrait(.DiagramNode)
        }.map { $0.id }
        let nodeDiff = difference(expected: nodes, current: currentNodes)

        change.added_nodes = PackedInt64Array(nodeDiff.added.map {$0.godotInt})
        change.removed_nodes = PackedInt64Array(nodeDiff.removed.map {$0.godotInt})

        let edges = edges.compactMap { ObjectID(String($0)) }
        let currentEdges = currentFrame.edges.filter {
            $0.object.type.hasTrait(.DiagramConnector)
        }.map { $0.id }
        let edgeDiff = difference(expected: edges, current: currentEdges)

        change.added_edges = PackedInt64Array(edgeDiff.added.map {$0.godotInt})
        change.removed_edges = PackedInt64Array(edgeDiff.removed.map {$0.godotInt})

        return change
    }
    
    // MARK: - Special Objects
    @Callable
    func get_diagram_settings() -> GDictionary? {
        guard let frame = design.frame(name: PoieticDesignController.DesignSettingsFrameName) else {
            return nil
        }
        guard let obj = frame.first(type: .DiagramSettings) else {
            return nil
        }
        
        return GDictionary(obj.attributes)
    }
    @Callable
    func set_diagram_settings(settings: GDictionary) {
        let original = design.frame(name: PoieticDesignController.DesignSettingsFrameName)
        let trans = design.createFrame(deriving: original)
        let mut: MutableObject
        if let obj = trans.first(type: .DiagramSettings) {
            mut = trans.mutate(obj.id)
        }
        else {
            mut = trans.create(.DiagramSettings)
        }

        for (attr, value) in settings.asLossyPoieticAttributes() {
            mut[attr] = value
        }
        do {
            try design.accept(trans, replacingName: PoieticDesignController.DesignSettingsFrameName)
        }
        catch /* StructuralIntegrityError */ {
            GD.pushError("Structural integrity error")
            return
        }
    }

    @Callable func get_design_info_object() -> PoieticObject? {
        guard let first = currentFrame.filter(type: ObjectType.DesignInfo).first else {
            return nil
        }
        var object = PoieticObject()
        object.object = first
        return object
    }

    @Callable func get_simulation_parameters_object() -> PoieticObject? {
        guard let first = currentFrame.filter(type: ObjectType.Simulation).first else {
            return nil
        }
        var object = PoieticObject()
        object.object = first
        return object
    }
    // MARK: - Transaction -
    @Callable
    func new_transaction() -> PoieticTransaction {
        let frame = design.createFrame(deriving: design.currentFrame)
        let trans = PoieticTransaction()
        trans.setFrame(frame)
        return trans
    }
    
    @Callable
    func discard(transaction: PoieticTransaction) {
        guard let frame = transaction.frame else {
            GD.pushError("Using design without a frame")
            return
        }
        design.discard(frame)
        
    }
    // TODO: Signal design_frame_changed(errors) (also handle errors)
    /// Accept and validate the frame.
    ///
    /// If the transaction has no changes, then it is discarded and no changes are applied. History
    /// stays untouched.
    ///
    @Callable
    func accept(transaction: PoieticTransaction) {
        guard let frame = transaction.frame else {
            GD.pushError("Using design without a frame")
            return
        }
        transaction.frame = nil
        accept(frame)
    }
    
    func accept(_ frame: TransientFrame) {
        guard frame.hasChanges else {
            GD.print("Nothing to do with transient frame, discarding and moving on")
            design.discard(frame)
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

    
    // MARK: - Issues
    @Callable
    func has_issues() -> Bool {
        guard let issues else {
            return false
        }
        return !issues.isEmpty
    }
    
    @Callable
    func issues_for_object(id: Int64) -> [PoieticIssue] {
        guard let poieticID = PoieticCore.ObjectID(id) else {
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
    
    @Callable func can_undo() -> Bool { self.design.canUndo }
    @Callable func can_redo() -> Bool { self.design.canRedo }
    
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
    @Callable
    func can_connect(type_name: String, origin: Int64, target: Int64) -> Bool {
        guard let originID = PoieticCore.ObjectID(origin) else {
            GD.pushError("Invalid origin ID")
            return false
        }
        guard let targetID = PoieticCore.ObjectID(target) else {
            GD.pushError("Invalid target ID")
            return false
        }
        guard currentFrame.contains(originID) && currentFrame.contains(targetID) else {
            GD.pushError("Unknown connection endpoints")
            return false
        }
        guard let type = _metamodel.objectType(name: type_name) else {
            GD.pushError("Unknown edge type '\(name)'")
            return false
        }
        return checker.canConnect(type: type, from: originID, to: targetID, in: currentFrame)
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
    func auto_connect_parameters(ids: PackedInt64Array) {
        guard let validated = validatedFrame else {
            GD.pushError("Using design without a frame")
            return
        }
        
        let ids = ids.compactMap { PoieticCore.ObjectID($0) }
        let view = StockFlowView(validated)
        let nodes: [DesignObject]
        if ids.isEmpty {
            nodes = view.simulationNodes
        }
        else {
            nodes = ids.map { validated[$0] }
        }
        let resolvedParams = resolveParameters(objects: nodes, view: view)
        // TODO: Know whether there is anything to do at this point

        if resolvedParams.isEmpty {
            GD.print("Nothing to auto-connect")
            return
        }
        
        let trans = design.createFrame(deriving: design.currentFrame)
        let result = autoConnectParameters(resolvedParams, in: trans)

        GD.print("Auto-connected \(resolvedParams.count) objects")

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
            let design = try store.load(metamodel: StockFlowMetamodel)
            self.design = design
        }
        catch {
            // TODO: Handle various load errors (as in ToolEnvironment of poietic-tool package)
            GD.pushError("Unable to open design: \(error)")
            return
        }
        emit(signal: PoieticDesignController.designReset)
        validateAndCompile()
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

    @Callable
    func import_from_data(data: PackedByteArray) -> Bool {
        let frame: TransientFrame = design.createFrame(deriving: design.currentFrame)
        let nativeData: Data = Data(data)
        // 1. Read
        GD.print("Importing from data")
        let foreignFrame: any ForeignFrameProtocol
        let reader = JSONFrameReader()

        do {
            foreignFrame = try reader.read(data: nativeData)
        }
        catch {
            // TODO: Propagate error to the user
            GD.printErr("Unable to read frame from data: \(error)")
            return false
        }

        // 2. Load
        let loader = ForeignFrameLoader()
        do {
            try loader.load(foreignFrame, into: frame)
        }
        catch {
            // TODO: Propagate error to the user
            GD.printErr("Unable to load frame from data: \(error)")
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
        let wrap = PoieticResult()
        wrap.set(plan: simulationPlan, result: simulator.result)
        emit(signal: PoieticDesignController.simulationFinished, wrap)
        
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
