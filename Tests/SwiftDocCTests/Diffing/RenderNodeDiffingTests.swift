//
//  File.swift
//  
//
//  Created by Maya Epps on 5/31/22.
//

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
        encoder.userInfoVersionPatch = VersionPatch(id: "testID", name: "Test display name", jsonPatch: [])
        
        let encodedNode = try encoder.encode(renderNodeArticle)
        print(String(data: encodedNode, encoding: .utf8)!)
    }
    
    func testDiffingAbstractFromFile() throws {
        
        let renderNodeWithAbstractURL = Bundle.module.url(
            forResource: "RenderNodeWithAbstract", withExtension: "json", subdirectory: "Test Resources")!
        let renderNodeNoAbstractURL = Bundle.module.url(
            forResource: "RenderNodeNoAbstract", withExtension: "json", subdirectory: "Test Resources")!
        
        let abstractData = try Data(contentsOf: renderNodeWithAbstractURL)
        let noAbstractData = try Data(contentsOf: renderNodeNoAbstractURL)
        let abstractSymbol = try RenderNode.decode(fromJSON: abstractData)
        let noAbstractSymbol = try RenderNode.decode(fromJSON: noAbstractData)
        
        let encoder = RenderJSONEncoder.makeEncoder()
        encoder.userInfoPreviousNode = noAbstractSymbol
        encoder.userInfoVersionPatch = VersionPatch(id: "testID", name: "Test display name", jsonPatch: [])
        let encodedNode = try encoder.encode(abstractSymbol)
        print(String(data: encodedNode, encoding: .utf8)!)
    }
}
