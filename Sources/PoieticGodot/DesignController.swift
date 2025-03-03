//
//  FrameController.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 22/02/2025.
//

import SwiftGodot
import PoieticFlows
import PoieticCore

@Godot
public class PoieticIssue: SwiftGodot.RefCounted {
    var issue: DesignIssue! = nil

    @Export var domain: String {
        get { issue.domain.description}
        set {}
    }
    @Export var severity: String {
        get { issue.severity.description }
        set {}
    }
    @Export var identifier: String {
        get { issue.identifier }
        set {}
    }
    @Export var message: String {
        get { issue.message }
        set {}
    }
    @Export var hint: String? {
        get { issue.hint }
        set {}
    }
    @Export var details: GDictionary {
        get {
            var dict = GDictionary()
            for (key, value) in issue.details {
                dict[key] = value.asGodotVariant()
            }
            return dict
        }
        set {}
    }
}

@Godot
public class PoieticActionResult: SwiftGodot.RefCounted {
    var issues: DesignIssueCollection? = nil
    var createdObjects: [PoieticCore.ObjectID] = []
    var removedObjects: [PoieticCore.ObjectID] = []
    var modifiedObjects: [PoieticCore.ObjectID] = []

    convenience init(fatalError message: String) {
        self.init()

        let issue = DesignIssue(domain: .validation,
                                severity: .fatal,
                                identifier: "internal_error",
                                message: message,
                                hint: "Let the developers know about this error")
        var issues = DesignIssueCollection()
        issues.append(issue)
        self.issues = issues
    }
    required init() {
        super.init()
        onInit()
    }

    required init(nativeHandle: UnsafeRawPointer) {
        super.init(nativeHandle: nativeHandle)
        onInit()
    }
    
    func onInit() {}
    
    @Callable
    func is_success() -> Bool {
        issues?.isEmpty ?? true
    }

    @Callable
    func is_fatal() -> Bool {
        guard let issues else {
            return false
        }
        return issues.designIssues.contains { $0.severity == .fatal }
    }
}

@Godot
public class PoieticDesignController: SwiftGodot.Node {
    var design: Design
    var currentFrame: DesignFrame { self.design.currentFrame! }
    
    var metamodel: Metamodel { design.metamodel }
    // let canvas: PoieticCanvas?
   
    // current frame
    
    #signal("design_changed")
    #signal("design_error_signalled")

    
    required init() {
        self.design = Design(metamodel: Metamodel.StockFlow)
        super.init()
        onInit()
    }

    required init(nativeHandle: UnsafeRawPointer) {
        self.design = Design(metamodel: Metamodel.StockFlow)
        super.init(nativeHandle: nativeHandle)
        onInit()
    }

    func onInit() {
        let frame = self.design.createFrame()
        try! self.design.accept(frame, appendHistory: true)
    }

    @Callable
    func new_design() {
        self.design = Design(metamodel: Metamodel.StockFlow)
        let frame = self.design.createFrame()
        try! self.design.accept(frame, appendHistory: true)
    }
    
    @Callable
    func get_diagram_nodes() -> PackedInt64Array {
        let nodes = currentFrame.nodes.filter { $0.type.hasTrait(.DiagramNode) }
        return PackedInt64Array(nodes.map { Int64($0.id.intValue) })
    }

    @Callable
    func get_diagram_edges() -> PackedInt64Array {
        let edges = currentFrame.edges.filter { _ in true /* FIXME: Use diagram edges only */ }
        return PackedInt64Array(edges.map { Int64($0.id.intValue) })
    }

    @Callable
    func new_transaction() -> PoieticTransaction {
        let frame = design.createFrame(deriving: design.currentFrame)
        let trans = PoieticTransaction()
        trans.setFrame(frame)
        return trans
    }
    
    @Callable
    func accept(transaction: PoieticTransaction) -> PoieticActionResult {
        guard let frame = transaction.frame else {
            GD.pushError("Using transaction without a frame")
            return PoieticActionResult(fatalError: "Using transaction without a frame")
        }
        let issues: DesignIssueCollection?
        
        do {
            try design.accept(frame, appendHistory: true)
            issues = nil
        }
        catch {
            issues = error.asDesignIssueCollection()
        }
        var result = PoieticActionResult()
        result.issues = issues
        return result
    }
}

@Godot
class PoieticTransaction: SwiftGodot.Object {
    var frame: TransientFrame?
    
    func setFrame(_ frame: TransientFrame){
        self.frame = frame
    }

    @Callable
    func create_node(typeName: String, name: SwiftGodot.Variant?, attributes: GDictionary) -> SwiftGodot.Variant? {
        guard let frame else {
            GD.pushError("Using transaction without a frame")
            return nil
        }

        guard let type = frame.design.metamodel.objectType(name: typeName) else {
            GD.pushError("Trying to create a node of unknown type '\(typeName)'")
            return nil
        }
        let actualName: String?
        if let name {
            guard let name = String(name) else {
                GD.pushError("Expected string for name")
                return nil
            }
            actualName = name
        }
        else {
            actualName = nil
        }

        var lossyAttributes: [String:PoieticCore.Variant] = attributes.asLossyPoieticAttributes()
        
        let object = frame.createNode(type, name: actualName, attributes: lossyAttributes)
        
        return object.id.gdVariant
    }
    
    @Callable
    func create_edge(typeName: String, origin: Int64, target: Int64) -> SwiftGodot.Variant? {
        guard let frame else {
            GD.pushError("Using transaction without a frame")
            return nil
        }
        guard let originID = PoieticCore.ObjectID(String(origin)) else {
            GD.pushError("Invalid origin ID")
            return nil
        }
        guard let targetID = PoieticCore.ObjectID(String(target)) else {
            GD.pushError("Invalid target ID")
            return nil
        }

        guard let type = frame.design.metamodel.objectType(name: typeName) else {
            GD.pushError("Trying to create a node of unknown type '\(typeName)'")
            return nil
        }
        guard frame.contains(originID) else {
            GD.pushError("Unknown object ID \(origin)")
            return nil
        }
        guard frame.contains(targetID) else {
            GD.pushError("Unknown object ID \(target)")
            return nil
        }

        let object = frame.createEdge(type, origin: originID, target: targetID)
        
        return object.id.gdVariant
    }
    
}
