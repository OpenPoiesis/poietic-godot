//
//  DiagramPresenter+Styles.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 25/08/2025.
//

// NOTE: This file needs to be synced between poietic-tool and poietic-godot.

import Diagramming
import SwiftGodot

// Resources and constants

let TouchShapeRadius: Double = 4.0

let IssueIndicatorIcon: String = "res://resources/icons/error.png"
let IssueIndicatorIconSize: Float = 36.0
let IssueIndicatorIconOffset = Diagramming.Vector2D(x: 0.0, y: -3.0)
let IssueIndicatorZIndex: Int32 = 1000
let DefaultHandleZIndex: Int32 = 900
let DefaultHandleSize: Double = 10.0

// Themeable
let CanvasThemeType = "DiagramCanvas"
let MidpointHandleFillColorKey = "midpoint_handle_fill"
let MidpointHandleOutlineColorKey = "midpoint_handle_outline"
// TODO: Rename to placement_shadow_color
let ShadowColorKey = "placement_shadow_color"

public let SelectionOutlineColorKey = "selection_outline"
public let SelectionFillColorKey = "selection_fill"
public let SelectionMargin: Double = 4.0


public let DefaultFatConnectorFillAlpha: Float = 0.6

// FIXME: Remove once happy with the whole pictogram and diagram composition pipeline
/// Scale used for pictograms during development/prototyping.
let PrototypingPictogramAdjustmentScale: Double = 0.5
