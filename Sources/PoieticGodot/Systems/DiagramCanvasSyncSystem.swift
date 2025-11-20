//
//  DiagramCanvasSyncSystem.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 12/11/2025.
//

import PoieticCore
import SwiftGodot
import Diagramming

public struct CanvasComponent: Component {
    /// Canvas scene node that the controller manages and synchronises diagrammatic representation
    /// of a design.
    public let canvas: DiagramCanvas
    public let canvasStyle: CanvasStyle
}

