//
//  DiagramStyle.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 27/10/2025.
//

import SwiftGodot
import PoieticCore

nonisolated(unsafe) let DefaultPictogramColor: SwiftGodot.Color = .gray
nonisolated(unsafe) let DefaultConnectorColor: SwiftGodot.Color = .gray
nonisolated(unsafe) let DefaultConnectorFillColor: SwiftGodot.Color = .darkGray
nonisolated(unsafe) let DefaultIntentShadowColor: SwiftGodot.Color = .darkGray

nonisolated(unsafe) let DefaultBlockLabelColor: SwiftGodot.Color = .gray

@Godot
public class CanvasStyle: SwiftGodot.Node {
    @Export public var adaptableColors: TypedDictionary<String, SwiftGodot.Color>?
    // Block
    @Export public var lineWidths: TypedDictionary<String, Double> = [:]
    @Export public var pictogramColor: SwiftGodot.Color = DefaultPictogramColor

    @Export public var primaryLabelSettings: SwiftGodot.LabelSettings = SwiftGodot.LabelSettings()
    @Export public var secondaryLabelSettings: SwiftGodot.LabelSettings = SwiftGodot.LabelSettings()
    @Export public var invalidLabelSettings: SwiftGodot.LabelSettings = SwiftGodot.LabelSettings()

    @Export public var intentShadowColor: SwiftGodot.Color = .darkBlue

    // Connector
    @Export public var defaultConnectorLineWidth: Double = 1.0
    @Export public var defaultConnectorColor: SwiftGodot.Color = DefaultConnectorColor
    @Export public var defaultConnectorFillColor: SwiftGodot.Color = DefaultConnectorFillColor

    // Per-type properties
    @Export public var connectorColors: TypedDictionary<String, SwiftGodot.Color> = [:]
    @Export public var connectorFillColors: TypedDictionary<String, SwiftGodot.Color> = [:]

    // Other visuals
    @Export public var selectionOutlineColor: SwiftGodot.Color = Color.blue
    @Export public var selectionFillColor: SwiftGodot.Color = Color.azure
    @Export public var handleColor: SwiftGodot.Color = DefaultConnectorColor

    
    @Callable
    func getAdaptableColor(name: String, defaultColor: SwiftGodot.Color) -> SwiftGodot.Color {
        return adaptableColors?[name] ?? defaultColor
    }
    @Callable
    func getLineWidth(_ name: String? = nil, defaultWidth: Double = 1.0) -> Double {
        guard let name else { return defaultWidth }
        return lineWidths[name] ?? defaultWidth
    }
}
