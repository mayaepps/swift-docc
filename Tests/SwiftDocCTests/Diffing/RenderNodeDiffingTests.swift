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
        encoder.userInfoVersionPatch = VersionPatch(archiveVersion: ArchiveVersion(versionID: "testID", displayName: "Test display name"), jsonPatch: [])
        
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
        encoder.userInfoVersionPatch = VersionPatch(archiveVersion: ArchiveVersion(versionID: "testID", displayName: "Test display name"), jsonPatch: [])
        let encodedNode = try encoder.encode(symbolv2)
        print(String(data: encodedNode, encoding: .utf8)!)
    }
}

