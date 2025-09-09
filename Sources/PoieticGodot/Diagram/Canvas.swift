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

public let EmptyLabelTextFontKey = "empty_text_font"
public let EmptyLabelTextFontColorKey = "empty_text_color"

@Godot
public class DiagramCanvas: SwiftGodot.Node2D {
    static let ChartsVisibleZoomLevel: Float = 2.0
    static let FormulasVisibleZoomLevel: Float = 1.0
    @Signal var canvasViewChanged: SignalWithArguments<SwiftGodot.Vector2, Float>

    @Export var zoomLevel: Float = 1.0
    @Export var canvasOffset: SwiftGodot.Vector2 = .zero
    
    @Export var chartsVisible: Bool = false
    @Export var formulasVisible: Bool = false
    
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
   
    required init(_ context: InitContext) {
        super.init(context)
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
        // TODO: Implement this
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
                if let indicator = child.issue_indicator as? CanvasIssueIndicator,
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
            GD.print("--- Hit target (count: \(targets.count)): \(targets[0].type) \(targets[0].object)")
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


