//
//  CanvasController.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 26/08/2025.
//

import SwiftGodot
import PoieticCore
import PoieticFlows
import Diagramming
import Foundation

// FIXME: There is confusion between Diagramming.DiagramStyle and our DiagramStyle. Resolve that.

/// Canvas Controller synchronises design with canvas.
///
/// Responsibilities:
///
/// - Synchronisation of design with canvas: create and update canvas objects, their visuals based
///   on state of the design.
/// - Creates and manages temporary visuals, such as new connectors.
/// - Facilitates inline editing.
/// - (TODO) Manages selection
///
@Godot
public class CanvasController: SwiftGodot.Node {
    // TODO: Move selection management here
    /// Canvas scene node that the controller manages and synchronises diagrammatic representation
    /// of a design.
    @Export public var canvas: DiagramCanvas?
    /// Controller of a design that is composed as a diagram on canvas.
    @Export public var designController: DesignController?
    var composer: DiagramComposer?
    
    internal var notation: Notation?
    // TODO: Update visuals on style change
    @Export public var style: CanvasStyle?
    @Export public var contextMenu: SwiftGodot.Control?
    var inlineEditors: [String:SwiftGodot.Control] = [:]
    
    @Export public var issuesPopup: SwiftGodot.Control?
    
    /// A control that is shown alongside a node, such as inline editor or issue list.
    @Export var inlinePopup: SwiftGodot.Control?
    
    var pictograms: PictogramCollection?

    var visualsUpdateSystems: SystemGroup

    let previewPipeline: SystemGroup
    var requireUpdatePreview: Bool = false
    // MARK: - Initialisation
    //
    required init(_ context: InitContext) {
        // TODO: Find a better place for this
        self.previewPipeline = SystemGroup(SystemConfiguration.DraggingPreview)
        super.init(context)
    }
    
    override public func _process(delta: Double) {
        guard let runtime = designController?.runtimeFrame else { return }
        if requireUpdatePreview {
            do {
                try self.previewPipeline.update(runtime)
            }
            catch {
                GD.pushError("Preview update failed: \(error)")
            }
            requireUpdatePreview = false
        }
    }
    public func queueUpdatePreview() {
        requireUpdatePreview = true
    }
    @Callable
    func initialize(designController: DesignController, canvas: DiagramCanvas) {
        self.designController = designController
        self.canvas = canvas
        
        loadPictograms(path: StockFlowPictogramsPath)
        
        designController.designChanged.connect(self.on_design_changed)
        designController.selectionManager.selectionChanged.connect(self.on_selection_changed)
    }
    
    @Callable(autoSnakeCase: true)
    func loadPictograms(path: String) {
        // TODO: Use Godot resource loading mechanism here
        let gData: PackedByteArray = FileAccess.getFileAsBytes(path: path)
        let data: Data = Data(gData)
        let decoder = JSONDecoder()
        let collection: PictogramCollection
        
        do {
            collection = try decoder.decode(PictogramCollection.self, from: data)
        }
        catch {
            GD.pushError("Unable to load pictograms from: \(StockFlowPictogramsPath). Reason: \(error)")
            collection = PictogramCollection()
        }
        if collection.pictograms.isEmpty {
            GD.pushWarning("No pictograms found (empty collection)")
        }
        else {
            let names = collection.pictograms.map { $0.name }.joined(separator: ",")
        }
        
        // FIXME: Remove once happy with the whole pictogram and diagram composition pipeline
        let scaled = collection.pictograms.map { $0.scaled(PrototypingPictogramAdjustmentScale) }
        
        let notation = Diagramming.Notation(
            pictograms: scaled,
            defaultPictogramName: "Unknown",
            connectorGlyphs: DefaultStockFlowConnectorGlyphs,
            defaultConnectorGlyphName: "default"
        )
        setNotation(notation)
    }
    
    func setNotation(_ notation: Notation) {
        guard let runtime = designController?.runtimeFrame else { return }
        runtime.setComponent(notation, for: .Frame)
        self.queueUpdatePreview()
    }
    
    // MARK: - Signal Handling
    @Callable
    func on_design_changed(hasIssued: Bool) {
        guard let frame = designController?.currentFrame else {
            GD.pushError("No current frame in design controller for diagram controller")
            return
        }
        self.queueUpdatePreview()
    }
    
    // MARK: - Selection
    @Callable(autoSnakeCase: true)
    func getSingleSelectionObject() -> PoieticObject? {
        guard let designController,
              designController.selectionManager.selection.count == 1,
              let id = designController.selectionManager.selection.first
        else {
            return nil
        }
        return designController.getObject(id.rawValue)
    }
    
    @Callable(autoSnakeCase: true)
    func deleteSelection() {
        guard let ctrl = designController else { return }
        let trans = ctrl.newTransaction()
        
        for id in ctrl.selectionManager.selection {
            guard trans.contains(id) else {
                GD.pushWarning("Selection has unknown ID:", id)
                continue
            }
            trans.removeCascading(id)
        }
        ctrl.accept(trans)
    }
    
    @Callable(autoSnakeCase: true)
    func removeMidpointsInSelection() {
        guard let ctrl = designController else { return }
        let trans = ctrl.newTransaction()
        
        for id in ctrl.selectionManager.selection {
            guard let obj = trans[id] else {
                GD.pushWarning("Selection has unknown ID:", id)
                continue
            }
            guard obj.type.hasTrait(.DiagramConnector) else {
                continue
            }
            let transObject = trans.mutate(id)
            transObject.removeAttribute(forKey: "midpoints")
        }
        ctrl.accept(trans)
    }
    
    // MARK: - Actions (basic)
    //
    @Callable
    func on_selection_changed(_ manager: SelectionManager) {
        guard let canvas else { return }
        let selected: Set<PoieticCore.ObjectID> = Set(manager.selection)
        for child in canvas.getChildren() {
            guard var child = child as? DiagramCanvasObject,
                  let objectID = child.objectID else { continue }
            let isSelected = selected.contains(objectID)
            child.isSelected = isSelected
            if let child = child as? DiagramCanvasConnector {
                child.handlesVisible = isSelected
            }
        }
    }
    
    /// Select all objects in the canvas
    @Callable(autoSnakeCase: true)
    public func selectAll() {
        guard let canvas else { return }
        guard let manager = designController?.selectionManager else { return }
        let ids = canvas.selectableObjectIDs()
        manager.replaceAll(ids)
    }
    
    @Callable(autoSnakeCase: true)
    func clearCanvas() {
        canvas?.clear()
        designController?.selectionManager.clear()
    }
    
   // MARK: - Value Indicators
    // Update indicators from the player.
    //
    // This method is typically called on simulation player step.
    @Callable(autoSnakeCase: true)
    func updateIndicatorValues(player: ResultPlayer) {
        // FIXME: [PORTING] Requires attention after porting from Godot
        guard let designController,
              let canvas
        else { return }
        
        for block in canvas.blocks {
            guard let id = block.objectID?.rawValue else { continue }
            guard let value = player.numericValue(rawObjectID: id) else { continue }
            block.displayValue = value
        }
    }

    // Remove values from indicators
    //
    // This method is called when design fails validation or when the simulation fails.
    //
    @Callable(autoSnakeCase: true)
    func clearIndicators() {
        // FIXME: [PORTING] Requires attention after porting from Godot
        guard let canvas else { return }
        for block in canvas.blocks {
            guard let id = block.objectID else { continue }
            block.displayValue = nil
        }
    }

    // Synchronize indicators based on a simulation result.
    //
    // The method sets initial value of indicators and sets indicator range from the
    // simulation result (time series).
    //
    // This method is typically called on design change.
    //
    @Callable(autoSnakeCase: true)
    func syncIndicators(result: PoieticResult) {
        // FIXME: [PORTING] Requires attention after porting from Godot
        guard let canvas,
              let designController else { return }
        
        for block in canvas.blocks {
            guard block.hasValueIndicator, // Whether we *should* have the indicator
                  let valueIndicator = block.valueIndicator, // Whether we actually have it
                  let id = block.objectID,
                  let object = designController.currentFrame[id]
            else { continue }

            guard let series = result.timeSeries(id: id.rawValue) else {
                continue
            }
            let autoscaleFlag: Bool? = object["display_value_auto_scale"]

            // TODO: Rename to display_value_min, max, baseline (see poietic-flows metamodel)
            let rangeMin: Double? = object["indicator_min_value"]
            let rangeMax: Double? = object["indicator_max_value"]
            let baseline: Double? = object["indicator_mid_value"]

            let coalescedMin = coalesceRangeValue(requestedValue: rangeMin,
                                                  autoValue: series.data_min,
                                                  defaultValue: ValueIndicatorRangeMinDefault,
                                                  autoScale: autoscaleFlag)
            let coalescedMax = coalesceRangeValue(requestedValue: rangeMax,
                                                  autoValue: series.data_max,
                                                  defaultValue: ValueIndicatorRangeMaxDefault,
                                                  autoScale: autoscaleFlag)
            valueIndicator.baseline = coalesceRangeValue(requestedValue: baseline,
                                                         autoValue: series.data_min,
                                                         defaultValue: coalescedMin,
                                                         autoScale: autoscaleFlag)

            // Safety range bounds swap
            valueIndicator.rangeMin = min(coalescedMin, coalescedMax)
            valueIndicator.rangeMax = max(coalescedMin, coalescedMax)
            // Clamp baseline within bounds
            valueIndicator.baseline = max(min(valueIndicator.baseline, valueIndicator.rangeMax), valueIndicator.rangeMin)
            
            block.displayValue = series.first
        }
    }

    func coalesceRangeValue(requestedValue: Double?, autoValue: Double, defaultValue: Double, autoScale: Bool?) -> Double {
        switch (requestedValue, autoScale) {
        case (.none,            .none):        defaultValue
        case (.none,            .some(false)): defaultValue
        case (.none,            .some(true)):  autoValue
        case (.some(let value), .none):        value
        case (.some(let value), .some(false)): value
        case (.some(_),         .some(true)):  autoValue
        }
    }
    
    
    public func moveSelection(_ selection: Selection, by designDelta: Vector2D) {
        guard let ctrl = designController else { return }
        let trans = ctrl.newTransaction()
        
        for id in selection {
            guard trans.contains(id) else {
                GD.pushWarning("Selection has unknown ID:", id)
                continue
            }
            let object = trans.mutate(id)
            _moveObject(object, by: designDelta)
        }
        
        ctrl.accept(trans)
    }
    
    public func _moveObject(_ object: TransientObject, by designDelta: Vector2D) {
        if object.type.hasTrait(.DiagramBlock) {
            object.position = (object.position ?? .zero) + designDelta
        }
        else if object.type.hasTrait(.DiagramConnector) {
            guard let midpoints: [Point] = object["midpoints"] else { return }
            guard !midpoints.isEmpty else { return }
            
            let movedMidpoints = midpoints.map {
                $0 + designDelta
            }
            object["midpoints"] = PoieticCore.Variant(movedMidpoints)
        }
    }
    
    public func setMidpoints(object id: PoieticCore.ObjectID, midpoints: [Vector2D]) {
        guard let ctrl = designController else { return }
        let trans = ctrl.newTransaction()
        
        guard trans.contains(id) else {
            GD.pushWarning("Unknown ID: \(id)")
            ctrl.discard(trans)
            return
        }
        let object = trans.mutate(id)
        object["midpoints"] = PoieticCore.Variant(midpoints)
        
        ctrl.accept(trans)
    }
    
    // MARK: - Inline Editors and Pop-ups
    //
    @Callable(autoSnakeCase: true)
    func registerInlineEditor(name: String, editor: SwiftGodot.Control) {
        guard inlineEditors[name] == nil else {
            GD.pushError("Inline editor '\(name)' already registered")
            return
        }
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
        
        inlineEditors[name] = editor
    }
    
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
    func openIssuesPopup(_ rawObjectID: EntityIDValue) {
        guard let designController,
              let issuesPopup,
              let canvas,
              let block = canvas.representedBlock(rawID: rawObjectID)
        else { return }
        guard issuesPopup.hasMethod("set_issues") else {
            GD.pushError("Invalid issues popup node: set_issues method missing")
            return
        }

        let issues = designController.issuesForObject(rawID: rawObjectID)
        issuesPopup.call(method: "set_issues",
                         SwiftGodot.Variant(rawObjectID),
                         SwiftGodot.Variant(issues))

        let position: Vector2
        if let indicator =  block.issueIndicator {
            position = indicator.globalPosition
        }
        else {
            position = canvas.promptPosition(for: rawObjectID)
        }
        openInlinePopup(control: issuesPopup, position: position)
    }
    
    @Callable(autoSnakeCase: true)
    func openInlineEditor(_ editorName: String,
                          rawObjectID: EntityIDValue,
                          attribute: String) {
        let objectID = PoieticCore.ObjectID(rawValue: rawObjectID)
        // TODO: Allow editing of not-yet-existing objects, such as freshly placed block
        guard let canvas,
              let designController,
              let editor = inlineEditor(editorName)
        else { return }
        guard let object = designController.currentFrame[objectID] else
        {
            GD.pushError("No object '\(objectID)' for inline editor")
            return
        }
        let value = object[attribute]
        var position = canvas.promptPosition(for: rawObjectID)
        openInlinePopup(control: editor, position: position)
        
        var godotObject = PoieticObject()
        godotObject.object = object
        
        editor.call(method: "open",
                    SwiftGodot.Variant(godotObject),
                    SwiftGodot.Variant(attribute),
                    value?.asGodotVariant())
        self.inlinePopup = editor
    }
    
    @Callable(autoSnakeCase: true)
    func openInlinePopup(control: SwiftGodot.Control, position: Vector2) {
        if let inlinePopup {
            closeInlinePopup()
        }
        let size = control.getSize()
        let adjustedPosition = Vector2(x: position.x - size.x / 2.0, y: position.y)
        control.setGlobalPosition(adjustedPosition)
        control.setProcess(enable: true)
        control.show()
        self.inlinePopup = control
    }
    
    @Callable(autoSnakeCase: true)
    func closeInlinePopup() {
        guard let inlinePopup else { return }
        if inlinePopup.hasMethod("close") {
            inlinePopup.call(method: "close")
        }
        inlinePopup.hide()
        inlinePopup.setProcess(enable: false)
        self.inlinePopup = nil
    }
    
    @Callable(autoSnakeCase: true)
    func commitNameEdit(rawObjectID: EntityIDValue, newValue: String) {
        let objectID = PoieticCore.ObjectID(rawValue: rawObjectID)
        guard let ctrl = designController,
              let canvas,
              let object = canvas.representedBlock(id: objectID),
              let block = object.block else { return }
        
        object.finishLabelEdit()
        
        guard block.label != newValue else { return } // Nothing changed
        
        var trans = ctrl.newTransaction()
        var obj = trans.mutate(objectID)
        obj["name"] = PoieticCore.Variant(newValue)
        ctrl.accept(trans)
    }
    
    @Callable(autoSnakeCase: true)
    func cancelNameEdit(rawObjectID: EntityIDValue) {
        let objectID = PoieticCore.ObjectID(rawValue: rawObjectID)
        guard let canvas,
              let object = canvas.representedBlock(id: objectID),
              let block = object.block else { return }
        object.finishLabelEdit()
    }
    
    @Callable(autoSnakeCase: true)
    func commitFormulaEdit(rawObjectID: EntityIDValue, newFormulaText: String) {
        let objectID = PoieticCore.ObjectID(rawValue: rawObjectID)
        guard let ctrl = designController,
              let object = ctrl.object(objectID) else { return }
        
        if (object["formula"] as? String) == newFormulaText {
            return // Attribute not changed
        }
        
        var trans = ctrl.newTransaction()
        var obj = trans.mutate(objectID)
        obj["formula"] = PoieticCore.Variant(newFormulaText)
        ctrl.accept(trans)
    }
   
    @Callable(autoSnakeCase: true)
    func commitGraphicalCurvesEdit(rawObjectID: EntityIDValue, points: PackedVector2Array, interpolationMethod: String) {
        let objectID = PoieticCore.ObjectID(rawValue: rawObjectID)
        guard let ctrl = designController,
              let object = ctrl.object(objectID) else { return }
        let convertedPoints = points.map { Point($0) }
        
        if (object["graphical_function_points"] as? [Point]) == convertedPoints
            && object["interpolation_method"] == interpolationMethod
        {
            return // Attribute not changed
        }
        
        var trans = ctrl.newTransaction()
        var obj = trans.mutate(objectID)
        obj["graphical_function_points"] = PoieticCore.Variant(convertedPoints)
        obj["interpolation_method"] = PoieticCore.Variant(interpolationMethod)
        ctrl.accept(trans)
    }

    @Callable(autoSnakeCase: true)
    func commitNumericAttributeEdit(rawObjectID: EntityIDValue, attribute: String, newTextValue: String) {
        let objectID = PoieticCore.ObjectID(rawValue: rawObjectID)
        guard let ctrl = designController,
              let object = ctrl.object(objectID) else { return }
        
        if let value = object[attribute], (try? value.stringValue()) == newTextValue
        {
            return // Attribute not changed
        }
        
        var trans = ctrl.newTransaction()
        var obj = trans.mutate(objectID)
        if obj.setNumericAttribute(attribute, fromString: newTextValue) {
            ctrl.accept(trans)
        }
        else {
            GD.pushWarning("Numeric attribute '",attribute,"' was not set: '", newTextValue, "'")
            ctrl.discard(trans)
        }
    }
    
    // MARK: - Pictogram UI Support
    //
    
    /// Get a Pictogram2D node for UI display (toolbar buttons, palettes).
    ///
    /// This method creates a `Pictogram2D` node that can be added as a child to UI controls
    /// like buttons. The node will be properly scaled and positioned to fit the specified size.
    ///
    /// - Parameters:
    ///   - typeName: Name of the object type whose pictogram to create
    ///   - size: Size to scale the pictogram to fit (default: 60)
    ///   - color: Color to render the pictogram (default: white)
    ///
    /// - Returns: Configured `Pictogram2D` node, or `nil` if pictogram not found
    ///
    /// - Note: The returned node should be added to the scene tree. The caller is responsible
    ///   for adding it as a child to an appropriate parent node.
    ///
    @Callable(autoSnakeCase: true)
    func getPictogramNode(typeName: String,
                          size: Int?,
                          color: SwiftGodot.Color?) -> Pictogram2D? {
        guard let pictogram = pictograms?.pictogram(typeName) else {
            GD.pushWarning("No pictogram for type: \(typeName)")
            return nil
        }

        let scaledPictogram: Pictogram
        if let targetSize = size {
            // Scale the curves to fit target size
            let bounds = pictogram.pathBoundingBox
            let maxDimension = max(bounds.width, bounds.height)
            guard maxDimension > 0 else {
                GD.pushWarning("Pictogram '\(typeName)' has zero size")
                return nil
            }

            let scaleFactor = Double(targetSize) / maxDimension
            scaledPictogram = pictogram.scaled(scaleFactor)
        } else {
            // Use original pictogram without scaling
            scaledPictogram = pictogram
        }

        // Create and configure Pictogram2D node
        let picto2d = Pictogram2D()
        picto2d.setPictogram(scaledPictogram)
        picto2d.color = color ?? PictogramIconColor
        picto2d.lineWidth = 2.0

        return picto2d
    }
}
