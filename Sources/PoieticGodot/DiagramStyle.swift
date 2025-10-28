//
//  DiagramStyle.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 27/10/2025.
//

import SwiftGodot
import PoieticCore

@Godot
public class DiagramStyle: SwiftGodot.Node {
    @Export public var adaptableColors: TypedDictionary<String, SwiftGodot.Color>?
    @Export public var lineWidths: TypedDictionary<String, Double>?

    @Callable
    func getAdaptableColor(name: String, defaultColor: SwiftGodot.Color) -> SwiftGodot.Color {
        return adaptableColors?[name] ?? defaultColor
    }
    @Callable
    func getLineWidth(_ name: String, defaultWidth: Double = 1.0) -> Double {
        return lineWidths?[name] ?? defaultWidth
    }
}
