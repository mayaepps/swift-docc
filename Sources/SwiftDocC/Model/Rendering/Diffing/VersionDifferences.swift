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
public struct VersionPatch: Codable, Equatable {
        
    let version: ArchiveVersion
    public var patch: JSONPatch
    
    public mutating func add(_ patchOperation: JSONPatchOperation) {
        patch.append(patchOperation)
    }
    
    public mutating func add<PatchOperations>(
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
public struct ArchiveVersion: Codable, Equatable {
    public var identifier: String
    public var displayName: String
    
    enum ArchiveVersionError: Error {
        case versionDisplayNameNotUnique
        case versionIdentifierNotUnique
    }
    
    public func checkIsUniqueFrom( otherVersions: [ArchiveVersion]) throws {
        if otherVersions.map({ $0.displayName }).contains(displayName) {
            print("You cannot repeat version display names!")
            throw ArchiveVersionError.versionDisplayNameNotUnique
        }
        
        if otherVersions.map({ $0.identifier }).contains(identifier) {
            print("You cannot repeat version identifiers!")
            throw ArchiveVersionError.versionIdentifierNotUnique
        }
    }
}
