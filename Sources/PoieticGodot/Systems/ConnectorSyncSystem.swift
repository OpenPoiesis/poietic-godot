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
struct ConnectorSyncSystem: System {
    // TODO: Alternative names: DiagramSceneSystem
    nonisolated(unsafe) public static let dependencies: [SystemDependency] = [
        .after(BlockCreationSystem.self),
        .after(ConnectorGeometrySystem.self),
    ]
    init() {}
    func update(_ world: World) throws (InternalSystemError) {
        guard let canvasComponent: CanvasComponent = world.singleton()
        else { return }
        
        let canvas = canvasComponent.canvas
        let style = canvas.style ?? CanvasStyle()

        var remaining = Set(canvas.connectors.compactMap { $0.entityID })
        var updated: [DiagramCanvasBlock] = []
        
        for (id, component) in world.query(DiagramConnector.self) {
            // TODO: Use multi-component query once available
            guard let geometry: DiagramConnectorGeometry = world.component(for: id) else { continue }

            sync(connector: component,
                 geometry: geometry,
                 id: id,
                 canvas: canvasComponent.canvas,
                 style: style,
                 world: world)
            
            remaining.remove(id)
        }
        
        for id in remaining {
            canvas.removeConnector(id)
        }
    }
    
    public func sync(connector: DiagramConnector,
                     geometry: DiagramConnectorGeometry,
                     id entityID: EphemeralID,
                     canvas: DiagramCanvas,
                     style: CanvasStyle,
                     world: World)
    {
        let sceneNode: DiagramCanvasConnector
        if let node = canvas.connector(id: entityID) {
            sceneNode = node
        }
        else {
            sceneNode = DiagramCanvasConnector()
            sceneNode.entityID = entityID
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
