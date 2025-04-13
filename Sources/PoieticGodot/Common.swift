//
//  Common.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 13/04/2025.
//

import SwiftGodot

func readOnlyAttributeError(function: StaticString = #function) {
    GD.pushError("Trying to set a read-only variable \(function)")
}
