// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftGodot

#initSwiftExtension(
    cdecl: "swift_entry_point",
    types: [
        PoieticMetamodel.self,
        PoieticDesignController.self,
        PoieticTransaction.self,
        PoieticObject.self,
        PoieticSelection.self,
        
        PoieticActionResult.self,
        PoieticIssue.self,
    ]
)

