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
    var issue: DesignIssue! = nil

    @Export var domain: String {
        get { issue.domain.description}
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
    @Export var hint: String? {
        get { issue.hint }
        set { readOnlyAttributeError() }
    }
    @Export var attribute: String? {
        get { try? issue.details["attribute"]?.stringValue() }
        set { readOnlyAttributeError() }
    }
    @Export var details: GDictionary {
        get {
            var dict = GDictionary()
            for (key, value) in issue.details {
                dict[key] = value.asGodotVariant()
            }
            return dict
        }
        set { readOnlyAttributeError() }
    }
}
