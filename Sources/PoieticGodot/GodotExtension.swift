// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftGodot

#initSwiftExtension(
    cdecl: "swift_entry_point",
    types: [
        // Data
        PoieticMetamodel.self,
        PoieticObject.self,
        PoieticIssue.self,
        PoieticResult.self,
        PoieticTimeSeries.self,

        // Controllers and other functioning objects
        PoieticDesignController.self,
        PoieticPlayer.self,

        // Auxiliary objects
        PoieticTransaction.self, // TODO: Maybe remove?
        PoieticSelection.self,
        PoieticDiagramChange.self, // TODO: Remove
        
        // Tool
        CanvasTool.self,
        
        // Diagram Canvas
        PoieticDiagramController.self,
        DiagramCanvas.self,
        DiagramCanvasObject.self,
        DiagramCanvasConnector.self,
        DiagramCanvasBlock.self,
        
        PoieticHitTarget.self,
        PoieticCanvasHandle.self,
        PoieticIssueIndicator.self,

    ]
)
