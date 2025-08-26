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
public class PoieticDiagramController: SwiftGodot.Node {
    var designController: PoieticDesignController?
    var canvas: PoieticCanvas?
    var pictograms: PictogramCollection?

    required init(_ context: InitContext) {
        super.init(context)
    }

    @Callable
    func initialize(designController: PoieticDesignController, canvas: PoieticCanvas) {
        GD.print("==> Initializing diagram controller (NEW)")
        self.designController = designController
        self.canvas = canvas
        _loadPictograms()
        
        designController.designChanged.connect(self.on_design_changed)
        
        GD.print("<--- Done initalizing diagram controller")
    }
    
    func _loadPictograms() {
        GD.print("--- Loading pictograms (NEW)")
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
            GD.print("--! No pictograms loaded (empty collection)")
        }
        else {
            let names = collection.pictograms.map { $0.name }.joined(separator: ",")
            GD.print("--- Loaded pictograms: \(names)")
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
    
    func updateCanvas(frame: StableFrame) {
        GD.print("=== Updating new canvas")
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
        
        var existing: [PoieticCore.ObjectID:PoieticBlock] = [:]
        var updated: [PoieticBlock] = []
        
        for node in canvas.blocks {
            guard let id = node.objectID else { continue }
            existing[id] = node
        }

        for diagramObject in diagram.blocks {
            let canvasNode: PoieticBlock
            if let node = existing[diagramObject.objectID] {
                canvasNode = node
                existing[diagramObject.objectID] = nil
            }
            else {
                canvasNode = PoieticBlock()
                canvas.addChild(node: canvasNode)
            }
            canvasNode.updateContent(from: diagramObject)
            updated.append(canvasNode)
        }
        canvas.blocks = updated
        
        GD.print("--- Canvas blocks updated: \(updated.count), removed: \(existing.count)")
        for node in existing.values {
            node.queueFree()
        }

    }

    func updateConnectors(diagram: Diagram) {
        guard let canvas else {
            GD.pushError("Diagram controller has no canvas")
            return
        }
        
        var existing: [PoieticCore.ObjectID:PoieticConnector] = [:]
        var updated: [PoieticConnector] = []
        
        for node in canvas.connectors {
            guard let id = node.objectID else { continue }
            existing[id] = node
        }
        
        for diagramObject in diagram.connectors {
            let canvasNode: PoieticConnector
            if let node = existing[diagramObject.objectID] {
                canvasNode = node
                existing[diagramObject.objectID] = nil
            }
            else {
                canvasNode = PoieticConnector()
                canvas.addChild(node: canvasNode)
            }
            canvasNode.updateContent(from: diagramObject)
            updated.append(canvasNode)
        }
        canvas.connectors = updated
        GD.print("--- Canvas connectors updated: \(updated.count), removed: \(existing.count)")
        for node in existing.values {
            node.queueFree()
        }

    }

}
