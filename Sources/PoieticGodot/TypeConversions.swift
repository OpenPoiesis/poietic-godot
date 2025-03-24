//
//  TypeConversions.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 24/02/2025.
//
import SwiftGodot
import PoieticFlows
import PoieticCore

typealias PoieticID = Int64
typealias PoieticIDArray = PackedInt64Array

extension PoieticCore.ObjectID {
    // TODO: This is unclean, just so we have this prototype working
    init?(_ value: Int64) {
        self.init(String(value))
    }
    // For regular ints
    var gdInt: Int { Int(self.intValue) }
    // For PackedInt64Array (does not work for `Int64?`)
    var gdInt64: Int64 { Int64(self.intValue) }
    var gdVariant: SwiftGodot.Variant { SwiftGodot.Variant(Int64(self.intValue)) }
}

extension Point {
    init(_ vector: SwiftGodot.Vector2) {
        self.init(x: Double(vector.x), y: Double(vector.y))
    }
    func asGodotVariant() -> SwiftGodot.Variant {
        return SwiftGodot.Variant(SwiftGodot.Vector2(x: Float(self.x), y: Float(self.y)))
    }
    func asGodotVector2() -> SwiftGodot.Vector2 {
        return SwiftGodot.Vector2(x: Float(self.x), y: Float(self.y))
    }
}

extension PoieticCore.Variant {
    init?(_ variant: SwiftGodot.Variant) {
        if let value = String(variant) {
            self.init(value)
        }
        else if let value = Bool(variant) {
            self.init(value)
        }
        else if let value = Double(variant) {
            self.init(value)
        }
        else if let value = Int(variant) {
            self.init(value)
        }
        else if let value = SwiftGodot.Vector2(variant)  {
            self.init(Point(value))
        }
        else if let items = SwiftGodot.PackedInt32Array(variant)  {
            let values: [Int] = items.map { Int($0) }
            self.init(values)
        }
        else if let items = SwiftGodot.PackedInt64Array(variant)  {
            let values: [Int] = items.map { Int($0) }
            self.init(values)
        }
        else if let items = SwiftGodot.PackedFloat64Array(variant)  {
            let values: [Double] = items.map { Double($0) }
            self.init(values)
        }
        else if let items = SwiftGodot.PackedStringArray(variant)  {
            let values: [String] = items.map { $0 }
            self.init(values)
        }
        else if let items = SwiftGodot.PackedVector2Array(variant)  {
            let points = items.map { Point($0) }
            self.init(points)
        }
        else {
            GD.pushError("Unhandled conversion from Godot variant type: \(variant.gtype)")
            return nil
        }
    }
    func asGodotVariant() -> SwiftGodot.Variant {
        switch self {
        case .atom(let atom):
            switch atom {
            case let .bool(value): SwiftGodot.Variant(value)
            case let .double(value): SwiftGodot.Variant(value)
            case let .int(value): SwiftGodot.Variant(value)
            case let .point(value): value.asGodotVariant()
            case let .string(value): SwiftGodot.Variant(value)
            }
        case .array(let array):
            switch array {
            case let .bool(value): SwiftGodot.Variant(PackedInt32Array(value.map { ($0) ? 1 : 0 }))
            case let .double(value): SwiftGodot.Variant(PackedFloat64Array(value))
            case let .int(value): SwiftGodot.Variant(PackedInt64Array(value.map {Int64($0)}))
            case let .point(value): SwiftGodot.Variant(PackedVector2Array(value.map { $0.asGodotVector2() }))
            case let .string(value): SwiftGodot.Variant(PackedStringArray(value))
            }
        }
    }
}

extension GDictionary {
    /// Convert the dictionary to an attribute dictionary.
    ///
    /// Items with keys not convertible to string and with values not convertible to Variant
    /// are ignored.
    ///
    func asLossyPoieticAttributes() -> [String:PoieticCore.Variant] {
        var result: [String:PoieticCore.Variant] = [:]
        for key in self.keys() {
            guard let key, let attributeName = String(key) else {
                continue
            }
            guard let value = self[key] else {
                continue
            }
            guard let poieticVariant = PoieticCore.Variant(value) else {
                continue
            }
            result[attributeName] = poieticVariant
            
        }
        return result
    }
}

