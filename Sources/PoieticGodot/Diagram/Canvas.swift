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
    
    var blocks: [DiagramCanvasBlock] = []
    var connectors: [DiagramCanvasConnector] = []
    @Export var selection: PoieticSelection
   
    required init(_ context: InitContext) {
        self.selection = PoieticSelection()
        super.init(context)
    }
    public override func _process(delta: Double) {
        // Find moved blocks
    }
   
    func currentTool() -> CanvasTool? {
        // FIXME: Use application
        guard let global = getNode(path: "/root/Global") else {
            GD.pushWarning("Unable to get current tool, no Global set")
            return nil
        }
        guard let variant = global.get(property: "current_tool") else {
            GD.pushWarning("Unable to get current tool")
            return nil
        }
        guard let tool: CanvasTool? = CanvasTool.fromVariant(variant) else {
            GD.pushWarning("Unable to get current tool: Invalid tool type")
            return nil
        }
        return tool
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
    public func block(id: PoieticCore.ObjectID) -> DiagramCanvasBlock? {
        return blocks.first { $0.objectID == id }
    }
    public func connector(id: PoieticCore.ObjectID) -> DiagramCanvasConnector? {
        return connectors.first { $0.objectID == id }
    }
    
    public func objectsAtTouch(_ point: Vector2D, radius: Double=10.0) -> [DiagramCanvasObject] {
        var result: [DiagramCanvasObject] = []
        result += blocks.filter { $0.block?.containsTouch(at: point, radius: radius) ?? false }
        result += connectors.filter { $0.connector?.containsTouch(at: point, radius: radius) ?? false }
        return result
    }
    
    
    /// Get a target wrapping a canvas item at given hit position.
    ///
    /// If you want to get only objects and ignore handles or indicators, then use
    /// ``hitObject(at:)``.
    ///
    @Callable(autoSnakeCase: true)
    public func hitTarget(at hitPosition: SwiftGodot.Vector2) -> CanvasHitTarget? {
        var targets: [CanvasHitTarget] = []
        var children = self.getChildren()
        
        // TODO:  Need to sort by z-index. This is kind of arbitrary, we pretend this is an order of insertion.
        children.reverse()
        for child in children {
            guard let child = child as? DiagramCanvasObject else {
                continue
            }
            
            for handle in child.getHandles() where handle.visible {
                if handle.containsPoint(point: hitPosition) {
                    targets.append(CanvasHitTarget(object: child, type: .handle, tag: handle.tag))
                }
            }
            
            if let child = child as? DiagramCanvasBlock {
                if let indicator = child.issue_indicator as? CanvasIssueIndicator,
                   indicator.visible,
                   indicator.contains_point(child.toLocal(globalPoint: hitPosition))
                {
                    targets.append(CanvasHitTarget(object: child, type: .errorIndicator))
                }
                if let label = child.primaryLabel,
                   label.visible &&
                    label.getRect().hasPoint(child.toLocal(globalPoint: hitPosition))
                {
                    targets.append(CanvasHitTarget(object: child, type: .primaryLabel))
                }

                if let label = child.secondaryLabel,
                   label.visible &&
                    label.getRect().hasPoint(child.toLocal(globalPoint: hitPosition))
                {
                    targets.append(CanvasHitTarget(object: child, type: .secondaryLabel))
                }
            }

            if child.contains_point(point: hitPosition) {
                targets.append(CanvasHitTarget(object: child, type: .object))
            }
        }
        
        let debugStr: String = targets.map { $0.debugDescription}.joined(separator: ",")
        GD.print("Targets: \(debugStr)")
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
    public func hitObject(at hitPosition: SwiftGodot.Vector2) -> DiagramCanvasObject? {
        var targets: [CanvasHitTarget] = []
        var children = self.getChildren()
        
        // TODO:  Need to sort by z-index. This is kind of arbitrary, we pretend this is an order of insertion.
        children.reverse()
        for child in children {
            guard let child = child as? DiagramCanvasObject else {
                continue
            }
            
            if child.contains_point(point: hitPosition) {
                return child
            }
        }
        
        return nil
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


