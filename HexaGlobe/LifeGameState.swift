//
//  LifeGameState.swift
//  HexaGlobe
//
//  Created by Michael Rockhold on 5/25/21.
//

import Foundation

protocol CellInfo {
    var cellID: Int { get }
    var neighbors: [Int] { get }
}

protocol CellInfoSource: Sequence where Element: CellInfo {
    
}


struct LifeGameState<T: CellInfoSource> {
    let cellInfoSource: T
    let liveCellIndices: IndexSet
    
    func applyRules(_ cellInfo: CellInfo) -> Bool {
        var liveCellCount = liveCellIndices.contains(cellInfo.cellID) ? 1 : 0
        let liveNeighbors = cellInfo.neighbors.filter { liveCellIndices.contains($0) }
        liveCellCount += liveNeighbors.count
        
        if cellInfo.neighbors.count == 5 { // Pentagon: liveCellCount may range from 0 to 6
            return liveCellCount > 2 && liveCellCount < 5
        } else { // Hexagon: liveCellCount may range from 0 to 7
            return liveCellCount > 2 && liveCellCount < 6
        }
    }
    
    func nextState() -> LifeGameState {
        var s = IndexSet()
        
        for cellInfo in cellInfoSource {
            let newCellState = applyRules(cellInfo)
            if newCellState {
                s.insert(cellInfo.cellID)
            }
        }
        
        return LifeGameState(cellInfoSource: cellInfoSource, liveCellIndices: s)
    }
}
