//
//  DiagramController.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 26/08/2025.
//

import SwiftGodot
import PoieticCore
import Diagramming
import Foundation

@Godot
public class DiagramController: SwiftGodot.Node {
    // TODO: Rename to DiagramCanvasController
    @Export var canvas: DiagramCanvas?
    @Export var designController: DesignController?
    
    var pictograms: PictogramCollection?
    var composer: DiagramComposer?
    
    required init(_ context: InitContext) {
        super.init(context)
    }
    
    @Callable
    func initialize(designController: DesignController, canvas: DiagramCanvas) {
        self.designController = designController
        self.canvas = canvas
        _loadPictograms()
        
        let style = DiagramStyle(
            pictograms: pictograms,
            connectorStyles: StockFlowConnectorStyles,
        )
        self.composer = DiagramComposer(style: style)

        designController.designChanged.connect(self.on_design_changed)
        designController.selectionManager.selectionChanged.connect(self.on_selection_changed)
    }
    
    func _loadPictograms() {
        // TODO: Use Godot resource loading mechanism here
        let gData: PackedByteArray = FileAccess.getFileAsBytes(path: StockFlowPictogramsPath)
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
        
        self.pictograms = PictogramCollection(scaled)
    }
    
    @Callable
    func on_design_changed(hasIssued: Bool) {
        guard let frame = designController?.currentFrame else {
            GD.pushError("No current frame in design controller for diagram controller")
            return
        }
        updateCanvas(frame: frame)
    }
    
    @Callable
    func on_selection_changed(_ manager: SelectionManager) {
        guard let canvas else { return }
        let selected: Set<PoieticCore.ObjectID> = Set(manager.selection)
        for child in canvas.getChildren() {
            guard var child = child as? SelectableCanvasObject,
                  let objectID = child.objectID else { continue }
            child.isSelected = selected.contains(objectID)
        }
    }
    
    @Callable
    func sync_indicators(result: PoieticResult) {
        // FIXME: Implement this
        GD.pushWarning("Syncing indicators not yet re-implemented")
    }

    @Callable(autoSnakeCase: true)
    func clearCanvas() {
        canvas?.clear()
    }
    func updateCanvas(frame: StableFrame) {
        guard let composer else { return }

        let nodes = frame.nodes(withTrait: .DiagramBlock)
        syncDesignBlocks(nodes: nodes)

        let edges = frame.edges(withTrait: .DiagramConnector)
        syncDesignConnectors(edges: edges)
    }
    
    func syncDesignBlocks(nodes: [ObjectSnapshot]) {
        guard let canvas else { return }
        guard let composer else { return }

        var existing: Set<PoieticCore.ObjectID> = Set(canvas.representedBlocks.compactMap {
            $0.objectID
        })
        var updated: [DiagramCanvasBlock] = []
        
        for node in nodes {
            syncDesignBlock(node)
            existing.remove(node.objectID)
        }
        
        for id in existing {
            canvas.removeRepresentedBlock(id)
        }
    }
    
    func syncDesignBlock(_ node: ObjectSnapshot) {
        guard let canvas else { return }
        guard let composer else { return }

        if let object = canvas.representedBlock(id: node.objectID) {
            guard let block = object.block else { return } // Broken block
            composer.updateBlock(block: block, node: node)
            object.updateContent(from: block)
        }
        else {
            let object = DiagramCanvasBlock()
            object.objectID = node.objectID
            let block = composer.createBlock(node)
            canvas.insertRepresentedBlock(object)
            object.updateContent(from: block)
        }
    }
    
    func syncDesignConnectors(edges: [EdgeObject]) {
        guard let canvas else { return }
        guard let composer else { return }

        var existing: Set<PoieticCore.ObjectID> = Set(canvas.representedConnectors.compactMap {
            $0.objectID
        })
        var updated: [DiagramCanvasBlock] = []
        
        for edge in edges {
            syncDesignConnector(edge)
            existing.remove(edge.key)
        }
        
        for id in existing {
            canvas.removeRepresentedConnector(id)
        }
    }

    /// Synchronises a connector with an edge that it represents.
    ///
    /// Represented blocks the edge connects must exist in the canvas.
    func syncDesignConnector(_ edge: EdgeObject) {
        guard let canvas else { return }
        guard let composer else { return }
        guard let origin = canvas.representedBlock(id: edge.origin),
              let originBlock = origin.block,
              let target = canvas.representedBlock(id: edge.target),
              let targetBlock = target.block else
        {
            GD.pushError("Connector \(edge.key) is missing blocks")
            return // Broken connector
        }

        if let object = canvas.representedConnector(id: edge.key) {
            guard let connector = object.connector else { return }
            composer.updateConnector(connector: connector,
                                      edge: edge,
                                      origin: originBlock,
                                      target: targetBlock)
            object.updateContent(from: connector)
        }
        else {
            let object = DiagramCanvasConnector()
            object.objectID = edge.key
            object.originID = edge.origin
            object.targetID = edge.target
            let connector = composer.createConnector(edge,
                                                      origin: originBlock,
                                                      target: targetBlock)
            canvas.insertRepresentedConnector(object)
            object.updateContent(from: connector)
        }
    }
    /// Update connector during selection move session.
    ///
    func updateConnectorPreview(_ connector: DiagramCanvasConnector) {
        guard let canvas else { return }
        guard let composer else { return }
        guard let originID = connector.originID,
              let origin = canvas.representedBlock(id: originID),
              let originBlock = origin.block,
              let targetID = connector.targetID,
              let target = canvas.representedBlock(id: targetID),
              let targetBlock = target.block else
        {
            GD.pushError("Connector has broken blocks")
            return // Broken connector
        }
        guard let wrappedConnector = connector.connector else { return }
        composer.updateConnector(connector: wrappedConnector,
                                 origin: originBlock,
                                 target: targetBlock)
        connector.setDirty()
    }

    /// Create a connector originating in a block and ending at a given point, typically
    /// a mouse position.
    ///
    /// Use this to make a connector that is being created using a mouse pointer or by a touch.
    ///
    /// - SeeAlso: ``updateDragConnector(connector:origin:targetPoint:)``
    ///
    public func createDragConnector(type: String,
                             origin: DiagramCanvasBlock,
                             targetPoint: Vector2D) -> DiagramCanvasConnector? {
        guard let canvas else { return nil }
        guard let composer else { return nil }
        
        let result = DiagramCanvasConnector()

        let originPoint: Vector2D
        
        if let block = origin.block {
            originPoint = Connector.touchPoint(shape: block.collisionShape.shape,
                                               position: block.position + block.collisionShape.position,
                                               from: targetPoint,
                                               towards: block.position)
        }
        else {
            originPoint = Vector2D(origin.position)
        }
        
        let style = composer.connectorStyle(forType: type)
        let connector = Connector(originPoint: originPoint,
                                  targetPoint: targetPoint,
                                  midpoints: [],
                                  style: style)
        result.connector = connector
        canvas.addChild(node: result)
        return result
    }
    
    
    /// Update a connector originating in a block and ending at a given point, typically
    /// a mouse position.
    ///
    /// Use this to update a connector that is being created using a mouse pointer or by a touch.
    ///
    /// - SeeAlso: ``createDragConnector(type:origin:targetPoint:)``
    ///
    public func updateDragConnector(_ dragConnector: DiagramCanvasConnector,
                                    origin: DiagramCanvasBlock,
                                    targetPoint: Vector2D)
    {
        guard let canvas else { return }
        guard let composer else { return }
        guard dragConnector.connector != nil else { return }
        
        let originPoint: Vector2D
        
        if let block = origin.block {
            originPoint = Connector.touchPoint(shape: block.collisionShape.shape,
                                               position: block.position + block.collisionShape.position,
                                               from: targetPoint,
                                               towards: block.position)
        }
        else {
            originPoint = Vector2D(origin.position)
        }
        
        dragConnector.connector!.originPoint = originPoint
        dragConnector.connector!.targetPoint = targetPoint
        dragConnector.setDirty()
    }
    
    public func moveSelection(_ selection: Selection, by designDelta: Vector2D) {
        guard let ctrl = designController else { return }
        let trans = ctrl.newTransaction()

        for id in selection {
            guard trans.contains(id) else {
                GD.pushWarning("Selection has unknown ID: \(id)")
                continue
            }
            let object = trans.mutate(id)
            _moveObject(object, by: designDelta)
        }
        
    }
    
    public func _moveObject(_ object: TransientObject, by designDelta: Vector2D) {
        if object.type.hasTrait(.DiagramBlock) {
            object.position = (object.position ?? .zero) + designDelta
        }
        else if object.type.hasTrait(.DiagramConnector) {
            guard let midpoints = (try? object["midpoints"]?.pointArray()) else { return }
            guard !midpoints.isEmpty else { return }
            
            let movedMidpoints = midpoints.map {
                $0 + designDelta
            }
            object["midpoints"] = PoieticCore.Variant(movedMidpoints)
        }
    }

//    public func setMidpoints(_ objectID: ObjectID, midpoints: [Vector2D]) {
//        
//    }
    
    // MARK: Prompt Editors
    // Label Editor
    @Callable
    func _on_label_edit_submitted(object_id: Int64, new_text: String) {
        guard let id = PoieticCore.ObjectID(object_id) else { return }
        guard let canvas else { return }
        guard let object = canvas.representedBlock(id: id) else { return }
        guard let block = object.block else { return }
        guard let ctrl = designController else { return }
        
        object.finishLabelEdit()
        
        guard block.label != new_text else { return } // Nothing changed
            
        // TODO: Use primary label attribute
        var trans = ctrl.newTransaction()
        var obj = trans.mutate(id)
        obj["name"] = PoieticCore.Variant(new_text)
        ctrl.accept(trans)
    }

    @Callable
    func _on_label_edit_cancelled(object_id: Int64) {
        guard let id = PoieticCore.ObjectID(object_id) else { return }
        guard let canvas else { return }
        guard let object = canvas.representedBlock(id: id) else { return }
        object.finishLabelEdit()
    }

    // Formula Editor
    // ------------------------------------------------------------
    @Callable
    func _on_formula_edit_submitted(object_id: Int64, new_text: String) {
        guard let id = PoieticCore.ObjectID(object_id) else { return }
        guard let ctrl = designController else { return }
        guard let object = ctrl.getObject(id) else { return }

        if (try? object["formula"]?.stringValue()) == new_text {
            print("Formula not changed in ", object_id)
            return
        }
        var trans = ctrl.newTransaction()
        var obj = trans.mutate(id)
        obj["formula"] = PoieticCore.Variant(new_text)  
        ctrl.accept(trans)
    }

    @Callable
    func _on_formula_edit_cancelled(object_id: Int64) {
        // Do nothing
    }

    // Attribute Editor
    // ------------------------------------------------------------
    // TODO: Rename _on_numeric_attribute_...
    @Callable
    func _on_attribute_edit_submitted(object_id: Int64, attribute: String, new_text: String) {
        guard let id = PoieticCore.ObjectID(object_id) else { return }
        guard let ctrl = designController else { return }
        guard let object = ctrl.getObject(id) else { return }
        if let value = object[attribute], (try? value.stringValue()) == new_text
        {
            GD.print("Attribute ", attribute, " not changed in ", object_id)
            return
        }
        var trans = ctrl.newTransaction()
        var obj = trans.mutate(id)
        if obj.setNumericAttribute(attribute, fromString: new_text) {
            ctrl.accept(trans)
        }
        else {
            GD.pushWarning("Numeric attribute '",attribute,"' was not set: '", new_text, "'")
            ctrl.discard(trans)
        }
    }
    @Callable
    func _on_attribute_edit_cancelled(object_id: Int64) {
        // Do nothing
    }
}
