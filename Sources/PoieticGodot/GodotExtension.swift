// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftGodot

#initSwiftExtension(
    cdecl: "swift_entry_point",
    types: [
        // Controllers
        PoieticApplication.self,
        DesignController.self,
        SelectionManager.self,
        ResultPlayer.self,

        // Design content and other data
        PoieticObject.self,
        PoieticIssue.self,
        PoieticResult.self,
        PoieticTimeSeries.self,

        // Auxiliary objects
        PoieticTransaction.self, // TODO: Remove in favour of command objects

        // Tool
        CanvasTool.self,
        SelectionTool.self,
        PlaceTool.self,
        ConnectTool.self,
        PanTool.self,

        // Diagram Canvas
        DiagramController.self,
        DiagramCanvas.self,
        DiagramCanvasObject.self,
        DiagramCanvasConnector.self,
        DiagramCanvasBlock.self,
        
        CanvasHitTarget.self,
        CanvasHandle.self,
        CanvasIssueIndicator.self,

    ]
)
