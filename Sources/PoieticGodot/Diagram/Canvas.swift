//
//  DiagramCanvas.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 18/08/2025.
//

import SwiftGodot
import Diagramming
import PoieticCore

public let DiagramBlockNamePrefix: String = "block"
public let DiagramConnectorNamePrefix: String = "connector"

public let EmptyLabelTextFontKey = "empty_text_font"
public let EmptyLabelTextFontColorKey = "empty_text_color"

@Godot
public class PoieticCanvas: SwiftGodot.Node2D {
    
    var blocks: [PoieticBlock] = []
    var connectors: [PoieticConnector] = []
    
    public override func _process(delta: Double) {
        // Find moved blocks
    }
    
    public func block(id: PoieticCore.ObjectID) -> PoieticBlock? {
        return blocks.first { $0.objectID == id }
    }
    public func connector(id: PoieticCore.ObjectID) -> PoieticConnector? {
        return connectors.first { $0.objectID == id }
    }
}

@Godot
public class PoieticCanvasObject: SwiftGodot.Node2D {
    var objectID: PoieticCore.ObjectID?
    @Export
    var hasIssues: Bool = false
    
    func update(from: ObjectSnapshot) {
        fatalError("Subclasses should override \(#function)")
    }
}

//struct DiagramBlockDisplayOptions: OptionSet {
//    typealias RawValue = UInt32
//    var rawValue: RawValue
//    init(rawValue: RawValue) {
//        self.rawValue = rawValue
//    }
//    
//    static let showPrimaryLabel    = DiagramBlockDisplayOptions(rawValue: 1 << 0)
//    static let showSecondaryLabel  = DiagramBlockDisplayOptions(rawValue: 1 << 1)
//    static let showValueIndicator  = DiagramBlockDisplayOptions(rawValue: 1 << 2)
//}


