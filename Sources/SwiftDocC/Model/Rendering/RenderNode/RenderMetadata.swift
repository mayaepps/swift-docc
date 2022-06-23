/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Arbitrary metadata for a render node.
public struct RenderMetadata: VariantContainer {
    
    // MARK: Tutorials metadata
    
    /// The name of technology associated with a tutorial.
    public var category: String?
    public var categoryPathComponent: String?
    /// A description of the estimated time to complete the tutorials of a technology.
    public var estimatedTime: String?
    
    // MARK: Symbol metadata
    
    /// The modules that the symbol is apart of.
    public var modules: [Module]? {
        get { getVariantDefaultValue(keyPath: \.modulesVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.modulesVariants) }
    }
    
    /// The variants for the modules.
    public var modulesVariants: VariantCollection<[Module]?> = .init(defaultValue: nil)
    
    /// The name of the module extension in which the symbol is defined, if applicable.
    public var extendedModule: String? {
        get { getVariantDefaultValue(keyPath: \.extendedModuleVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.extendedModuleVariants) }
    }
    
    /// The variants for the module extension.
    public var extendedModuleVariants: VariantCollection<String?> = .init(defaultValue: nil)
    
    /// The platform availability information about a symbol.
    public var platforms: [AvailabilityRenderItem]? {
        get { getVariantDefaultValue(keyPath: \.platformsVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.platformsVariants) }
    }
    
    /// The variants for the platforms.
    public var platformsVariants: VariantCollection<[AvailabilityRenderItem]?> = .init(defaultValue: nil)
    
    /// Whether protocol method is required to be implemented by conforming types.
    public var required: Bool {
        get { getVariantDefaultValue(keyPath: \.requiredVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.requiredVariants) }
    }

    /// The variants for the `required` property.
    public var requiredVariants: VariantCollection<Bool> = .init(defaultValue: false)
    
    /// A heading describing the type of the document.
    public var roleHeading: String? {
        get { getVariantDefaultValue(keyPath: \.roleHeadingVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.roleHeadingVariants) }
    }
    
    /// The variants of the role heading.
    public var roleHeadingVariants: VariantCollection<String?> = .init(defaultValue: nil)
    
    /// The role of the document.
    ///
    /// Examples of document roles include "symbol" or "sampleCode".
    public var role: String?
    
    /// The title of the page.
    public var title: String? {
        get { getVariantDefaultValue(keyPath: \.titleVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.titleVariants) }
    }
    
    /// The variants of the title.
    public var titleVariants: VariantCollection<String?> = .init(defaultValue: nil)
    
    /// An identifier for a symbol generated externally.
    public var externalID: String? {
        get { getVariantDefaultValue(keyPath: \.externalIDVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.externalIDVariants) }
    }
    
    /// The variants of the external ID.
    public var externalIDVariants: VariantCollection<String?> = .init(defaultValue: nil)
    
    /// The kind of a symbol, e.g., "class" or "func".
    public var symbolKind: String? {
        get { getVariantDefaultValue(keyPath: \.symbolKindVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.symbolKindVariants) }
    }
    
    /// The variants of the symbol kind.
    public var symbolKindVariants: VariantCollection<String?> = .init(defaultValue: nil)
    
    /// The access level of a symbol, e.g., "public" or "private".
    public var symbolAccessLevel: String? {
        get { getVariantDefaultValue(keyPath: \.symbolAccessLevelVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.symbolAccessLevelVariants) }
    }
    
    /// The variants for the access level of a symbol.
    public var symbolAccessLevelVariants: VariantCollection<String?> = .init(defaultValue: nil)
    
    /// Abbreviated declaration to display in links.
    public var fragments: [DeclarationRenderSection.Token]? {
        get { getVariantDefaultValue(keyPath: \.fragmentsVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.fragmentsVariants) }
    }
    
    /// The variants for the fragments of a page.
    public var fragmentsVariants: VariantCollection<[DeclarationRenderSection.Token]?> = .init(defaultValue: nil)
    
    /// Abbreviated declaration to display in navigators.
    public var navigatorTitle: [DeclarationRenderSection.Token]? {
        get { getVariantDefaultValue(keyPath: \.navigatorTitleVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.navigatorTitleVariants) }
    }
    
    /// The variants for the navigator title of a page.
    public var navigatorTitleVariants: VariantCollection<[DeclarationRenderSection.Token]?> = .init(defaultValue: nil)
    
    /// Additional metadata associated with the render node.
    public var extraMetadata: [CodingKeys: Any] = [:]
    
    /// Information the availability of generic APIs.
    public var conformance: ConformanceSection?
    
    /// The URI of the source file in which the symbol was originally declared, suitable for display in a user interface.
    ///
    /// This information may not (and should not) always be available for many reasons,
    /// such as compiler infrastructure limitations, or filesystem privacy and security concerns.
    public var sourceFileURI: String? {
        get { getVariantDefaultValue(keyPath: \.sourceFileURIVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.sourceFileURIVariants) }
    }
    
    /// The variants for the source file URI of a page.
    public var sourceFileURIVariants: VariantCollection<String?> = .init(defaultValue: nil)
    
    /// Any tags assigned to the node.
    public var tags: [RenderNode.Tag]?
    
    /// The archive version that this node belongs to.
    public var version: ArchiveVersion?
}

extension RenderMetadata: Codable {
    /// A list of pre-defined roles to assign to nodes.
    public enum Role: String, Equatable {
        case symbol, containerSymbol, restRequestSymbol, dictionarySymbol, pseudoSymbol, pseudoCollection, collection, collectionGroup, article, sampleCode, unknown
        case table, codeListing, link, subsection, task, overview
        case tutorial = "project"
    }
    
    /// Metadata about a module dependency.
    public struct Module: Codable, Diffable, Equatable {
        public let name: String
        /// Possible dependencies to the module, we allow for those in the render JSON model
        /// but have no authoring support at the moment.
        public let relatedModules: [String]?

        /// Returns the difference between two RenderMetadata.Modules.
        public func difference(from other: RenderMetadata.Module, at path: Path) -> Differences {
            var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)
            
            diffBuilder.addDifferences(atKeyPath: \.name, forKey: CodingKeys.name)
            diffBuilder.addDifferences(atKeyPath: \.relatedModules, forKey: CodingKeys.relatedModules)

            return diffBuilder.differences
        }
    }

    public struct CodingKeys: CodingKey, Hashable, Equatable {
        public var stringValue: String
        
        public init(stringValue: String) {
            self.stringValue = stringValue
        }
        
        public var intValue: Int? {
            return nil
        }
        
        public init?(intValue: Int) {
            return nil
        }
        
        public static let category = CodingKeys(stringValue: "category")
        public static let categoryPathComponent = CodingKeys(stringValue: "categoryPathComponent")
        public static let estimatedTime = CodingKeys(stringValue: "estimatedTime")
        public static let modules = CodingKeys(stringValue: "modules")
        public static let extendedModule = CodingKeys(stringValue: "extendedModule")
        public static let platforms = CodingKeys(stringValue: "platforms")
        public static let required = CodingKeys(stringValue: "required")
        public static let roleHeading = CodingKeys(stringValue: "roleHeading")
        public static let role = CodingKeys(stringValue: "role")
        public static let title = CodingKeys(stringValue: "title")
        public static let externalID = CodingKeys(stringValue: "externalID")
        public static let symbolKind = CodingKeys(stringValue: "symbolKind")
        public static let symbolAccessLevel = CodingKeys(stringValue: "symbolAccessLevel")
        public static let conformance = CodingKeys(stringValue: "conformance")
        public static let fragments = CodingKeys(stringValue: "fragments")
        public static let navigatorTitle = CodingKeys(stringValue: "navigatorTitle")
        public static let sourceFileURI = CodingKeys(stringValue: "sourceFileURI")
        public static let tags = CodingKeys(stringValue: "tags")
        public static let version = CodingKeys(stringValue: "version")
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        category = try container.decodeIfPresent(String.self, forKey: .category)
        categoryPathComponent = try container.decodeIfPresent(String.self, forKey: .categoryPathComponent)

        platformsVariants = try container.decodeVariantCollectionIfPresent(ofValueType: [AvailabilityRenderItem]?.self, forKey: .platforms)
        modulesVariants = try container.decodeVariantCollectionIfPresent(ofValueType: [Module]?.self, forKey: .modules)
        extendedModuleVariants = try container.decodeVariantCollectionIfPresent(ofValueType: String?.self, forKey: .extendedModule)
        estimatedTime = try container.decodeIfPresent(String.self, forKey: .estimatedTime)
        requiredVariants = try container.decodeVariantCollectionIfPresent(ofValueType: Bool.self, forKey: .required) ?? .init(defaultValue: false)
        roleHeadingVariants = try container.decodeVariantCollectionIfPresent(ofValueType: String?.self, forKey: .roleHeading)
        let rawRole = try container.decodeIfPresent(String.self, forKey: .role)
        role = rawRole == "tutorial" ? Role.tutorial.rawValue : rawRole
        titleVariants = try container.decodeVariantCollectionIfPresent(ofValueType: String?.self, forKey: .title)
        externalID = try container.decodeIfPresent(String.self, forKey: .externalID)
        symbolKindVariants = try container.decodeVariantCollectionIfPresent(ofValueType: String?.self, forKey: .symbolKind)
        symbolAccessLevelVariants = try container.decodeVariantCollectionIfPresent(ofValueType: String?.self, forKey: .symbolAccessLevel)
        conformance = try container.decodeIfPresent(ConformanceSection.self, forKey: .conformance)
        fragmentsVariants = try container.decodeVariantCollectionIfPresent(ofValueType: [DeclarationRenderSection.Token]?.self, forKey: .fragments)
        navigatorTitleVariants = try container.decodeVariantCollectionIfPresent(ofValueType: [DeclarationRenderSection.Token]?.self, forKey: .navigatorTitle)
        sourceFileURIVariants = try container.decodeVariantCollectionIfPresent(ofValueType: String?.self, forKey: .sourceFileURI)
        tags = try container.decodeIfPresent([RenderNode.Tag].self, forKey: .tags)
        version = try container.decodeIfPresent(ArchiveVersion.self, forKey: .version)
        
        let extraKeys = Set(container.allKeys).subtracting(
            [
                .category,
                .categoryPathComponent,
                .estimatedTime,
                .modules,
                .extendedModule,
                .platforms,
                .required,
                .roleHeading,
                .role,
                .title,
                .externalID,
                .symbolKind,
                .symbolAccessLevel,
                .conformance,
                .fragments,
                .navigatorTitle,
                .sourceFileURI,
                .tags,
                .version
            ]
        )
        for extraKey in extraKeys {
            extraMetadata[extraKey] = try container.decode(AnyMetadata.self, forKey: extraKey).value
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(categoryPathComponent, forKey: .categoryPathComponent)
        
        try container.encodeVariantCollection(modulesVariants, forKey: .modules, encoder: encoder)
        try container.encodeVariantCollection(extendedModuleVariants, forKey: .extendedModule, encoder: encoder)
        try container.encodeIfPresent(estimatedTime, forKey: .estimatedTime)
        try container.encodeVariantCollection(platformsVariants, forKey: .platforms, encoder: encoder)
        try container.encodeVariantCollectionIfTrue(requiredVariants, forKey: .required, encoder: encoder)
        try container.encodeVariantCollection(roleHeadingVariants, forKey: .roleHeading, encoder: encoder)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeVariantCollection(titleVariants, forKey: .title, encoder: encoder)
        try container.encodeIfPresent(externalID, forKey: .externalID)
        try container.encodeIfPresent(symbolKindVariants.defaultValue, forKey: .symbolKind)
        try container.encodeVariantCollection(symbolKindVariants, forKey: .symbolKind, encoder: encoder)
        try container.encodeVariantCollection(symbolAccessLevelVariants, forKey: .symbolAccessLevel, encoder: encoder)
        try container.encodeIfPresent(conformance, forKey: .conformance)
        try container.encodeVariantCollection(fragmentsVariants, forKey: .fragments, encoder: encoder)
        try container.encodeVariantCollection(navigatorTitleVariants, forKey: .navigatorTitle, encoder: encoder)
        try container.encodeVariantCollection(sourceFileURIVariants, forKey: .sourceFileURI, encoder: encoder)
        try container.encodeIfPresent(version, forKey: .version)
        if let tags = self.tags, !tags.isEmpty {
            try container.encodeIfPresent(tags, forKey: .tags)
        }
        
        for (key, value) in extraMetadata {
            try container.encode(AnyMetadata(value), forKey: key)
        }
    }
    
    /// Returns the differences between this RenderMetadata and the given one.
    public func difference(from other: RenderMetadata, at path: Path) -> Differences {

        var diffs = Differences()

        // Diffing optional properties:
        diffs.append(contentsOf: optionalPropertyDifference(title, from: other.title, at: path + [CodingKeys.title]))
        diffs.append(contentsOf: optionalPropertyDifference(externalID, from: other.externalID, at: path + [CodingKeys.externalID]))
        diffs.append(contentsOf: optionalPropertyDifference(symbolKind, from: other.symbolKind, at: path + [CodingKeys.symbolKind]))
        diffs.append(contentsOf: optionalPropertyDifference(role, from: other.role, at: path + [CodingKeys.role]))
        diffs.append(contentsOf: optionalPropertyDifference(roleHeading, from: other.roleHeading, at: path + [CodingKeys.roleHeading]))
        diffs.append(contentsOf: optionalPropertyDifference(version, from: other.version, at: path + [CodingKeys.version]))

        // Diffing structs and arrays
        diffs.append(contentsOf: modules.difference(from: other.modules, at: path + [CodingKeys.modules]))
        diffs.append(contentsOf: fragments.difference(from: other.fragments, at: path + [CodingKeys.fragments]))
        diffs.append(contentsOf: navigatorTitle.difference(from: other.navigatorTitle, at: path + [CodingKeys.navigatorTitle]))

        return diffs
    }

}

extension RenderMetadata: Diffable {
    func isSimilar(to other: RenderMetadata) -> Bool {
        return self.title == other.title
    }
}
