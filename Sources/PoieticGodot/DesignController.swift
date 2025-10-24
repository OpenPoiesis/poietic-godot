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
import Diagramming

// Single-thread.
/// Manages design context, typically for a canvas and an inspector.
@Godot
public class DesignController: SwiftGodot.Node {
    static let DesignSettingsFrameName = "settings"
    
    // TODO: Review where is the ctrl metamodel used
    // TODO: Remove this or rename to `metamodel`
    var _metamodel: Metamodel { design.metamodel }
    var design: Design
    var checker: ConstraintChecker
    var currentFrame: DesignFrame { self.design.currentFrame! }
    var issues: DesignIssueCollection? = nil
    var validatedFrame: ValidatedFrame? = nil
    var simulationPlan: SimulationPlan? = nil
    var result: SimulationResult? = nil

    @Export var selectionManager: SelectionManager

    /// Called on: load from path
    @Signal var designReset: SimpleSignal
    /// Called on: accept, undo, redo
    @Signal var designChanged: SignalWithArguments<Bool>
    
    @Signal var simulationStarted: SimpleSignal
    @Signal var simulationFailed: SimpleSignal
    @Signal var simulationFinished: SignalWithArguments<PoieticResult>
    
    required init(_ context: InitContext) {
        self.design = Design(metamodel: StockFlowMetamodel)
        self.checker = ConstraintChecker(design.metamodel)
        self.selectionManager = SelectionManager()
        
        super.init(context)
        
        let frame = self.design.createFrame()
        try! self.design.accept(frame, appendHistory: true)
    }
    
    @Callable(autoSnakeCase: true)
    func newDesign() {
        self.design = Design(metamodel: StockFlowMetamodel)
        self.checker = ConstraintChecker(design.metamodel)
        let frame = self.design.createFrame()
        try! self.design.accept(frame, appendHistory: true)
        designChanged.emit(false)
    }
    
    // MARK: - Object Graph
    @Callable(autoSnakeCase: true)
    func getObject(_ rawID: EntityIDValue) -> PoieticObject? {
        let id = ObjectID(rawValue: rawID)
        guard let object = currentFrame[id] else { return nil }
        var wrapper = PoieticObject()
        wrapper.object = object
        return wrapper
    }
    
    func object(_ id: PoieticCore.ObjectID) -> ObjectSnapshot? {
        return self.currentFrame[id]
    }
   
    /// Get a list of object IDs that are of given object type.
    ///
    @Callable(autoSnakeCase: true)
    public func objectsOfType(typeName: String) -> PackedInt64Array {
        guard let type = design.metamodel.objectType(name: typeName) else {
            GD.pushError("Unknown object type '\(typeName)'")
            return PackedInt64Array()
        }
        let objects = currentFrame.filter { $0.type === type }
        let ids = objects.map { $0.objectID }
        return PackedInt64Array(compactingValid: ids)
    }
    
    /// Order given IDs by the given attribute in ascending order.
    ///
    /// Rules:
    /// - If the object does not have the given attribute, it is ordered last
    /// - Attribute-less objects are ordered by a value derived from their ID,
    ///   which is arbitrary but consistent within design.
    ///
    @Callable(autoSnakeCase: true)
    func vaguelyOrdered(ids: PackedInt64Array, orderAttribute: String) -> PackedInt64Array {
        // TODO: Make this method Frame.vaguelyOrdered(ids, orderAttribute:)
        var objects:[ObjectSnapshot] = ids.asValidEntityIDs().compactMap {
            currentFrame[$0]
        }
        if objects.count != ids.count {
            GD.pushError("Some IDs were not found in the frame")
        }
        objects.sort { (left, right) in
            switch (left[orderAttribute], right[orderAttribute]) {
            case let (.some(lvalue), .some(rvalue)):
                if let flag = lvalue.vaguelyInAscendingOrder(after: rvalue) {
                    return flag
                }
                else {
                    return left.objectID.rawValue < right.objectID.rawValue
                }
            case (.none, .some(_)): return false
            case (.some(_), .none): return true
            case (.none, .none):
                return left.objectID.rawValue < right.objectID.rawValue
            }
        }
        let ids = objects.compactMap { Int64(exactly: $0.objectID.rawValue) }

        return PackedInt64Array(ids)
    }
    
    // FIXME: Used only for charts, remove this
    @Callable
    func get_outgoing_ids(origin_id: UInt64, type_name: String) -> PackedInt64Array {
        let origin_id = PoieticCore.ObjectID(rawValue: origin_id)
        
        guard let type = design.metamodel.objectType(name: type_name) else {
            GD.pushError("Unknown object type '\(type_name)'")
            return PackedInt64Array()
        }
        
        let objects = currentFrame.outgoing(origin_id).filter { $0.object.type === type }
        let ids = objects.compactMap { Int64(exactly: $0.key.rawValue) }
        return PackedInt64Array(ids)
    }
    
    // MARK: - Special Objects
    @Callable
    func get_diagram_settings() -> GDictionary? {
        guard let frame = design.frame(name: DesignController.DesignSettingsFrameName),
              let obj = frame.first(type: .DiagramSettings)
        else { return nil }
        
        return GDictionary(obj.attributes)
    }
    @Callable
    func set_diagram_settings(settings: GDictionary) {
        let original = design.frame(name: DesignController.DesignSettingsFrameName)
        let trans = design.createFrame(deriving: original)
        let mut: TransientObject
        if let obj = trans.first(type: .DiagramSettings) {
            mut = trans.mutate(obj.objectID)
        }
        else {
            mut = trans.create(.DiagramSettings)
        }
        
        for (attr, value) in settings.asLossyPoieticAttributes() {
            mut[attr] = value
        }
        do {
            try design.accept(trans, replacingName: DesignController.DesignSettingsFrameName)
        }
        catch /* StructuralIntegrityError */ {
            GD.pushError("Structural integrity error")
            return
        }
    }
    
    /// Get special singleton object with system-defined name.
    ///
    /// Known names and their properties:
    ///     - `DesignInfo`
    ///         - `title`
    ///         - `author`
    ///         - `abstract`
    ///         - `documentation`
    ///         - `license`
    ///     - `Simulation`
    ///         - `initial_time`
    ///         - `time_delta`
    ///         - `end_time`
    ///
    @Callable(autoSnakeCase: true)
    func getSpecialObject(name: String) -> PoieticObject? {
        let object: ObjectSnapshot?
        switch name {
        case "DesignInfo":
            object = currentFrame.filter(type: ObjectType.DesignInfo).first
        case "Simulation":
            object = currentFrame.filter(type: ObjectType.Simulation).first
        default:
            return nil
        }
        guard let object else { return nil }
        var result = PoieticObject()
        result.object = object
        return result
    }
    
    // TODO: Deprecate in favour of "getSpecialObject"
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
    
    func newTransaction() -> TransientFrame {
        return design.createFrame(deriving: design.currentFrame)
    }
    
    @Callable
    func discard(transaction: PoieticTransaction) {
        guard let frame = transaction.frame else {
            GD.pushError("Using design without a frame")
            return
        }
        design.discard(frame)
        
    }
    func discard(_ frame: TransientFrame) {
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
        
        designChanged.emit(self.hasIssues())
        
        // TODO: Simulate only when there are simulation-related changes.
        // Simulate
        if self.simulationPlan != nil {
            simulate()
        }
    }
    
    
    // MARK: - Issues
    @Callable(autoSnakeCase: true)
    func hasIssues() -> Bool {
        guard let issues else { return false }
        return !issues.isEmpty
    }
    
    @Callable(autoSnakeCase: true)
    func issuesForObject(rawID: EntityIDValue) -> TypedArray<PoieticIssue?> {
        let id = PoieticCore.ObjectID(rawValue: rawID)
        // FIXME: Replace with runtime component
        guard let issues,
              let objectIssues = issues.objectIssues[id] else { return [] }
        
        let result =  objectIssues.map {
            let issue = PoieticIssue()
            issue.issue = $0
            return issue
        }
        return TypedArray(result)
    }
    
    @Callable(autoSnakeCase: true)
    func objectHasIssues(rawID: EntityIDValue) -> Bool {
        let id = PoieticCore.ObjectID(rawValue: rawID)
        guard let issues,
              let objectIssues = issues[id] else { return false }
        return !objectIssues.isEmpty
    }
    
    @Callable(autoSnakeCase: true)
    func canConnect(typeName: String, origin: EntityIDValue, target: EntityIDValue) -> Bool {
        let originID = PoieticCore.ObjectID(rawValue: origin)
        let targetID = PoieticCore.ObjectID(rawValue: target)
        guard currentFrame.contains(originID) && currentFrame.contains(targetID) else {
            return false
        }
        guard let type = _metamodel.objectType(name: typeName) else {
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
    
    @Callable(autoSnakeCase: true)
    func getDistinctValues(ids: PackedInt64Array, attribute: String) -> SwiftGodot.VariantArray {
        // FIXME: Use array not selection
        guard let frame = design.currentFrame else { return VariantArray() }
        let validIDs: [PoieticCore.ObjectID] = ids.asValidEntityIDs()
        let contained = frame.existing(from: validIDs)
        let values = frame.distinctAttribute(attribute, ids: contained)
        var result = SwiftGodot.VariantArray()
        
        for value in values {
            result.append(value.asGodotVariant())
        }
        return result
    }
    
    @Callable(autoSnakeCase: true)
    func getDistinctTypes(ids: PackedInt64Array) -> [String] {
        guard let frame = design.currentFrame else { return [] }
        let validIDs: [PoieticCore.ObjectID] = ids.asValidEntityIDs()
        let contained = frame.existing(from: validIDs)
        let types = frame.distinctTypes(contained)
        return types.map { $0.name }
    }
    
    @Callable(autoSnakeCase: true)
    func getSharedTraits(ids: PackedInt64Array) -> [String] {
        guard let frame = design.currentFrame else { return [] }
        let validIDs: [PoieticCore.ObjectID] = ids.asValidEntityIDs()
        let contained = frame.existing(from: validIDs)
        let traits = frame.sharedTraits(contained)
        return traits.map { $0.name }
    }
    // MARK: - Design Graph Transformations
    
    @Callable
    func auto_connect_parameters(ids: PackedInt64Array) {
        guard let validated = validatedFrame else {
            GD.pushError("Using design without a frame")
            return
        }
        
        let ids: [PoieticCore.ObjectID] = ids.asValidEntityIDs()
        let view = StockFlowView(validated)
        let nodes: [ObjectSnapshot]
        if ids.isEmpty {
            nodes = view.simulationNodes
        }
        else {
            nodes = ids.compactMap { validated[$0] }
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
        let store = DesignStore(url: url)
        do {
            let design = try store.load(metamodel: StockFlowMetamodel)
            self.design = design
        }
        catch {
            // TODO: Handle various load errors (as in ToolEnvironment of poietic-tool package)
            GD.pushError("Unable to open design: \(error)")
            return
        }
        designReset.emit()
        validateAndCompile()
    }
    
    @Callable
    func save_to_path(path: String) {
        let url = URL(fileURLWithPath: path)
        let store = DesignStore(url: url)
        do {
            try store.save(design: design)
        }
        catch {
            GD.pushError("Unable to save design: \(error)")
        }
    }
    
    @Callable(autoSnakeCase: true)
    func exportSVGDiagram(path: String, canvasController: CanvasController) {
        // TODO: Make composer configurable
        guard let composer = canvasController.composer else {
            GD.pushError("No composer")
            return
        }
        let diagram = composer.createDiagram(from: currentFrame)
        // TODO: Configure SVG export style
        let exporter = SVGDiagramExporter()
        do {
            try exporter.export(diagram: diagram, to: path)
        }
        catch {
            GD.pushError("Export to SVG failed:", error.localizedDescription)
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
        
        let trans: TransientFrame = design.createFrame(deriving: design.currentFrame)
        
        // 1. Read
        GD.print("Importing from \(path)")
        let reader = JSONDesignReader(variantCoding: .dictionaryWithFallback)
        let rawDesign: RawDesign
        
        do {
            rawDesign = try reader.read(fileAtURL: url)
        }
        catch {
            GD.printErr("Unable to read frame '\(path)': \(error)")
            return false
        }
        
        // 2. Load
        let loader = DesignLoader(metamodel: StockFlowMetamodel, options: .useIDAsNameAttribute)
        do {
            // FIXME: [WIP] add which frame to load
            try loader.load(rawDesign, into: trans)
        }
        catch {
            // TODO: Propagate error to the user
            GD.printErr("Unable to load frame \(path): \(error)")
            return false
        }
        
        accept(trans)
        return true
    }
    
    @Callable
    func import_from_data(data: PackedByteArray) -> Bool {
        let nativeData: Data = Data(data)
        let trans: TransientFrame = design.createFrame(deriving: design.currentFrame)
        
        // 1. Read
        GD.print("Importing from data")
        let reader = JSONDesignReader(variantCoding: .dictionaryWithFallback)
        let rawDesign: RawDesign
        
        do {
            rawDesign = try reader.read(data: nativeData)
        }
        catch {
            GD.printErr("Unable to read frame from data: \(error)")
            return false
        }
        
        // 2. Load
        let loader = DesignLoader(metamodel: StockFlowMetamodel, options: .useIDAsNameAttribute)
        do {
            // FIXME: add which frame to load
            try loader.load(rawDesign, into: trans)
        }
        catch {
            // TODO: Propagate error to the user
            GD.printErr("Unable to load frame from data: \(error)")
            return false
        }
        
        accept(trans)
        return true
        return true
    }
    
    /// Extract textual serialised representation of selected objects.
    ///
    /// The extracted representation is encoded as JSON.
    ///
    /// Use this method to implement copy/cut functionality.
    ///
    /// - SeeAlso: ``deleteSelection()``, ``pasteFromText(text:)``
    ///
    @Callable(autoSnakeCase: true)
    public func copySelectionAsText() -> String {
        let ids = selectionManager.selection.ids
        let extractor = DesignExtractor()
        let extract = extractor.extractPruning(objects: ids,
                                               frame: self.currentFrame)
        var rawDesign = RawDesign(metamodelName: design.metamodel.name,
                                  metamodelVersion: design.metamodel.version,
                                  snapshots: extract)
        
        let writer = JSONDesignWriter()
        guard let text: String = writer.write(rawDesign) else {
            GD.printErr("Unable to get textual representation for pasteboard")
            return ""
        }
        return text
    }
    
    /// Paste JSON-encoded objects into the design.
    ///
    /// - Returns: `true` when paste was successful, `false` when paste failed.
    ///
    @Callable(autoSnakeCase: true)
    public func pasteFromText(text: String) -> Bool {
        guard let data = text.data(using: .utf8) else {
            GD.pushError("Can not get data from text")
            return false
        }
        let reader = JSONDesignReader()
        let rawDesign: RawDesign
        do {
            rawDesign = try reader.read(data: data)
        }
        catch {
            GD.pushError("Unable to paste: \(error)")
            return false
        }
        let loader = DesignLoader(metamodel: self._metamodel)
        let ids: [PoieticCore.ObjectID]

        let trans = self.newTransaction()
        do {
            ids = try loader.load(rawDesign,
                                  into: trans,
                                  identityStrategy: .preserveOrCreate)
        }
        catch {
            GD.pushError("Unable to paste: \(error)")
            self.discard(trans)
            return false
        }

        self.accept(trans)
        selectionManager.replaceAll(ids)
        return true
    }
    
    /// Delete selected objects and its dependents.
    ///
    @Callable(autoSnakeCase: true)
    public func deleteSelection() {
        let ids = selectionManager.selection.ids
        deleteObjects(ids)
        selectionManager.clear()
    }
        
    /// Delete selected objects and its dependents.
    ///
    @Callable(autoSnakeCase: true)
    public func removeConnectorMidpointsInSelection() {
        // TODO: Make this a command
        let trans = self.newTransaction()
        let ids = selectionManager.selection.ids

        for id in ids {
            guard trans.contains(id) else { continue }
            let obj = trans.mutate(id)
            guard obj.type.hasTrait(.DiagramConnector) else { continue }
            obj.removeAttribute(forKey: "midpoints")
        }
        self.accept(trans)
        selectionManager.clear()
    }

    @Export var debug_stats: GDictionary {
        get {
            var dict = GDictionary()
            if let frame = design.currentFrame {
                dict["current_frame"] = SwiftGodot.Variant(frame.id.stringValue)
                dict["nodes"] = SwiftGodot.Variant(frame.nodes.count)
                dict["edges"] = SwiftGodot.Variant(frame.edges.count)
                dict["diagram_blocks"] = SwiftGodot.Variant(frame.filter(trait: .DiagramBlock).count)
                dict["edges"] = SwiftGodot.Variant(frame.edges.count)
            }
            else {
                dict["current_frame"] = SwiftGodot.Variant("none")
                dict["nodes"] = SwiftGodot.Variant(0)
                dict["diagram_blocks"] = SwiftGodot.Variant(0)
                dict["edges"] = SwiftGodot.Variant(0)
            }
            dict["frames"] = SwiftGodot.Variant(design.frames.count)
            dict["undo_frames"] = SwiftGodot.Variant(design.undoList.count)
            dict["redo_frames"] = SwiftGodot.Variant(design.redoList.count)
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
    
    // MARK: - Metamodel Queries

    /// Get names of object types that can be placed on the diagram.
    ///
    /// Returns types that have the `DiagramBlock` trait, which indicates they can be
    /// visually represented as blocks on the canvas.
    ///
    /// - Returns: Array of type names suitable for diagram placement
    ///
    @Callable(autoSnakeCase: true)
    func getPlaceablePictogramNames() -> PackedStringArray {
        let types = design.metamodel.types.filter { $0.hasTrait(.DiagramBlock) }
        return PackedStringArray(types.map { $0.name })
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
        
        simulationStarted.emit()
        
        do {
            try simulator.initializeState()
        }
        catch {
            GD.pushError("Simulation initialisation failed: \(error)")
            simulationFailed.emit()
            return
        }
        
        do {
            try simulator.run()
        }
        catch {
            GD.pushError("Simulation failed at step \(simulator.currentStep): \(error)")
            simulationFailed.emit()
            return
        }
        
        self.result = simulator.result
        let wrap = PoieticResult()
        wrap.set(plan: simulationPlan, result: simulator.result)
        simulationFinished.emit(wrap)
    }
    
    @Callable
    func write_to_csv(path: String, result: PoieticResult, ids: PackedInt64Array) {
        guard let plan = result.plan else {
            GD.pushError("No simulation plan for result export")
            return
        }
        guard let result = result.result else {
            GD.pushError("No simulation result to export")
            return
        }

        do {
            let actualIDs: [PoieticCore.ObjectID] = ids.asValidEntityIDs()
            try writeToCSV(path: path, result: result, plan: plan, ids: actualIDs)
        }
        catch {
            // TODO: Handle error gracefuly
            GD.pushError("Unable to write to '\(path)'. Reason: \(error)")
            return
        }
    }
    
    func writeToCSV(path: String,
                    result: SimulationResult,
                    plan: SimulationPlan,
                    ids: [PoieticCore.ObjectID]) throws {
        var variableIndices: [Int] = []
        variableIndices.append(plan.builtins.step)
        variableIndices.append(plan.builtins.time)
        
        if ids.isEmpty {
            variableIndices += Array(plan.stateVariables.indices)
        }
        else {
            variableIndices += ids.compactMap { plan.variableIndex(of: $0) }
        }

        let writer: CSVWriter = try CSVWriter(path: path)
        let header: [String] = variableIndices.map { plan.stateVariables[$0].name }

        try writer.write(row: header)
        
        for state in result.states {
            var row: [String] = []
            for index in variableIndices {
                let value: PoieticCore.Variant = state[index]
                row.append(try value.stringValue())
            }
            try writer.write(row: row)
            
        }
        try writer.close()
    }
   
    // MARK: - Actions
    // TODO: Move towards this, review other methods
    /// Delete objects in current frame.
    ///
    func deleteObjects(_ ids: [PoieticCore.ObjectID]) {
        let trans = self.newTransaction()
        let existing = trans.existing(from: ids)
        for id in existing {
            trans.removeCascading(id)
        }
        self.accept(trans)
    }
}
