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
        PoieticTransaction.self,
        PoieticSelection.self,
        PoieticDiagramChange.self,
        
        
        // Diagram Canvas
        PoieticDiagramController.self,
        PoieticCanvas.self,
        PoieticCanvasObject.self,
        PoieticConnector.self,
        PoieticBlock.self,

    ]
)
