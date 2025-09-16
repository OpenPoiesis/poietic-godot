//
//  CanvasPromptManager.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 28/08/2025.
//

import SwiftGodot

@Godot
class CanvasInlineEditor: SwiftGodot.Node {
    @Export var canvasController: CanvasController?
    
//    @Export var isActive: Bool = false
    
    required init(_ context: SwiftGodot.InitContext) {
        super.init(context)
    }
    
    func contentNode() -> Control? {
        self.getChildren().first as? Control
    }

    @Callable
    func open(objectID: Int64, attribute: String, globalPosition: Vector2) {
        // Subclasses should override this
    }

    @Callable
    func close() {
        // Subclasses should override this
    }
}
