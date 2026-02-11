//
//  TypeConversions.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 24/02/2025.
//
import SwiftGodot
import PoieticFlows
import PoieticCore

// TODO: These two aliases are here because compilation of their typed equivalents using SwiftGodot protocol conformances fails (either in declaration or as macro).
public typealias GodotRuntimeEntityID = Int
public typealias GodotDesignEntityID = Int

// TODO: This is here because GodotBuiltinConvertible conformance is causing compile errors
extension PoieticCore.ObjectID {
    init(fromGodotValue value: GodotDesignEntityID) {
        self.init(intValue: UInt64(bitPattern: Int64(value)))
    }
    func asGodotValue() -> GodotDesignEntityID {
        Int(Int64(bitPattern: self.rawValue))
    }
}

extension PoieticCore.RuntimeID {
    init(fromGodotValue value: GodotDesignEntityID) {
        self.init(intValue: UInt64(bitPattern: Int64(value)))
    }
    func asGodotValue() -> GodotDesignEntityID {
        Int(Int64(bitPattern: self.asUInt64))
    }
}

extension PoieticCore.RuntimeID: GodotBuiltinConvertible {
    public func toGodotBuiltin() -> Int {
        Int(Int64(bitPattern: self.asUInt64))
    }
    
    public static func fromGodotBuiltinOrThrow(_ value: Int) throws(SwiftGodot.VariantConversionError) -> PoieticCore.RuntimeID {
        Self.init(intValue: UInt64(bitPattern: Int64(value)))
    }
   
    public typealias GodotBuiltin = Int
}
    
//extension PoieticCore.RuntimeID {
//    public init(fromGodotValue value: Int) {
//        self.init(intValue: UInt64(bitPattern: Int64(value)))
//    }
//    public func asGodotValue() -> Int {
//        Int(Int64(bitPattern: self.asUInt64))
//    }
//}
extension PoieticCore.RuntimeID: SwiftGodot.VariantConvertible {
    public static func fromFastVariantOrThrow(_ variant: borrowing SwiftGodot.FastVariant) throws(SwiftGodot.VariantConversionError) -> Self {
        if let value = UInt64(variant) {
            return Self(intValue: value)
        }
        else {
            throw .unexpectedContent(parsing: PoieticCore.RuntimeID.self, from: variant)
        }
    }
    public func toFastVariant() -> SwiftGodot.FastVariant? {
        SwiftGodot.FastVariant(self.asUInt64)
    }
}

extension PackedInt64Array {
    public convenience init(_ ids: some Collection<DesignEntityID>) {
        let valid = ids.map { Int64(bitPattern: $0.rawValue) }
        self.init(valid)
    }
    public func asDesignEntityIDs() -> [DesignEntityID] {
        let valid = self.map { UInt64(bitPattern: $0) }
        return valid.map { DesignEntityID(intValue: $0) }
    }
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

extension Point: SwiftGodot.VariantConvertible {
    public static func fromFastVariantOrThrow(_ variant: borrowing SwiftGodot.FastVariant) throws(SwiftGodot.VariantConversionError) -> PoieticCore.Point {
        if let vector = SwiftGodot.Vector2(variant) {
            return Point(x: Double(vector.x), y: Double(vector.y))
        }
        else {
            throw .unexpectedContent(parsing: PoieticCore.Point.self, from: variant)
        }
    }
    public func toFastVariant() -> SwiftGodot.FastVariant? {
        return SwiftGodot.FastVariant(SwiftGodot.Vector2(x: Float(self.x), y: Float(self.y)))
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

extension PoieticCore.Variant: SwiftGodot.VariantConvertible {
    public static func fromFastVariantOrThrow(_ variant: borrowing SwiftGodot.FastVariant) throws(SwiftGodot.VariantConversionError) -> PoieticCore.Variant {
        if let value = String(variant) {
            return Self(value)
        }
        else if let value = Bool(variant) {
            return Self(value)
        }
        else if let value = Double(variant) {
            return Self(value)
        }
        else if let value = Int(variant) {
            return Self(value)
        }
        else if let value = SwiftGodot.Vector2(variant)  {
            return Self(Point(value))
        }
        else if let items = SwiftGodot.PackedInt32Array(variant)  {
            let values: [Int] = items.map { Int($0) }
            return Self(values)
        }
        else if let items = SwiftGodot.PackedInt64Array(variant)  {
            let values: [Int] = items.map { Int($0) }
            return Self(values)
        }
        else if let items = SwiftGodot.PackedFloat64Array(variant)  {
            let values: [Double] = items.map { Double($0) }
            return Self(values)
        }
        else if let items = SwiftGodot.PackedStringArray(variant)  {
            let values: [String] = items.map { $0 }
            return Self(values)
        }
        else if let items = SwiftGodot.PackedVector2Array(variant)  {
            let points = items.map { Point($0) }
            return Self(points)
        }
        else {
            throw .unexpectedContent(parsing: PoieticCore.Variant.self, from: variant)
        }
    }
    public func toFastVariant() -> SwiftGodot.FastVariant? {
        switch self {
        case .atom(let atom):
            switch atom {
            case let .bool(value): SwiftGodot.FastVariant(value)
            case let .double(value): SwiftGodot.FastVariant(value)
            case let .int(value): SwiftGodot.FastVariant(value)
            case let .point(value): value.toFastVariant()
            case let .string(value): SwiftGodot.FastVariant(value)
            }
        case .array(let array):
            switch array {
            case let .bool(value): SwiftGodot.FastVariant(PackedInt32Array(value.map { ($0) ? 1 : 0 }))
            case let .double(value): SwiftGodot.FastVariant(PackedFloat64Array(value))
            case let .int(value): SwiftGodot.FastVariant(PackedInt64Array(value.map {Int64($0)}))
            case let .point(value): SwiftGodot.FastVariant(PackedVector2Array(value.map { $0.asGodotVector2() }))
            case let .string(value): SwiftGodot.FastVariant(PackedStringArray(value))
            }
        }
    }
}

extension InspectableComponent {
    func godotDictionary() -> TypedDictionary<String,SwiftGodot.Variant?> {
        var result: TypedDictionary<String,SwiftGodot.Variant?> = [:]
        for (key, value) in self.attributeDictionary() {
            result[key] = value.asGodotVariant()
        }
        return result
    }
}

extension GDictionary {
    convenience init(_ dict: [String:PoieticCore.Variant]) {
        self.init()

        for (attr, value) in dict {
            self[attr] = value.asGodotVariant()
        }
    }
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

