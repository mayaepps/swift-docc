/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

/// An object that writes render nodes, as JSON files, into a target folder.
///
/// The render node writer writes the JSON files into a hierarchy of folders and subfolders based on the relative URL for each node.
class JSONEncodingRenderNodeWriter {
    /// Errors that may occur while writing render node JSON files.
    enum Error: DescribedError {
        /// A file already exist at this path.
        case fileExists(String)
        /// The absolute path to the file is too long.
        public var errorDescription: String {
            switch self {
            case .fileExists(let path): return "File already exists at: '\(path)'"
            }
        }
    }
    
    private let urlGenerator: NodeURLGenerator
    private let fileManager: FileManagerProtocol
    private let renderReferenceCache = RenderReferenceCache([:])
    
    /// The changes (modifications, additions, deprecations) made to nodes in the index between archive versions.
    let differencesCache: Synchronized<[String : [String : RenderIndexChange]]>?
    
    /// Creates a writer object that write render node JSON into a given folder.
    ///
    /// - Parameters:
    ///   - targetFolder: The folder to which the writer object writes the files.
    ///   - fileManager: The file manager with which the writer object writes data to files.
    init(targetFolder: URL, fileManager: FileManagerProtocol, buildDifferencesCache: Bool = false) {
        self.urlGenerator = NodeURLGenerator(
            baseURL: targetFolder.appendingPathComponent("data", isDirectory: true)
        )
        self.fileManager = fileManager
        
        if buildDifferencesCache {
            self.differencesCache = Synchronized<[String : [String : RenderIndexChange]]>([:])
        } else {
            self.differencesCache = nil
        }
    }
    
    // The already created directories on disk
    let directoryIndex = Synchronized(Set<URL>())
    
    

    /// Writes a render node to a JSON file at a location based on the node's relative URL.
    ///
    /// If the target path to the JSON file includes intermediate folders that don't exist, the writer object will ask the file manager, with which it was created, to
    /// create those intermediate folders before writing the JSON file.
    ///
    /// - Parameter renderNode: The node which the writer object writes to a JSON file.
    /// - Throws: A ``Error/fileExists`` error if a file already exists at the location for this node's JSON file.
    func write(_ renderNode: RenderNode) throws {
        // The path on disk to write the render node JSON file at.
        let targetFileURL = urlGenerator
            .urlForReference(
                renderNode.identifier,
                // Lowercase the URL on disk so that it matches the casing used for topic references in render nodes.
                // It's important that the casing matches for case-sensitive file systems.
                lowercased: true
            )
            .appendingPathExtension("json")
        
        let targetFolderURL = targetFileURL.deletingLastPathComponent()
        
        // On Linux sometimes it takes a moment for the directory to be created and that leads to
        // errors when trying to write files concurrently in the same target location.
        // We keep an index in `directoryIndex` and create new sub-directories as needed.
        // When the symbol's directory already exists no code is executed during the lock below
        // besides the set lookup.
        try directoryIndex.sync {
            if !$0.contains(targetFileURL) {
                $0.insert(targetFileURL)
                try fileManager.createDirectory(at: targetFolderURL, withIntermediateDirectories: true, attributes: nil)
            }
        }
        
        let encoder = RenderJSONEncoder.makeEncoder()
        
        // Get the previous RenderNode from the target file URL to diff against.
        do {
            let targetFileData = try Data(contentsOf: targetFileURL)
            let previousRenderNode = try RenderNode.decode(fromJSON: targetFileData)
            
            encoder.userInfoPreviousNode = previousRenderNode
        } catch {
            // This is a new RenderNode--there is no previous node to diff against.
            
            let previousVersionID = "previousVersionIDHere" // TODO: get the previous version from somewhere... metadata.json maybe?
            differencesCache?.sync { differentReferences in
                if differentReferences[renderNode.identifier.path] != nil {
                    differentReferences[renderNode.identifier.path]![previousVersionID] = RenderIndexChange.added
                } else {
                    differentReferences[renderNode.identifier.path] = [previousVersionID : RenderIndexChange.added]
                }
            }
        }
        
        let data = try renderNode.encodeToJSON(with: encoder, renderReferenceCache: renderReferenceCache)
        try fileManager.createFile(at: targetFileURL, contents: data)
    }
}
