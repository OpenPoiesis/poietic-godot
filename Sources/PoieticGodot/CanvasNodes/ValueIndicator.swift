//
//  ValueIndicator.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 08/10/2025.
//

import SwiftGodot

// TODO: Draw overflow/underflow indicator - '+' sign or '>>' '<<' or something like that

nonisolated(unsafe) let DefaultValueIndicatorSize = Vector2(x: 100, y: 20)

let DefaultValueIndicatorBaselineLineWidth: Double = 2.0
let DefaultValueIndicatorPadding: Double = 2.0
let ValueIndicatorRangeMinDefault: Double = 0.0
let ValueIndicatorRangeMaxDefault: Double = 100.0

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
    /// Padding of the indicator bar from the indicator frame box.
    @Export var padding: Double = DefaultValueIndicatorPadding
    @Export var baselineLineColor: Color = SwiftGodot.Color.white
    @Export var baselineLineWidth: Double = DefaultValueIndicatorBaselineLineWidth

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
    @Export var rangeMin: Double = ValueIndicatorRangeMinDefault
    /// Lower bound value that is represented at the right side of the indicator
    @Export var rangeMax: Double = ValueIndicatorRangeMaxDefault
    /// Origin value (typically same as min value), relative to which the indicator bar will be
    /// drawn.
    @Export var baseline: Double = ValueIndicatorRangeMinDefault

    /// Style used to draw the indicator background, before the actual indicator content.
    @Export var backgroundStyle: StyleBox?
    /// Style used to draw the indicator bar when the value is within bounds and when the negative
    /// style is not set.
    @Export var normalStyle: StyleBox?
    /// If set, then the style is used to draw the value when the value is less than origin.
    @Export var negativeStyle: StyleBox?
    /// Value used to draw the indicator when the value is greater than max value.
    @Export var overflowStyle: StyleBox?
    /// Value used to draw the indicator when the value is less than min value.
    @Export var underflowStyle: StyleBox?
    /// Style of the indicator when the value is not set.
    @Export var emptyStyle: StyleBox?

    override public func _ready() {
        if let style = backgroundStyle {
            self.backgroundStyle = style
        }
        else {
            let style = StyleBoxFlat()
            style.bgColor = Color.black
            style.borderColor = Color.white
            backgroundStyle = style
        }
        if let style = normalStyle {
            self.normalStyle = style
        }
        else {
            let style = StyleBoxFlat()
            style.bgColor = Color.yellow
            style.borderColor = Color.limeGreen
            normalStyle = style
        }
        if let style = overflowStyle {
            self.overflowStyle = style
        }
        else {
            let style = StyleBoxFlat()
            style.bgColor = Color.red
            style.borderColor = Color.red
            overflowStyle = style
        }
        if let style = underflowStyle {
            self.underflowStyle = style
        }
        else {
            let style = StyleBoxFlat()
            style.bgColor = Color.blue
            style.borderColor = Color.blue
            underflowStyle = style
        }
        if let style = emptyStyle {
            self.emptyStyle = style
        }
        else {
            let style = StyleBoxFlat()
            style.bgColor = Color.darkGray
            style.borderColor = Color.gray
            emptyStyle = style
        }

    }
    
    override public func _draw() {
        let fullRect = Rect2(position: -size / 2, size: self.size)
        let rect = fullRect.grow(amount: -padding)
        let size = rect.size // Adjusted size by padding
        
        guard let value else {
            let style = self.emptyStyle ?? StyleBoxFlat()
            style.draw(canvasItem: self.getCanvasItem(), rect: rect)
            return
        }
        let backgroundStyle = self.backgroundStyle ?? StyleBoxLine()
        backgroundStyle.draw(canvasItem: self.getCanvasItem(), rect: fullRect)
        
        let style: StyleBox
        let boundedValue: Double // Value within indicator bounds

        if value > rangeMax {
            style = overflowStyle ?? StyleBoxFlat()
            boundedValue = rangeMax
        }
        else if value < rangeMin {
            style = underflowStyle ?? StyleBoxFlat()
            boundedValue = rangeMin
        }
        else {
            if value >= baseline {
                style = normalStyle ?? StyleBoxFlat()
            }
            else {
                style = negativeStyle ?? normalStyle ?? StyleBoxFlat()
            }
            boundedValue = value
        }

        let range = rangeMax - rangeMin
        guard range.magnitude > Double.standardEpsilon else {
            style.draw(canvasItem: self.getCanvasItem(), rect: rect)
            return
        }

        let bar: Rect2
        
        switch orientation {
        case .horizontal:
            let scaledOrigin = Float((baseline - rangeMin) / range) * size.x
            let scaledValue = Float((boundedValue - rangeMin) / range) * size.x

            if scaledValue >= scaledOrigin {
                bar = Rect2(x: rect.position.x + scaledOrigin, y: rect.position.y,
                            width: scaledValue - scaledOrigin, height: size.y)
            }
            else {
                bar = Rect2(x: rect.position.x + scaledValue, y: rect.position.y,
                            width: scaledOrigin - scaledValue, height: size.y)
            }
            
            if scaledOrigin > Float.standardEpsilon {
                drawLine(from: Vector2(x: rect.position.x + scaledOrigin, y: rect.position.y),
                         to: Vector2(x: rect.position.x + scaledOrigin, y: rect.position.y + size.y),
                         color: baselineLineColor,
                         width: baselineLineWidth)
            }

        case .vertical:
            let scaledOrigin = Float((baseline - rangeMin) / range) * size.y
            let scaledValue = Float((boundedValue - rangeMin) / range) * size.y

            if scaledValue >= scaledOrigin {
                bar = Rect2(x: rect.position.x, y: rect.position.y + scaledOrigin,
                            width: size.x, height: scaledValue - scaledOrigin)
            }
            else {
                bar = Rect2(x: rect.position.x, y: rect.position.y + scaledValue,
                            width: size.x, height: scaledOrigin - scaledValue)
            }
            if scaledOrigin > Float.standardEpsilon {
                drawLine(from: Vector2(x: rect.position.x, y: rect.position.y + scaledOrigin),
                         to: Vector2(x: rect.position.x + size.x, y: rect.position.y + scaledOrigin),
                         color: baselineLineColor,
                         width: baselineLineWidth)
            }
        }

        style.draw(canvasItem: self.getCanvasItem(), rect: bar)
    }
}
