//
//  ValueIndicator.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 08/10/2025.
//

import SwiftGodot

nonisolated(unsafe) let DefaultValueIndicatorSize = Vector2(x: 100, y: 20)

public enum Orientation: Int, CaseIterable, CustomStringConvertible {
    case horizontal = 0
    case vertical = 1

    public var description: String {
        switch self {
        case .horizontal: "horizontal"
        case .vertical: "vertical"
        }
    }
}

@Godot
public class ValueIndicator: SwiftGodot.Node2D {
    
    /// Value to be displayed by the indicator.
    ///
    @Export var value: Double? {
        didSet { self.queueRedraw() }
    }

    /// Size of the indicator rectangle.
    @Export var size: Vector2 = DefaultValueIndicatorSize

    /// Orientation of the indicator bar.
    @Export var orientation: Orientation = .horizontal {
        didSet { self.queueRedraw() }
    }
    
    //
    // |<-- min value
    // |
    // |        |<-- origin
    // |        |              | <-- max value
    // +--------+--------------+
    // |        |******        |
    // +--------+--------------|
    //                 |<-- actual value
    //
    
    /// Upper bound value that is represented at the left side of the indicator
    @Export var minValue: Double = 0.0
    /// Lower bound value that is represented at the right side of the indicator
    @Export var maxValue: Double = 100.0
    /// Origin value (typically same as min value), relative to which the indicator bar will be
    /// drawn.
    @Export var origin: Double = 0.0

    /// Style used to draw the indicator background, before the actual indicator content.
    @Export var backgroundStyle: StyleBox = StyleBoxLine()
    /// Style used to draw the indicator bar when the value is within bounds and when the negative
    /// style is not set.
    @Export var normalStyle: StyleBox = StyleBoxFlat()
    /// If set, then the style is used to draw the value when the value is less than origin.
    @Export var negativeStyle: StyleBox?
    /// Value used to draw the indicator when the value is greater than max value.
    @Export var overflowStyle: StyleBox = StyleBoxFlat()
    /// Value used to draw the indicator when the value is less than min value.
    @Export var underflowStyle: StyleBox = StyleBoxFlat()
    /// Style of the indicator when the value is not set.
    @Export var emptyStyle: StyleBox = StyleBoxFlat()

    override public func _draw() {
        GD.print("--- Draw indicator ", value, self)
        var rect = Rect2(position: position - size / 2, size: size)
        guard let value else {
            emptyStyle.draw(canvasItem: self.getCanvasItem(), rect: rect)
            return
        }
        backgroundStyle.draw(canvasItem: self.getCanvasItem(), rect: rect)
        let style: StyleBox
        
        let boundedValue: Double
        // 1. Compute value rectangle
        if value > maxValue {
            style = overflowStyle
            boundedValue = maxValue
        }
        else if value < minValue {
            style = underflowStyle
            boundedValue = minValue
        }
        else {
            if value >= origin {
                style = normalStyle
            }
            else {
                style = negativeStyle ?? normalStyle
            }
            boundedValue = value
        }
        
        let range = maxValue - minValue
        guard range.magnitude > Double.standardEpsilon else {
            style.draw(canvasItem: self.getCanvasItem(), rect: rect)
            return
        }
        
        let bar: Rect2
        
        switch orientation {
        case .horizontal:
            let scaledOrigin = Float((origin - minValue) / range) * size.x
            let scaledValue = Float((boundedValue - minValue) / range) * size.x

            if scaledValue >= scaledOrigin {
                bar = Rect2(x: rect.position.x + scaledOrigin, y: rect.position.y,
                            width: scaledValue - scaledOrigin, height: size.y)
            }
            else {
                bar = Rect2(x: rect.position.x + scaledValue, y: rect.position.y,
                            width: scaledOrigin - scaledValue, height: size.y)
            }

        case .vertical:
            let scaledOrigin = Float((origin - minValue) / range) * size.y
            let scaledValue = Float((boundedValue - minValue) / range) * size.y

            if scaledValue >= scaledOrigin {
                bar = Rect2(x: rect.position.x, y: rect.position.y + scaledOrigin,
                            width: size.x, height: scaledValue - scaledOrigin)
            }
            else {
                bar = Rect2(x: rect.position.x, y: rect.position.y + scaledValue,
                            width: size.x, height: scaledOrigin - scaledValue)
            }
        }

        style.draw(canvasItem: self.getCanvasItem(), rect: bar)
    }
}
