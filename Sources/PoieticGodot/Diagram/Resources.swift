//
//  DiagramPresenter+Styles.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 25/08/2025.
//

// NOTE: This file needs to be synced between poietic-tool and poietic-godot.

import Diagramming
import SwiftGodot

let StockFlowPictogramsPath: String = "res://resources/stock_flow_pictograms.json"
let IssueIndicatorIcon: String = "res://resources/icons/error.png"
let IssueIndicatorIconSize: Float = 10.0
let IssueIndicatorIconOffset = Diagramming.Vector2D(x: 0.0, y: -3.0)
let IssueIndicatorZIndex: Int32 = 1000
let DefaultHandleZIndex: Int32 = 900
let DefaultHandleSize: Double = 10.0

// Themeable
let CanvasThemeType = "DiagramCanvas"
let MidpointHandleFillColorKey = "midpoint_handle_fill"
let MidpointHandleOutlineColorKey = "midpoint_handle_outline"
let ShadowColorKey = "shadow_color"



// FIXME: Remove once happy with the whole pictogram and diagram composition pipeline
/// Scale used for pictograms during development/prototyping.
let PrototypingPictogramAdjustmentScale: Double = 0.5

public let StockFlowConnectorStyles: [String:ConnectorStyle] = [
    "default": .thin(ThinConnectorStyle(
        headType: .none,
        tailType: .none,
        headSize: 0.0,
        tailSize: 0.0,
        lineType: .straight
    )),

    "Parameter": .thin(ThinConnectorStyle(
        headType: .stick,
        tailType: .ball,
        headSize: 10.0,
        tailSize: 5.0,
        lineType: .curved
    )),

    "Flow": .fat(FatConnectorStyle(
        headType: .regular,
        tailType: .none,
        headSize: 20.0,
        tailSize: 0.0,
        width: 10.0,
        joinType: .round
    ))
]
