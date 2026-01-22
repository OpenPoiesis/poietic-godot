//
//  PoieticObject.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 13/04/2025.
//
import SwiftGodot
import PoieticFlows
import PoieticCore

@Godot
class PoieticEntity: SwiftGodot.RefCounted {
    var world: World?
    internal var runtimeID: RuntimeID?
    
    var objectID: PoieticCore.ObjectID? {
        guard let runtimeID
        else { return nil }
        return world?.entityToObject(runtimeID)
    }

    var object: ObjectSnapshot? {
        guard let entityID = runtimeID,
              let objectID = world?.entityToObject(entityID),
              let object = world?.frame?[objectID]
        else { return nil }
        return object
    }
    
    required init(_ context: InitContext) {
        fatalError("init(_:) has not been implemented")
    }
    
    public func bind(world: World, entityID: RuntimeID) {
        precondition(self.world == nil && self.runtimeID == nil)
        self.world = world
        self.runtimeID = entityID
    }
    
    /// World entity ID.
    ///
    @Export var runtime_id: GodotRuntimeEntityID {
        get { runtimeID!.asGodotValue() }
        set { readOnlyAttributeError() }
    }
    /// ID of an object if the entity represents a design object.
    ///
    /// `nil` if the entity is an ephemeral entity.
    @Export var object_id: GodotDesignEntityID? {
        get {
            guard let objectID = world?.entityToObject(runtimeID!)
            else {
                return nil
            }
            return objectID.asGodotValue()
        }
        set { readOnlyAttributeError() }
    }
    
    
    /// List of issues of a design object.
    ///
    /// The list is always empty for non-design object entities (ephemeral entities).
    ///
    @Callable(autoSnakeCase: true)
    func issues() -> TypedArray<PoieticIssue?> {
        guard let world,
              let object = self.object,
              let objectIssues = world.objectIssues(object.objectID)
        else { return [] }
        
        let result =  objectIssues.map {
            let issue = PoieticIssue()
            issue.issue = $0
            return issue
        }
        return TypedArray(result)
    }

    /// Flag whether the entity representing a design object has any issues.
    ///
    /// Non-design object entities have no issues.
    ///
    @Callable(autoSnakeCase: true)
    func hasIssues() -> Bool {
        guard let world,
              let object = self.object
        else { return false }
        return world.objectHasIssues(object.objectID)
    }
    
    // MARK: - Design Object

    @Export var objectName: String? {
        get { object?.name }
        set { readOnlyAttributeError() }
    }

    @Export var typeName: String? {
        get { object?.type.name }
        set { readOnlyAttributeError() }
    }
    
    @Export var label: String? {
        get { object?.label }
        set { readOnlyAttributeError() }
    }
    
    @Export var secondaryLabel: String? {
        get { object?.secondaryLabel }
        set { readOnlyAttributeError() }
    }

    @Export var origin: Int? {
        get {
            guard let object,
                  case let .edge(origin, _) = object.structure
            else { return nil }
            return origin.asGodotValue()
        }
        set { readOnlyAttributeError() }
    }

    @Export var target: Int? {
        get {
            guard let object,
                  case let .edge(_, target) = object.structure
            else { return nil }
            return target.asGodotValue()
        }
        set { readOnlyAttributeError() }
    }

    @Callable(autoSnakeCase: true)
    func getTraits() -> PackedStringArray {
        guard let type = object?.type else { return PackedStringArray() }
        return PackedStringArray(type.traits.map { String($0.name) })
    }
    
    @Callable(autoSnakeCase: true)
    func hasTrait(_ traitName: String) -> Bool {
        guard let type = object?.type else { return false }
        return type.hasTrait(traitName)
    }

    @Callable(autoSnakeCase: true)
    func getAttribute(_ attribute: String) -> SwiftGodot.Variant? {
        guard let object,
              let value = object[attribute] else { return nil }
        return value.asGodotVariant()
    }
    
    @Callable(autoSnakeCase: true)
    func getAttributeKeys() -> PackedStringArray {
        guard let type = object?.type else { return PackedStringArray() }
        return PackedStringArray(type.attributes.map {$0.name})
    }

    // MARK: - Result
    
    @Callable(autoSnakeCase: true)
    func timeSeries() -> PoieticTimeSeries? {
        guard let entityID = runtimeID,
              let objectID = world?.entityToObject(entityID),
              let series: RegularTimeSeries = world?.component(for: entityID)
        else { return nil }
        
        let wrapped = PoieticTimeSeries()
        wrapped._object_id = objectID
        wrapped.series = series
        return wrapped
    }
}
