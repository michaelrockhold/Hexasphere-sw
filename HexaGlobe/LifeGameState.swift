//
//  LifeGameState.swift
//  HexaGlobe
//
//  Created by Michael Rockhold on 5/25/21.
//

import Foundation

protocol CellInfo {
    var cellID: Int { get }
    var neighbors: Set<Int> { get }
}

protocol CellInfoSource: Collection where Element: CellInfo {}

struct LifeGameState<T: CellInfoSource> where T.Index: Strideable, T.Index.Stride: SignedInteger {
    let cellInfoSource: T
    let liveCellIndices: IndexSet
    let familyID = UUID().uuidString

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
        
        let waitGroup = DispatchGroup()
        let workQueue = DispatchQueue(label: "LifeGameState.\(familyID).nextState", attributes: .concurrent)
        let outputQueue = DispatchQueue(label: "LifeGameState.\(familyID).reduce")
        var result = IndexSet()

        func processOneSegment(_ cells: T.SubSequence) {
            waitGroup.enter()
            var s = IndexSet()
            workQueue.async(qos: .utility) {
                for cellInfo in cells {
                    let newCellState = applyRules(cellInfo)
                    if newCellState {
                        s.insert(cellInfo.cellID)
                    }
                }
                outputQueue.sync {
                    result.formUnion(s)
                }
                waitGroup.leave()
            }
        }

        let taskCount = Int(Double(cellInfoSource.count).squareRoot().rounded())
        let segmentSize = cellInfoSource.count / taskCount
        let extras = cellInfoSource.count % taskCount
        
        var first = cellInfoSource.startIndex
        var last = cellInfoSource.index(first, offsetBy: segmentSize + extras)

        for _ in 0..<taskCount {
            processOneSegment(cellInfoSource[first..<last])
            
            first = last
            if last < cellInfoSource.endIndex {
                last = cellInfoSource.index(last, offsetBy: segmentSize)
            }
        }

        waitGroup.wait()
        return LifeGameState(cellInfoSource: cellInfoSource, liveCellIndices: result)
    }
}
