//
//  StockFlowResources.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 20/09/2025.
//

import SwiftGodot
import Diagramming

let StockFlowPictogramsPath: String = "res://resources/stock_flow_pictograms-jolly.json"

// Pictogram icon rendering configuration

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
        headSize: 12.0,
        tailSize: 10.0,
        lineType: .curved
    )),

    "Flow": .fat(FatConnectorStyle(
        headType: .regular,
        tailType: .none,
        headSize: 20.0,
        tailSize: 0.0,
        width: 12.0,
        joinType: .round
    ))
]
// TODO: Merge with StockFlowConnectorStyles
public let StockFlowShapeStyes: [String:ShapeStyle] = [
    "default":   ShapeStyle(lineWidth: 1.0, lineColor: "white", fillColor: "none"),
    "Flow":      ShapeStyle(lineWidth: 1.0, lineColor: "white", fillColor: "gray"),
    "Parameter": ShapeStyle(lineWidth: 1.0, lineColor: "orange", fillColor: "none"),
]

public let PlaceToolPaletteName = "Blocks"

/// Types that can be placed using the ``PlaceTool``.
///
public let BlockNodeTypes: [String] = [
    "Stock",
    "FlowRate",
    "Auxiliary",
    "Cloud",
    "Delay",
    "Smooth"
]
public let DefaultBlockNodeType = "Stock"

public let ConnectToolPaletteName = "Connectors"

/// Connector types that can be created using the ``ConnectTool``.
///
public let ConnectorEdgeTypes: [String] = [
    "Flow",
    "Parameter",
]
/// Edge type used when no item is selected in the tool palette (unlikely, but we want to be safe).
public let DefaultConnectorEdgeType = "Parameter"
