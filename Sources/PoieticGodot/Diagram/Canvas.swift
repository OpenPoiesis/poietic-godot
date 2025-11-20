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
public let BackgroundZIndex: Int32 = -1000

@Godot
public class DiagramCanvas: SwiftGodot.Node2D {
    static let ChartsVisibleZoomLevel: Float = 2.0
    static let FormulasVisibleZoomLevel: Float = 1.0
    @Signal var canvasViewChanged: SignalWithArguments<SwiftGodot.Vector2, Float>

    @Export var zoomLevel: Float = 1.0
    @Export var canvasOffset: SwiftGodot.Vector2 = .zero
    
    @Export var chartsVisible: Bool = false
    @Export var formulasVisible: Bool = false
    
    @Export var backgroundColor: Color {
        set(color) {
            background?.color = color
        }
        get {
            return background?.color ?? Color.white
        }
    }
    
    /// Prototype node that will be cloned to create value indicators.
    /// 
    @Export var valueIndicatorPrototype: ValueIndicator?
    
    @Export var background: SwiftGodot.ColorRect?
    
    // TODO: Move represented* to diagram controller
    /// Blocks that represent design nodes.
    ///
    /// Blocks representing design nodes have their `objectID` set to the object they represent.
    ///
    public var blocks: [DiagramCanvasBlock] { Array(_blocks.values) }
    private var _blocks: [RuntimeEntityID:DiagramCanvasBlock] = [:]
    /// Connectors that represent design edges.
    ///
    /// Connectors representing design nodes have their `objectID` set to the object they represent.
    ///
    public var connectors: [DiagramCanvasConnector] { Array(_connectors.values) }
    private var _connectors: [RuntimeEntityID:DiagramCanvasConnector] = [:]
   
    // - MARK: - Styling
    @Export var primaryLabelSettings: SwiftGodot.LabelSettings?
    @Export var secondaryLabelSettings: SwiftGodot.LabelSettings?
    @Export var invalidLabelSettings: SwiftGodot.LabelSettings?

    public override func _ready() {
        if background == nil {
            GD.print("--- Creating background")
            let rect = ColorRect()
            rect.color = Color(code: "F8F4E9")
            rect.zIndex = BackgroundZIndex
            rect.mouseFilter = .ignore
            addChild(node: rect)
            self.background = rect
        }
        updateBackground()
        getViewport()?.sizeChanged.connect(self.updateBackground)
    }

    func updateBackground() {
        GD.print("--? Update background?")
        guard let viewport = getViewport(),
              let background = self.background else { return }
        let size = viewport.getVisibleRect().size
        GD.print("--- Yes, update background: \(size). Zoom: \(zoomLevel) offset: \(canvasOffset)")
        background.setSize(size / Double(zoomLevel))
        background.setPosition(-canvasOffset / Double(zoomLevel))
    }
    
    // - MARK: Content
    /// Get IDs of design objects represented within the canvas.
    ///
    /// Example use case of this method is to provide IDs for the _"Select all"`_ command.
    ///
    func selectableObjectIDs() -> [PoieticCore.ObjectID] {
        let blockIDs = _blocks.keys.compactMap { $0.objectID }
        let connectorIDs = _connectors.keys.compactMap { $0.objectID }
        return blockIDs + connectorIDs
    }
    
    /// Get IDs of objects represented in the canvas - blocks and connectors.
    @Callable(autoSnakeCase: false)
    func get_selectable_objects() -> PackedInt64Array {
        let rawIDs = selectableObjectIDs().map { Int64($0.rawValue) }
        return PackedInt64Array(rawIDs)
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
        _blocks.removeAll()
        _connectors.removeAll()
    }

    /// Add a block that represents a design node. The block must have `ObjectID` set to a non-nil
    /// value. Existing block with the same ID will be replaced.
    ///
    public func insertBlock(_ block: DiagramCanvasBlock) {
        guard let id = block.runtimeID else { return }
        
        if let existing = _blocks[id] {
            removeChild(node: existing)
        }
        addChild(node: block)
        _blocks[id] = block
    }

    public func removeBlock(_ id: RuntimeEntityID) {
        guard let node = _blocks.removeValue(forKey: id) else {
            return
        }
        node.queueFree()
    }
    
    /// Get a block that represents a design object with given ID (typically a node).
    ///
    /// If no such block exists or the canvas object is of different type, then `null` is returned.
    ///
    @Callable(autoSnakeCase: true)
    public func getBlock(rawID: EntityIDValue) -> DiagramCanvasBlock? {
        let runtimeID: RuntimeEntityID = .object(PoieticCore.ObjectID(rawValue: rawID))
        return _blocks[runtimeID]
    }
    
    public func block(id: RuntimeEntityID) -> DiagramCanvasBlock? {
        return _blocks[id]
    }

    public func insertConnector(_ connector: DiagramCanvasConnector) {
        guard let id = connector.runtimeID else { return }
        
        if let existing = _connectors[id] {
            removeChild(node: existing)
        }
        addChild(node: connector)
        _connectors[id] = connector
    }
    public func removeConnector(_ id: RuntimeEntityID) {
        guard let object = _connectors.removeValue(forKey: id) else {
            return
        }
        object.queueFree()
    }

    /// Get a connector that represents a design object with given ID (typically an edge).
    ///
    /// If no such connector exists or the canvas object is of different type, then `null` is returned.
    ///
    @Callable(autoSnakeCase: true)
    public func getConnector(rawID: EntityIDValue) -> DiagramCanvasConnector? {
        let id: RuntimeEntityID = .object(PoieticCore.ObjectID(rawValue: rawID))
        return _connectors[id]
    }
    public func connector(id: RuntimeEntityID) -> DiagramCanvasConnector? {
        return _connectors[id]
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
        print("--- Update canvas view")
        self.position = canvasOffset
        self.scale = Vector2(x: zoomLevel, y: zoomLevel)
        canvasViewChanged.emit(canvasOffset, zoomLevel)
        
        chartsVisible = zoomLevel > Self.ChartsVisibleZoomLevel
        formulasVisible = zoomLevel > Self.FormulasVisibleZoomLevel

        updateBackground()
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
        let runtimeID = RuntimeEntityID.object(nodeID)
        guard let block = _blocks[runtimeID] else { return .zero }

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
        let nodeID = PoieticCore.ObjectID(rawValue: rawID)
        let runtimeID = RuntimeEntityID.object(nodeID)
        if let block = _blocks[runtimeID] {
            let y: Float
            if let label = block.primaryLabel {
                y = label.getGlobalPosition().y
            }
            else {
                y = block.globalPosition.y
            }
            return Vector2(x: block.globalPosition.x,y: y)
        }
        else if let connector = _connectors[runtimeID] {
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


