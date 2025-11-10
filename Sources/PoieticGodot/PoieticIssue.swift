//
//  PoieticIssue.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 15/09/2025.
//

import SwiftGodot
import PoieticCore

// TODO: Make this just a dictionary [String:SwiftGodot.Variant]
@Godot
public class PoieticIssue: SwiftGodot.RefCounted {
    var issue: Issue! = nil

    @Export var system: String {
        get { issue.system}
        set { readOnlyAttributeError() }
    }
    @Export var severity: String {
        get { issue.severity.description }
        set { readOnlyAttributeError() }
    }
    @Export var identifier: String {
        get { issue.identifier }
        set { readOnlyAttributeError() }
    }
    @Export var message: String {
        get { issue.message }
        set { readOnlyAttributeError() }
    }
    @Export var hints: PackedStringArray {
        get { PackedStringArray(issue.hints) }
        set { readOnlyAttributeError() }
    }
    @Export var attribute: String? {
        get { try? issue.details["attribute"]?.stringValue() }
        set { readOnlyAttributeError() }
    }
    @Export var details: TypedDictionary<String,SwiftGodot.Variant?> {
        get {
            var dict = TypedDictionary<String,SwiftGodot.Variant?>()
            for (key, value) in issue.details {
                dict[key] = value.asGodotVariant()
            }
            return dict
        }
        set { readOnlyAttributeError() }
    }
    @Export var relatedObjects: PackedInt64Array {
        get {
            return PackedInt64Array(compactingValid: issue.relatedObjects)
        }
        set { readOnlyAttributeError() }
    }
}
