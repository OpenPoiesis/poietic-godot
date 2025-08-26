//
//  DiagramPresenter+Styles.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 25/08/2025.
//

// NOTE: This file needs to be synced between poietic-tool and poietic-godot.

import Diagramming

let StockFlowPictogramsPath: String = "res://resources/stock_flow_pictograms.json"

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
