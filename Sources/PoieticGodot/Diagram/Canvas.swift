//
//  DiagramCanvas.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 18/08/2025.
//

import SwiftGodot
import Diagramming
import PoieticCore

public let DiagramBlockNamePrefix: String = "block"
public let DiagramConnectorNamePrefix: String = "connector"

@Godot
public class DiagramCanvas: SwiftGodot.Node2D {
    static let ChartsVisibleZoomLevel: Float = 2.0
    static let FormulasVisibleZoomLevel: Float = 1.0
    @Signal var canvasViewChanged: SignalWithArguments<SwiftGodot.Vector2, Float>

    @Export var zoomLevel: Float = 1.0
    @Export var canvasOffset: SwiftGodot.Vector2 = .zero
    
    @Export var chartsVisible: Bool = false
    @Export var formulasVisible: Bool = false
    
    /// Prototype node that will be cloned to create value indicators.
    /// 
    @Export var valueIndicatorPrototype: ValueIndicator?
    
    // TODO: Move represented* to diagram controller
    /// Blocks that represent design nodes.
    ///
    /// Blocks representing design nodes have their `objectID` set to the object they represent.
    ///
    public var representedBlocks: [DiagramCanvasBlock] { Array(_representedBlocks.values) }
    private var _representedBlocks: [PoieticCore.ObjectID:DiagramCanvasBlock] = [:]
    /// Connectors that represent design edges.
    ///
    /// Connectors representing design nodes have their `objectID` set to the object they represent.
    ///
    public var representedConnectors: [DiagramCanvasConnector] { Array(_representedConnectors.values) }
    private var _representedConnectors: [PoieticCore.ObjectID:DiagramCanvasConnector] = [:]
   
    // - MARK: - Styling
    @Export var primaryLabelSettings: SwiftGodot.LabelSettings?
    @Export var secondaryLabelSettings: SwiftGodot.LabelSettings?
    @Export var invalidLabelSettings: SwiftGodot.LabelSettings?

    // - MARK: Content
    /// Get IDs of design objects represented within the canvas.
    ///
    /// Example use case of this method is to provide IDs for the _"Select all"`_ command.
    ///
    func representedObjectIDs() -> [PoieticCore.ObjectID] {
        return Array(_representedBlocks.keys) + Array(_representedConnectors.keys)
    }
    
    func currentTool() -> CanvasTool? {
        guard let app = getNode(path: NodePath(AppNodePath)) as? PoieticApplication else {
            GD.pushWarning("Unable to get app")
            return nil
        }
        return app.currentTool
    }
   
    func clear() {
        for child in getChildren() {
            guard let child = child as? DiagramCanvasObject else { continue }
            child.queueFree()
        }
        _representedBlocks.removeAll()
        _representedConnectors.removeAll()
    }

    /// Add a block that represents a design node. The block must have `ObjectID` set to a non-nil
    /// value. Existing block with the same ID will be replaced.
    ///
    public func insertRepresentedBlock(_ representedBlock: DiagramCanvasBlock) {
        guard let id = representedBlock.objectID else { return }
        
        if let existing = _representedBlocks[id] {
            removeChild(node: existing)
        }
        addChild(node: representedBlock)
        _representedBlocks[id] = representedBlock
    }
    public func removeRepresentedBlock(_ id: PoieticCore.ObjectID) {
        guard let object = _representedBlocks.removeValue(forKey: id) else {
            return
        }
        object.queueFree()
    }
    
    /// Get a block that represents a design object with given ID (typically a node).
    ///
    /// If no such block exists or the canvas object is of different type, then `null` is returned.
    ///
    @Callable(autoSnakeCase: true)
    public func representedBlock(rawID: EntityIDValue) -> DiagramCanvasBlock? {
        let id = PoieticCore.ObjectID(rawValue: rawID)
        return _representedBlocks[id]
    }
    
    public func representedBlock(id: PoieticCore.ObjectID) -> DiagramCanvasBlock? {
        return _representedBlocks[id]
    }

    public func insertRepresentedConnector(_ representedConnector: DiagramCanvasConnector) {
        guard let id = representedConnector.objectID else { return }
        
        if let existing = _representedConnectors[id] {
            removeChild(node: existing)
        }
        addChild(node: representedConnector)
        _representedConnectors[id] = representedConnector
    }
    public func removeRepresentedConnector(_ id: PoieticCore.ObjectID) {
        guard let object = _representedConnectors.removeValue(forKey: id) else {
            return
        }
        object.queueFree()
    }

    /// Get a connector that represents a design object with given ID (typically an edge).
    ///
    /// If no such connector exists or the canvas object is of different type, then `null` is returned.
    ///
    @Callable(autoSnakeCase: true)
    public func representedConnector(rawID: EntityIDValue) -> DiagramCanvasConnector? {
        let id = PoieticCore.ObjectID(rawValue: rawID)
        return _representedConnectors[id]
    }
    public func representedConnector(id: PoieticCore.ObjectID) -> DiagramCanvasConnector? {
        return _representedConnectors[id]
    }

    public override func _unhandledInput(event: SwiftGodot.InputEvent?) {
        guard let event else { return }
        switch event {
        case let event as InputEventPanGesture:
            canvasOffset += (-event.delta) * Double(zoomLevel * 10)
            updateCanvasView()
            self.getViewport()?.setInputAsHandled()
        case let event as InputEventMagnifyGesture:
            setZoom(level: Double(zoomLevel) * event.factor, keepPosition: getGlobalMousePosition())
            updateCanvasView()
            self.getViewport()?.setInputAsHandled()
        default:
            guard let tool = currentTool() else { break }
            // FIXME: Pass canvas as handle input parameter
            tool.canvas = self
            if tool.handleInput(event: event) {
                self.getViewport()?.setInputAsHandled()
            }
        }
    }
    
    @Callable(autoSnakeCase: true)
    func setZoom(level: Double, keepPosition: SwiftGodot.Vector2) {
        let scale = Vector2(x: zoomLevel, y: zoomLevel)
        let t_before = Transform2D().scaled(scale: scale).translated(offset: canvasOffset)
        let m_before = t_before.affineInverse() * keepPosition
        
        zoomLevel = Float(min(max(level, 0.1), 5.0))
        
        let scaleAfter = Vector2(x: zoomLevel, y: zoomLevel)
        var t_after = Transform2D().scaled(scale: scaleAfter).translated(offset: canvasOffset)
        var m_after = t_after.affineInverse() * keepPosition
        canvasOffset += -(m_before - m_after) * Double(zoomLevel)
    }
    @Callable(autoSnakeCase: true)
    public func updateCanvasView() {
        self.position = canvasOffset
        self.scale = Vector2(x: zoomLevel, y: zoomLevel)
        canvasViewChanged.emit(canvasOffset, zoomLevel)
        
        chartsVisible = zoomLevel > Self.ChartsVisibleZoomLevel
        formulasVisible = zoomLevel > Self.FormulasVisibleZoomLevel
    }
        
    /// Get a target wrapping a canvas item at given hit position.
    ///
    /// If you want to get only objects and ignore handles or indicators, then use
    /// ``hitObject(at:)``.
    ///
    @Callable(autoSnakeCase: true)
    public func hitTarget(globalPosition: SwiftGodot.Vector2) -> CanvasHitTarget? {
        var targets: [CanvasHitTarget] = []
        var children = self.getChildren()
        
        // TODO:  Need to sort by z-index. This is kind of arbitrary, we pretend this is an order of insertion.
        children.reverse()
        for child in children {
            guard let child = child as? DiagramCanvasObject else {
                continue
            }
            
            for handle in child.getHandles() where handle.visible {
                if handle.containsPoint(globalPoint: globalPosition) {
                    targets.append(CanvasHitTarget(object: child, type: .handle, tag: handle.tag))
                }
            }
            
            if let child = child as? DiagramCanvasBlock {
                if let indicator = child.issueIndicator as? CanvasIssueIndicator,
                   indicator.visible,
                   indicator.containsPoint(globalPoint: globalPosition)
                {
                    targets.append(CanvasHitTarget(object: child, type: .errorIndicator))
                }
                if let label = child.primaryLabel,
                   label.visible &&
                    label.getRect().hasPoint(child.toLocal(globalPoint: globalPosition))
                {
                    targets.append(CanvasHitTarget(object: child, type: .primaryLabel))
                }

                if let label = child.secondaryLabel,
                   label.visible &&
                    label.getRect().hasPoint(child.toLocal(globalPoint: globalPosition))
                {
                    targets.append(CanvasHitTarget(object: child, type: .secondaryLabel))
                }
            }

            if child.containsTouch(globalPoint: globalPosition) {
                targets.append(CanvasHitTarget(object: child, type: .object))
            }
        }
        
        if targets.isEmpty {
            return nil
        }
        else {
            return targets[0]
        }
    }
    
    /// Get a canvas object at given position.
    ///
    /// This method returns the first canvas object, ignoring handles and indicators, at the
    /// position ``hitPosition``.
    ///
    /// - SeeAlso: ``hitTarget(at:)``
    ///
    @Callable(autoSnakeCase: true)
    public func hitObject(globalPosition: SwiftGodot.Vector2) -> DiagramCanvasObject? {
        var targets: [CanvasHitTarget] = []
        var children = self.getChildren()
        
        // TODO:  Need to sort by z-index. This is kind of arbitrary, we pretend this is an order of insertion.
        children.reverse()
        for child in children {
            guard let child = child as? DiagramCanvasObject else {
                continue
            }
            
            if child.containsTouch(globalPoint: globalPosition) {
                return child
            }
        }
        
        return nil
    }

    @Callable(autoSnakeCase: true)
    func promptPosition(for rawID: EntityIDValue) -> Vector2 {
        let nodeID = PoieticCore.ObjectID(rawValue: rawID)
        guard let block = _representedBlocks[nodeID]
        else {
            return .zero
        }

        let position: Vector2
        if let primaryLabel = block.primaryLabel {
            return primaryLabel.getGlobalPosition()
        }
        else {
            return self.toGlobal(localPoint: block.position)
        }
    }

    
    // TODO: Observe how we are using it and adjust types accordingly
    // TODO: Add screen scaling (retina)
    /// Converts a point from canvas coordinates to design coordinates.
    func toDesign(canvasPoint: SwiftGodot.Vector2) -> Vector2D {
        let inDesign = canvasPoint / Double(zoomLevel)
        return Vector2D(inDesign)
    }
    /// Converts a point from design coordinates to canvas coordinates.
    func fromDesign(_ position: Vector2D) -> SwiftGodot.Vector2 {
        return position.asGodotVector2()
    }

    /// Default position where a pop-up is expected to be displayed around a given object.
    ///
    @Callable(autoSnakeCase: true)
    public func defaultPopupPosition(rawID: EntityIDValue) -> Vector2 {
        let objectID = PoieticCore.ObjectID(rawValue: rawID)
        if let block = _representedBlocks[objectID] {
            let y: Float
            if let label = block.primaryLabel {
                y = label.getGlobalPosition().y
            }
            else {
                y = block.globalPosition.y
            }
            return Vector2(x: block.globalPosition.x,y: y)
        }
        else if let connector = _representedConnectors[objectID] {
            // TODO: Compute some sensible position
            return .zero
        }
        else {
            return .zero
        }
    }

}

//struct DiagramBlockDisplayOptions: OptionSet {
//    typealias RawValue = UInt32
//    var rawValue: RawValue
//    init(rawValue: RawValue) {
//        self.rawValue = rawValue
//    }
//    
//    static let showPrimaryLabel    = DiagramBlockDisplayOptions(rawValue: 1 << 0)
//    static let showSecondaryLabel  = DiagramBlockDisplayOptions(rawValue: 1 << 1)
//    static let showValueIndicator  = DiagramBlockDisplayOptions(rawValue: 1 << 2)
//}


