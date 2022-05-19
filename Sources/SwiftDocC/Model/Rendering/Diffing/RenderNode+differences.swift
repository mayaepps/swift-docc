/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension RenderNode {
    /// Returns the differences between this render node and the given one.
    public func difference(from other: RenderNode) -> [String: Any] {
        // Diff the abstract:
        let currentAbstract = abstract ?? []
        let otherAbstract = other.abstract ?? []
        let abstractDifference = otherAbstract.difference(from: currentAbstract)
        
        return [
            "abstract": abstractDifference
        ]
    }
}
