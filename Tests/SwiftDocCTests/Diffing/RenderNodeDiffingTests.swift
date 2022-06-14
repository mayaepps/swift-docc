/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC
import SwiftDocCTestUtilities

class RenderNodeDiffingTests: XCTestCase {
    func testDiffingKind() throws {
        
        let renderNodeArticle = RenderNode(
            identifier: .init(bundleIdentifier: "com.bundle", path: "/", sourceLanguage: .swift),
            kind: .article
        )

        let renderNodeSymbol = RenderNode(
            identifier: .init(bundleIdentifier: "com.bundle", path: "/", sourceLanguage: .swift),
            kind: .symbol
        )
        
        let encoder = RenderJSONEncoder.makeEncoder()
        encoder.userInfoPreviousNode = renderNodeSymbol
        
        let encodedNode = try encoder.encode(renderNodeArticle)
        print(String(data: encodedNode, encoding: .utf8)!)
    }
    
    func testDiffingFromFile() throws {
        
        let renderNodev1URL = Bundle.module.url(
            forResource: "RenderNodev1", withExtension: "json", subdirectory: "Test Resources")!
        let renderNodev2URL = Bundle.module.url(
            forResource: "RenderNodev2", withExtension: "json", subdirectory: "Test Resources")!
        
        let datav1 = try Data(contentsOf: renderNodev1URL)
        let datav2 = try Data(contentsOf: renderNodev2URL)
        let symbolv1 = try RenderNode.decode(fromJSON: datav1)
        let symbolv2 = try RenderNode.decode(fromJSON: datav2)
        
        let encoder = RenderJSONEncoder.makeEncoder()
        encoder.userInfoPreviousNode = symbolv1
        let encodedNode = try encoder.encode(symbolv2)
        print(String(data: encodedNode, encoding: .utf8)!)
    }
}

