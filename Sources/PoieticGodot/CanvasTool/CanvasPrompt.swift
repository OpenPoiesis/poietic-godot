//
//  CanvasPromptManager.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 28/08/2025.
//

import SwiftGodot

@Godot
class CanvasPromptManager: SwiftGodot.Node {
    required init(_ context: SwiftGodot.InitContext) {
        super.init(context)
    }
}

@Godot
class CanvasPrompt: SwiftGodot.Control {
    @Export var diagramController: PoieticDiagramController?
//    @Export var isActive: Bool = false
    
    required init(_ context: SwiftGodot.InitContext) {
        super.init(context)
    }
    
    @Callable
    func open(objectID: Int64) {
        // Subclasses should override this
    }

    @Callable
    func close() {
        // Subclasses should override this
    }
}
