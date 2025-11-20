//
//  ConnectorSyncSystem.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 17/11/2025.
//

import PoieticCore
import SwiftGodot
import Diagramming

/// - **Dependency:** Must run after diagram block and connector components are created.
/// - **Input:** Objects with ``DiagramConnector`` and ``DiagramConnectorGeometry`` components.
/// - **Output:** Creates or updates Godot nodes in a canvas referenced in ``CanvasComponent``.
/// - **Forgiveness:**
///     - Connectors with missing geometry are ignored
public struct ConnectorSyncSystem: System {
    // TODO: Alternative names: DiagramSceneSystem
    nonisolated(unsafe) public static let dependencies: [SystemDependency] = [
        .after(BlockCreationSystem.self),
    ]
    public init() {}
    public func update(_ frame: AugmentedFrame) throws (InternalSystemError) {
        guard let canvasComponent: CanvasComponent = frame.component(for: .Frame) else {
            return
        }
        
        let canvas = canvasComponent.canvas
        var remaining = Set(canvas.connectors.compactMap { $0.runtimeID })
        var updated: [DiagramCanvasBlock] = []
        
        for (id, component) in frame.runtimeFilter(DiagramConnector.self) {
            guard let geometry: DiagramConnectorGeometry = frame.component(for: id) else { continue }

            sync(connector: component,
                 geometry: geometry,
                 id: id,
                 canvas: canvasComponent.canvas,
                 style: canvasComponent.canvasStyle,
                 frame: frame)
            
            remaining.remove(id)
        }
        
        for id in remaining {
            canvas.removeConnector(id)
        }
    }
    
    public func sync(connector: DiagramConnector,
                     geometry: DiagramConnectorGeometry,
                     id runtimeID: RuntimeEntityID,
                     canvas: DiagramCanvas,
                     style: CanvasStyle,
                     frame: AugmentedFrame)
    {
        let sceneNode: DiagramCanvasConnector
        if let node = canvas.connector(id: runtimeID) {
            sceneNode = node
        }
        else {
            sceneNode = DiagramCanvasConnector()
            sceneNode.runtimeID = runtimeID
            canvas.insertConnector(sceneNode)
        }
        
        sceneNode._prepareChildren()
        
        sceneNode.updateGeometry(geometry)
                
        sceneNode.fillColor = style.defaultConnectorFillColor
        sceneNode.fillColor.alpha = DefaultFatConnectorFillAlpha
        sceneNode.lineColor = style.defaultConnectorColor
        sceneNode.lineWidth = style.defaultConnectorLineWidth
        //        self.lineWidth = connector.shapeStyle.lineWidth
        
        sceneNode.queueRedraw()
    }
#if false
    internal func updateHandles(connector: DiagramConnector,
                                geometry: DiagramConnectorGeometry,
                                sceneNode: DiagramCanvasConnector) {
        let existingCount = sceneNode.midpointHandles.count
        let requiredCount = connector.midpoints.count
        let removeCount: Int
        
        if requiredCount == 0 {
            let segment = LineSegment(from: geometry.originPoint, to: geometry.targetPoint)
            let handle: CanvasHandle
            if existingCount == 0 {
                handle = sceneNode.createMidpointHandle()
                removeCount = 0
            }
            else {
                handle = sceneNode.midpointHandles[0]
                removeCount = existingCount - 1
            }
            
            // Connector node position is always (0.0, 0.0). Midpoints are absolute, within diagram
            // canvas. Diagram canvas coordinates are the same as connector node-relative
            // coordinates.
            handle.position = Vector2(segment.midpoint)
            handle.tag = 0
        }
        else { // requiredCount > 0
            for (index, midpoint) in connector.midpoints.enumerated() {
                let handle: CanvasHandle
                if index < existingCount {
                    handle = sceneNode.midpointHandles[index]
                }
                else {
                    handle = sceneNode.createMidpointHandle()
                }
                handle.tag = index
                handle.position = Vector2(midpoint)
            }
            removeCount = existingCount - requiredCount
        }

        if removeCount > 0 {
            for _ in 0..<removeCount {
                let handle = sceneNode.midpointHandles.removeLast()
                handle.queueFree()
            }
        }
        
        for handle in sceneNode.midpointHandles {
            handle.visible = sceneNode.handlesVisible
        }
    }
#endif

}

extension DiagramCanvasConnector {
    public func updateGeometry(_ geometry: DiagramConnectorGeometry)
    {
        self._prepareChildren()
        
        let tessellatedWire = geometry.wire.tessellate()
        self.wire = PackedVector2Array(tessellatedWire)
        
        let body: [Curve2D] = geometry.linePath?.asGodotCurves() ?? []
        let head: [Curve2D] = geometry.headArrowhead?.asGodotCurves() ?? []
        let tail: [Curve2D] = geometry.tailArrowhead?.asGodotCurves() ?? []
        self.openCurves = tail + body + head
        
        let fill = geometry.fillPath?.asGodotCurves() ?? []
        self.filledCurves = fill

        // Selection Outline
        //
        let inflatedWire = geometry.wire.inflated(by: 10.0)
        let outlineCurves = inflatedWire.asGodotCurves()
        self.selectionOutline?.curves = TypedArray(outlineCurves)

        self.queueRedraw()
    }

}
