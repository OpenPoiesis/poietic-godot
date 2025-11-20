//
//  Preview.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 18/11/2025.
//

import PoieticCore
import Diagramming

/// Connector that is being dragged
public struct DraggedDiagramConnector: Component {
    internal init(originID: RuntimeEntityID,
                  targetPosition: Vector2D,
                  glyph: ConnectorGlyph,
                  midpoints: [Vector2D] = []) {
        self.originID = originID
        self.targetPosition = targetPosition
        self.glyph = glyph
        self.midpoints = midpoints
    }
    
    public let representedObjectID: ObjectID?
    /// Name of connector style.
    ///
    /// Refers to a style defined in ``DiagramStyle/connectorStyles``.
    ///
    public let glyph: ConnectorGlyph
    
    /// ID of the origin diagram block.
    ///
    /// The  runtime entity must have ``DiagramBlock`` component.
    public let originID: RuntimeEntityID

    /// ID of the target diagram block.
    ///
    /// The  runtime entity must have ``DiagramBlock`` component.
    public let targetPosition: Vector2D
    
    /// Optional intermediate midpoints the connector routes through.
    public let midpoints: [Vector2D]
}

