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
public class PoieticCanvas: SwiftGodot.Node2D {
    static let ChartsVisibleZoomLevel: Float = 2.0
    static let FormulasVisibleZoomLevel: Float = 1.0
    @Signal var canvasViewChanged: SignalWithArguments<SwiftGodot.Vector2, Float>

    @Export var zoomLevel: Float = 1.0
    @Export var canvasOffset: SwiftGodot.Vector2 = .zero
    
    @Export var chartsVisible: Bool = false
    @Export var formulasVisible: Bool = false
    
    var blocks: [PoieticBlock] = []
    var connectors: [PoieticConnector] = []
    @Export var selection: PoieticSelection
    
    required init(_ context: InitContext) {
        self.selection = PoieticSelection()
        super.init(context)
    }
    public override func _process(delta: Double) {
        // Find moved blocks
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
            let global = Engine.getSingleton(name: StringName("Global"))
            let ctool = global?.get(property: StringName("current_tool"))
            let boo = Array(Engine.getSingletonList())
            GD.print("--- Singletons: \(boo)")
            GD.print("--- Global: \(global) Tool: \(ctool)")
            break// Regular tool use
//            var tool = Global.current_tool
//            if not tool {
//                return
//            }
//            tool.canvas = self
//            if tool.handle_input(event): {
//                get_viewport().set_input_as_handled()
//            }
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
    public func block(id: PoieticCore.ObjectID) -> PoieticBlock? {
        return blocks.first { $0.objectID == id }
    }
    public func connector(id: PoieticCore.ObjectID) -> PoieticConnector? {
        return connectors.first { $0.objectID == id }
    }
    
    public func objectsAtTouch(_ point: Vector2D, radius: Double=10.0) -> [PoieticCanvasObject] {
        var result: [PoieticCanvasObject] = []
        result += blocks.filter { $0.block?.containsTouch(at: point, radius: radius) ?? false }
        result += connectors.filter { $0.connector?.containsTouch(at: point, radius: radius) ?? false }
        return result
    }
    
    
    @Callable
    func hit_target(hitPosition: SwiftGodot.Vector2) -> PoieticHitTarget? {
        var targets: [PoieticHitTarget] = []
        var children = self.getChildren()
        
        // TODO:  Need to sort by z-index. This is kind of arbitrary, we pretend this is an order of insertion.
        children.reverse()
        for child in children {
            guard let child = child as? PoieticCanvasObject else {
                continue
            }
            
            for handle in child.getHandles() where handle.visible {
                if handle.containsPoint(point: hitPosition) {
                    targets.append(PoieticHitTarget(object: child, type: .handle, tag: handle.tag))
                }
            }
            
            if let child = child as? PoieticBlock {
                if let indicator = child.issue_indicator as? PoieticIssueIndicator,
                   indicator.visible,
                   indicator.contains_point(child.toLocal(globalPoint: hitPosition))
                {
                    targets.append(PoieticHitTarget(object: child, type: .errorIndicator))
                }
                if let label = child.primaryLabel,
                   label.visible &&
                    label.getRect().hasPoint(child.toLocal(globalPoint: hitPosition))
                {
                    targets.append(PoieticHitTarget(object: child, type: .primaryLabel))
                }

                if let label = child.secondaryLabel,
                   label.visible &&
                    label.getRect().hasPoint(child.toLocal(globalPoint: hitPosition))
                {
                    targets.append(PoieticHitTarget(object: child, type: .secondaryLabel))
                }
            }

            if child.contains_point(point: hitPosition) {
                targets.append(PoieticHitTarget(object: child, type: .object))
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


