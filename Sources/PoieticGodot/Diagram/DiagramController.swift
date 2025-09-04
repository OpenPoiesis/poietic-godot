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
    
    required init(_ context: InitContext) {
        super.init(context)
    }
    
    @Callable
    func initialize(designController: DesignController, canvas: DiagramCanvas) {
        self.designController = designController
        self.canvas = canvas
        _loadPictograms()
        
        designController.designChanged.connect(self.on_design_changed)
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
    func sync_indicators(result: PoieticResult) {
        // FIXME: Implement this
        GD.pushWarning("Syncing indicators not yet re-implemented")
    }
    
    func updateCanvas(frame: StableFrame) {
        let style = DiagramStyle(
            pictograms: pictograms,
            connectorStyles: StockFlowConnectorStyles,
        )
        let presenter = DiagramPresenter(style: style)
        let diagram = presenter.createDiagram(from: frame)
        
        updateBlocks(diagram: diagram)
        updateConnectors(diagram: diagram)
    }
    
    func updateBlocks(diagram: Diagram) {
        guard let canvas else {
            GD.pushError("Diagram controller has no canvas")
            return
        }
        
        var existing: [PoieticCore.ObjectID:DiagramCanvasBlock] = [:]
        var updated: [DiagramCanvasBlock] = []
        
        for node in canvas.blocks {
            guard let id = node.objectID else { continue }
            existing[id] = node
        }
        
        for diagramObject in diagram.blocks {
            guard let objectID = diagramObject.objectID else { continue }
            let canvasNode: DiagramCanvasBlock
            if let node = existing[objectID] {
                canvasNode = node
                existing[objectID] = nil
            }
            else {
                canvasNode = DiagramCanvasBlock()
                canvas.addChild(node: canvasNode)
            }
            canvasNode.updateContent(from: diagramObject)
            updated.append(canvasNode)
        }
        canvas.blocks = updated
        
//        GD.print("--- Canvas blocks updated: \(updated.count), removed: \(existing.count)")
        for node in existing.values {
            node.queueFree()
        }
        
    }
    
    func updateConnectors(diagram: Diagram) {
        guard let canvas else {
            GD.pushError("Diagram controller has no canvas")
            return
        }
        
        var existing: [PoieticCore.ObjectID:DiagramCanvasConnector] = [:]
        var updated: [DiagramCanvasConnector] = []
        
        for node in canvas.connectors {
            guard let id = node.objectID else { continue }
            existing[id] = node
        }
        
        for diagramObject in diagram.connectors {
            guard let objectID = diagramObject.objectID else { continue }
            let canvasNode: DiagramCanvasConnector
            if let node = existing[objectID] {
                canvasNode = node
                existing[objectID] = nil
            }
            else {
                canvasNode = DiagramCanvasConnector()
                canvas.addChild(node: canvasNode)
            }
            canvasNode.updateContent(from: diagramObject)
            updated.append(canvasNode)
        }
        canvas.connectors = updated
//        GD.print("--- Canvas connectors updated: \(updated.count), removed: \(existing.count)")
        for node in existing.values {
            node.queueFree()
        }
        
    }
    
    
    // MARK: Prompt Editors
    // Label Editor
    @Callable
    func _on_label_edit_submitted(object_id: Int64, new_text: String) {
        guard let id = PoieticCore.ObjectID(object_id) else { return }
        guard let canvas else { return }
        guard let object = canvas.block(id: id) else { return }
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
        guard let object = canvas.block(id: id) else { return }
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
