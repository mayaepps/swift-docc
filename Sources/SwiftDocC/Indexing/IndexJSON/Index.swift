/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SymbolKit
import Foundation

/// A navigation index of the content in a DocC archive, optimized for rendering.
///
/// The structure of this data is determined by the topic groups authored in
/// the processed documentation content.
///
/// This is an alternative representation of the data that is also handled by the
/// ``NavigatorIndex`` in a ``NavigatorTree``. This index is specifically designed to be emitted
/// to disk as JSON file and implements the RenderIndex JSON spec.
///
/// An OpenAPI specification for RenderIndex is available in the repo at
/// `Sources/SwiftDocC/SwiftDocC.docc/Resources/RenderIndex.spec.json`.
public struct RenderIndex: Codable, Equatable {
    /// The current schema version of the Index JSON spec.
    public static let currentSchemaVersion = SemanticVersion(major: 0, minor: 1, patch: 0)
    
    /// The version of the RenderIndex spec that was followed when creating this index.
    public let schemaVersion: SemanticVersion
    
    /// A mapping of interface languages to the index nodes they contain.
    public let interfaceLanguages: [String: [Node]]
    
    /// Metadata about the RenderIndex.
    public let metadata: RenderIndexMetadata?
    
    /// Information about previous version of this RenderIndex.
    public let versions: [VersionPatch]?
    
    /// A mapping of node identifiers to what type of change should be rendered when this version of the archive is diffed against previous versions
    public var versionDifferences: [String : [String : RenderIndexChange]]?
    
    /// Creates a new render index with the given interface language to node mapping.
    public init(
        interfaceLanguages: [String: [Node]],
        versions: [VersionPatch]? = [],
        currentVersion: ArchiveVersion? = nil,
        versionDifferences: [String : [String : RenderIndexChange]]? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.interfaceLanguages = interfaceLanguages
        self.versions = versions
        if let currentVersion = currentVersion {
            self.metadata = RenderIndexMetadata(version: currentVersion)
        } else {
            self.metadata = nil
        }
        self.versionDifferences = versionDifferences
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(interfaceLanguages, forKey: .interfaceLanguages)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfPresent(versionDifferences, forKey: .versionDifferences)
        
        // If given a previous index, diff between it and this RenderNode.
        if let previousIndex = encoder.userInfoPreviousIndex {
            
            // If diffing against a previous version, this index must have a version.
            let newVersionPatch = VersionPatch(
                archiveVersion: previousIndex.metadata?.version ?? ArchiveVersion(identifier: "N/A", displayName: "N/A"),
                jsonPatch: previousIndex.difference(from: self, at: encoder.codingPath))
            
            var newVersions = [VersionPatch]() // versions <-- For now, only diffing two versions for ease of testing.
            newVersions.append(newVersionPatch)
            
            try container.encode(newVersions, forKey: .versions)
        }
    }
}

extension RenderIndex {
    /// A documentation node in a documentation render index.
    public struct Node: Codable, Hashable, Equatable {
        /// The title of the node, suitable for presentation.
        public let title: String
        
        /// The relative path to the page represented by this node.
        public let path: String?
        
        /// The type of this node.
        ///
        /// This type can be used to determine what icon to display for this node.
        public let type: String?
        
        /// The children of this node.
        public let children: [Node]?
        
        /// A Boolean value that is true if the current node has been marked as deprecated on any platform.
        ///
        /// Allows renderers to use a specific design treatment for render index nodes that mark the node as deprecated.
        public let isDeprecated: Bool

        /// A Boolean value that is true if the current node belongs to an external
        /// documentation archive.
        ///
        /// Allows renderers to use a specific design treatment for render index nodes
        /// that lead to external documentation content.
        public let isExternal: Bool
        
        /// A Boolean value that is true if the current node has been marked as is beta
        ///
        /// Allows renderers to use a specific design treatment for render index nodes that mark the node as in beta.
        public let isBeta: Bool

        enum CodingKeys: String, CodingKey {
            case title
            case path
            case type
            case children
            case deprecated
            case external
            case beta
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(title, forKey: .title)
            
            try container.encodeIfPresent(path, forKey: .path)
            try container.encodeIfPresent(type, forKey: .type)
            try container.encodeIfPresent(children, forKey: .children)
            
            // `isDeprecated` defaults to false so only encode it if it's true
            if isDeprecated {
                try container.encode(isDeprecated, forKey: .deprecated)
            }
            
            // `isExternal` defaults to false so only encode it if it's true
            if isExternal {
                try container.encode(isExternal, forKey: .external)
            }
            
            // `isBeta` defaults to false so only encode it if it's true
            if isBeta {
                try container.encode(isBeta, forKey: .beta)
            }
        }
        
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            
            title = try values.decode(String.self, forKey: .title)
            
            path = try values.decodeIfPresent(String.self, forKey: .path)
            type = try values.decodeIfPresent(String.self, forKey: .type)
            children = try values.decodeIfPresent([Node].self, forKey: .children)
            
            // `isDeprecated` defaults to false if it's not specified
            isDeprecated = try values.decodeIfPresent(Bool.self, forKey: .deprecated) ?? false
            
            // `isExternal` defaults to false if it's not specified
            isExternal = try values.decodeIfPresent(Bool.self, forKey: .external) ?? false
            
            // `isBeta` defaults to false if it's not specified
            isBeta = try values.decodeIfPresent(Bool.self, forKey: .beta) ?? false
        }
        
        /// Creates a new node with the given title, path, type, and children.
        ///
        /// - Parameters:
        ///   - title: The title of the node, suitable for presentation.
        ///   - path: The relative path to the page represented by this node.
        ///   - type: The type of this node.
        ///   - children: The children of this node.
        ///   - isDeprecated : If the current node has been marked as deprecated.
        ///   - isExternal: If the current node belongs to an external
        ///     documentation archive.
        ///   - isBeta: If the current node is in beta.
        public init(
            title: String,
            path: String?,
            type: String,
            children: [Node]?,
            isDeprecated: Bool,
            isExternal: Bool,
            isBeta: Bool
        ) {
            self.title = title
            self.path = path
            self.type = type
            self.children = children
            self.isDeprecated = isDeprecated
            self.isExternal = isExternal
            self.isBeta = isBeta
        }
        
        init(
            title: String,
            path: String,
            pageType: NavigatorIndex.PageType?,
            isDeprecated: Bool,
            children: [Node]
        ) {
            self.title = title
            self.children = children.isEmpty ? nil : children
            
            self.isDeprecated = isDeprecated
            
            // Currently Swift-DocC doesn't support resolving links to external DocC archives
            // so we default to `false` here.
            self.isExternal = false
            
            self.isBeta = false
            
            guard let pageType = pageType else {
                self.type = nil
                self.path = path
                return
            }
            
            self.type = pageType.renderIndexPageType
            
            if pageType.pathShouldBeIncludedInRenderIndex {
                self.path = path
            } else {
                self.path = nil
            }
        }
    }
}

extension RenderIndex {
    static func fromNavigatorIndex(_ navigatorIndex: NavigatorIndex, with builder: NavigatorIndex.Builder, differencesCache: Synchronized<[String:[String:RenderIndexChange]]>? = nil) -> RenderIndex {
        // The immediate children of the root represent the interface languages
        // described in this navigator tree.
        let interfaceLanguageRoots = navigatorIndex.navigatorTree.root.children
        
        let languageMaskToLanguage = navigatorIndex.languageMaskToLanguage
        
        return RenderIndex(
            interfaceLanguages: Dictionary(
                interfaceLanguageRoots.compactMap { interfaceLanguageRoot in
                    // If an interface language in the given navigator tree does not exist
                    // in the given language mask to language mapping, something has gone wrong
                    // and we should crash.
                    let languageID = languageMaskToLanguage[interfaceLanguageRoot.item.languageID]!.id
                    
                    return (
                        language: languageID,
                        children: interfaceLanguageRoot.children.map {
                            RenderIndex.Node.fromNavigatorTreeNode($0, in: navigatorIndex, with: builder)
                        }
                    )
                },
                uniquingKeysWith: +
            ),
            currentVersion: builder.indexVersion,
            versionDifferences: differencesCache?.sync { differences in
                return differences
            }
        )
    }
}

extension RenderIndex.Node {
    static func fromNavigatorTreeNode(_ node: NavigatorTree.Node, in navigatorIndex: NavigatorIndex, with builder: NavigatorIndex.Builder) -> RenderIndex.Node {
        // If this node was deprecated on any platform version mark it as deprecated.
        let isDeprecated: Bool
        
        let availabilityIndexEntryIDsForNode = builder.availabilityEntryIDs(for: node.item.availabilityID)
        if let entryIDs = availabilityIndexEntryIDsForNode {
            let availabilityInfosForNode = entryIDs.map { ID in navigatorIndex.availabilityIndex.info(for: ID) }
            // Mark node as deprecated if we have an explicit deprecation version
            isDeprecated = availabilityInfosForNode.contains { $0?.deprecated != nil }
        } else {
            isDeprecated = false
        }
        
        return RenderIndex.Node(
            title: node.item.title,
            path: node.item.path,
            pageType: NavigatorIndex.PageType(rawValue: node.item.pageType),
            isDeprecated: isDeprecated,
            children: node.children.map {
                RenderIndex.Node.fromNavigatorTreeNode($0, in: navigatorIndex, with: builder)
            }
        )
    }
}

extension NavigatorIndex.PageType {
    var pathShouldBeIncludedInRenderIndex: Bool {
        switch self {
        case .root, .section, .groupMarker:
            return false
        default:
            return true
        }
    }
    
    var renderIndexPageType: String? {
        switch self {
        case .root:
            return "root"
        case .article:
            return RenderNode.Kind.article.rawValue
        case .tutorial:
            return RenderNode.Kind.tutorial.rawValue
        case .section:
            return RenderNode.Kind.section.rawValue
        case .learn:
            return "learn"
        case .overview:
            return RenderNode.Kind.overview.rawValue
        case .resources:
            return "resources"
        case .symbol:
            return  RenderNode.Kind.symbol.rawValue
        case .framework:
            return SymbolGraph.Symbol.KindIdentifier.module.renderingIdentifier
        case .class:
            return SymbolGraph.Symbol.KindIdentifier.class.renderingIdentifier
        case .structure:
            return SymbolGraph.Symbol.KindIdentifier.struct.renderingIdentifier
        case .protocol:
            return SymbolGraph.Symbol.KindIdentifier.protocol.renderingIdentifier
        case .enumeration:
            return SymbolGraph.Symbol.KindIdentifier.enum.renderingIdentifier
        case .function:
            return SymbolGraph.Symbol.KindIdentifier.func.renderingIdentifier
        case .extension:
            return "extension"
        case .localVariable, .globalVariable, .instanceVariable:
            return SymbolGraph.Symbol.KindIdentifier.var.renderingIdentifier
        case .typeAlias:
            return SymbolGraph.Symbol.KindIdentifier.typealias.renderingIdentifier
        case .associatedType:
            return SymbolGraph.Symbol.KindIdentifier.associatedtype.renderingIdentifier
        case .operator:
            return SymbolGraph.Symbol.KindIdentifier.operator.renderingIdentifier
        case .macro:
            return "macro"
        case .union:
            return "union"
        case .enumerationCase:
            return SymbolGraph.Symbol.KindIdentifier.case.renderingIdentifier
        case .initializer:
            return SymbolGraph.Symbol.KindIdentifier.`init`.renderingIdentifier
        case .instanceMethod:
            return SymbolGraph.Symbol.KindIdentifier.method.renderingIdentifier
        case .instanceProperty:
            return SymbolGraph.Symbol.KindIdentifier.property.renderingIdentifier
        case .subscript:
            return SymbolGraph.Symbol.KindIdentifier.subscript.renderingIdentifier
        case .typeMethod:
            return SymbolGraph.Symbol.KindIdentifier.typeMethod.renderingIdentifier
        case .typeProperty:
            return SymbolGraph.Symbol.KindIdentifier.typeProperty.renderingIdentifier
        case .buildSetting:
            return "buildSetting"
        case .propertyListKey:
            return "propertyListKey"
        case .sampleCode:
            return "sampleCode"
        case .httpRequest:
            return "httpRequest"
        case .dictionarySymbol:
            return "dictionarySymbol"
        case .propertyListKeyReference:
            return "propertyListKeyReference"
        case .languageGroup:
            return "languageGroup"
        case .container:
            return "container"
        case .groupMarker:
            return "groupMarker"
        }
    }
}

/// Metadata about a RenderIndex, such as the index's current version.
public struct RenderIndexMetadata: Equatable, Codable {
    
    /// The version of the archive that contains this RenderIndex.
    public let version: ArchiveVersion
    
}

extension RenderIndex: Diffable {
    func difference(from other: RenderIndex, at path: Path) -> Differences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)
        
        diffBuilder.addDifferences(atKeyPath: \.schemaVersion, forKey: CodingKeys.schemaVersion)
        diffBuilder.addDifferences(atKeyPath: \.interfaceLanguages, forKey: CodingKeys.interfaceLanguages)
        diffBuilder.addDifferences(atKeyPath: \.metadata, forKey: CodingKeys.metadata)
        
        return diffBuilder.differences
    }
}

extension RenderIndex.Node: Diffable {
    func difference(from other: RenderIndex.Node, at path: Path) -> Differences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)
        
        diffBuilder.addDifferences(atKeyPath: \.title, forKey: CodingKeys.title)
        diffBuilder.addDifferences(atKeyPath: \.path, forKey: CodingKeys.path)
        diffBuilder.addDifferences(atKeyPath: \.type, forKey: CodingKeys.type)
        diffBuilder.addDifferences(atKeyPath: \.children, forKey: CodingKeys.children)
        diffBuilder.addDifferences(atKeyPath: \.isDeprecated, forKey: CodingKeys.deprecated)
        diffBuilder.addDifferences(atKeyPath: \.isExternal, forKey: CodingKeys.external)
        diffBuilder.addDifferences(atKeyPath: \.isBeta, forKey: CodingKeys.beta)
        
        return diffBuilder.differences
    }
    
    func isSimilar(to other: RenderIndex.Node) -> Bool {
        return title == other.title || ((children != nil) && children == other.children) || ((path != nil) && path == other.path) || ((type != nil) && type == other.type)
    }
}
