/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/


import Foundation

/// Defines differences between documentation content versions.
///
/// This class can be used to accumulate difference information in the form of a JSONPatch while encoding a tree of objects.
public class VersionPatch: Codable {
        
    let version: ArchiveVersion
    public var patch: JSONPatch
    
    public func add(_ patchOperation: JSONPatchOperation) {
        patch.append(patchOperation)
    }
    
    public func add<PatchOperations>(
        contentsOf patchOperations: PatchOperations
    ) where PatchOperations: Collection, PatchOperations.Element == JSONPatchOperation {
        for operation in patchOperations {
            add(operation)
        }
    }
    
    init(archiveVersion: ArchiveVersion, jsonPatch: JSONPatch) {
        version = archiveVersion
        patch = jsonPatch
    }
        
}

/// Defines a version of a framework.
///
/// This struct can be used to group a version's unique identifier with its display name.
struct ArchiveVersion: Codable {
    public var versionID: String
    public var displayName: String
}
