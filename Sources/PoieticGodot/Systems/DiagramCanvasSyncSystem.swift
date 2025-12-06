//
//  DiagramCanvasSyncSystem.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 12/11/2025.
//

import PoieticCore
import SwiftGodot
import Diagramming

/// Component for entities representing Godot diagram canvas nodes.
///
/// Currently only one canvas is managed per ``DesignController``. The canvas component
/// is associated with the frame (singleton). Other entities with this component are ignored.
///
public struct CanvasComponent: Component {
    // See: DesignController.canvas.
    /// Canvas scene node that the controller manages and synchronises diagrammatic representation
    /// of a design.
    public let canvas: DiagramCanvas
}
