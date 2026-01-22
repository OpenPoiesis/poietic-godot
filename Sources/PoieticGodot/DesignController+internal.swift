//
//  DesignController+internal.swift
//  poietic-godot
//
//  Created by Stefan Urbanek on 21/01/2026.
//

import PoieticCore
import PoieticFlows
import SwiftGodot
import Foundation

extension DesignController {
    func debugPrintIssues(_ issues: DesignIssueCollection) {
        GD.printErr("Validation error")
        for issue in issues.designIssues {
            GD.printErr("  \(issue)")
        }
        for (id, objIssues) in issues.objectIssues {
            GD.printErr("  Object \(id):")
            for issue in objIssues {
                GD.printErr("      \(issue)")
            }
        }
    }
    
    func newTransaction() -> TransientFrame {
        return design.createFrame(deriving: design.currentFrame)
    }
    
    func discard(_ frame: TransientFrame) {
        design.discard(frame)
    }

    func accept(_ frame: TransientFrame) {
        guard frame.hasChanges else {
            design.discard(frame)
            return
        }
        do {
            try design.accept(frame, appendHistory: true)
            GD.print("Design accepted. Current frame: \(frame.id), frame count: \(design.frames.count)")
        }
        catch  {
            // This is not user's fault and never should be.
            // The application failed to make sure structural integrity is assured
            // TODO: Display alert panel.
            GD.pushError("Frame validation error:", String(describing: error))
            return
        }
        run(schedule: FrameChangeSchedule.self)
        simulate()
    }
    func makeFileURL(fromPath path: String) -> URL? {
        // TODO: See same method in poietic-tool
        let url: URL
        let manager = FileManager()
        
        if !manager.fileExists(atPath: path) {
            return nil
        }
        
        // Determine whether the file is a directory or a file
        
        if let attrs = try? manager.attributesOfItem(atPath: path) {
            if attrs[FileAttributeKey.type] as? FileAttributeType == FileAttributeType.typeDirectory {
                url = URL(fileURLWithPath: path, isDirectory: true)
            }
            else {
                url = URL(fileURLWithPath: path, isDirectory: false)
            }
        }
        else {
            url = URL(fileURLWithPath: path)
        }
        
        return url
    }
    
    func writeToCSV(path: String,
                    result: SimulationResult,
                    plan: SimulationPlan,
                    ids: [PoieticCore.ObjectID]) throws {
        var variableIndices: [Int] = []
        variableIndices.append(plan.builtins.step)
        variableIndices.append(plan.builtins.time)
        
        if ids.isEmpty {
            variableIndices += Array(plan.stateVariables.indices)
        }
        else {
            variableIndices += ids.compactMap { plan.variableIndex($0) }
        }

        let writer: CSVWriter = try CSVWriter(path: path)
        let header: [String] = variableIndices.map { plan.stateVariables[$0].name }

        try writer.write(row: header)
        
        for state in result.states {
            var row: [String] = []
            for index in variableIndices {
                let value: PoieticCore.Variant = state[index]
                row.append(try value.stringValue())
            }
            try writer.write(row: row)
            
        }
        try writer.close()
    }
   

}
