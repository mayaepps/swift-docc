/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// A type that encapsulates resolving links by searching a hierarchy of path components.
final class PathHierarchyBasedLinkResolver {
    /// A hierarchy of path components used to resolve links in the documentation.
    private(set) var pathHierarchy: PathHierarchy
    
    /// Map between resolved identifiers and resolved topic references.
    private(set) var resolvedReferenceMap = BidirectionalMap<ResolvedIdentifier, ResolvedTopicReference>()
    
    /// Initializes a link resolver with a given path hierarchy.
    init(pathHierarchy: PathHierarchy) {
        self.pathHierarchy = pathHierarchy
    }
    
    /// Remove all matches from a given documentation bundle from the link resolver.
    func unregisterBundle(identifier: BundleIdentifier) {
        var newMap = BidirectionalMap<ResolvedIdentifier, ResolvedTopicReference>()
        for (id, reference) in resolvedReferenceMap {
            if reference.bundleIdentifier == identifier {
                pathHierarchy.removeNodeWithID(id)
            } else {
                newMap[id] = reference
            }
        }
        resolvedReferenceMap = newMap
    }
    
    /// Creates a path string—that can be used to find documentation in the path hierarchy—from an unresolved topic reference,
    private static func path(for unresolved: UnresolvedTopicReference) -> String {
        guard let fragment = unresolved.fragment else {
            return unresolved.path
        }
        return "\(unresolved.path)#\(urlReadableFragment(fragment))"
    }
    
    /// Traverse all the pairs of symbols and their parents.
    func traverseSymbolAndParentPairs(_ observe: (_ symbol: ResolvedTopicReference, _ parent: ResolvedTopicReference) -> Void) {
        for (id, node) in pathHierarchy.lookup {
            guard node.symbol != nil else { continue }
            
            guard let parentID = node.parent?.identifier else { continue }
            
            // Only symbols in the symbol index are added to the reference map.
            guard let reference = resolvedReferenceMap[id], let parentReference = resolvedReferenceMap[parentID] else { continue }
            observe(reference, parentReference)
        }
    }
    
    /// Traverse all symbols of the same kind that have collisions.
    func traverseOverloadedSymbols(_ observe: (_ overloadedSymbols: [ResolvedTopicReference]) -> Void) {
        let overloadableKinds = ["method", "type.method", "func", "init", "macro", "subscript", "func.op"]
        
        for (_, node) in pathHierarchy.lookup {
            guard node.symbol != nil else { continue }
            
            // TODO: Once we know what data and what structure we need we should probably create a PathHierarchy API that hides those implementation details.
            for (_ /*name*/, disambiguation) in node.children {
                for ( kind, innerStorage) in disambiguation.storage where innerStorage.count > 1 && overloadableKinds.contains(kind) {
                    let childrenWithSameKind = innerStorage.values.compactMap {
                        // Filter out any non-symbols and pages that don't have a known reference
                        $0.symbol == nil ? nil : resolvedReferenceMap[$0.identifier]
                    }
                    observe(childrenWithSameKind)
                }
            }
        }
    }
    
    /// Returns a list of all the top level symbols.
    func topLevelSymbols() -> [ResolvedTopicReference] {
        return pathHierarchy.topLevelSymbols().map { resolvedReferenceMap[$0]! }
    }
    
    /// Returns a list of all module symbols.
    func modules() -> [ResolvedTopicReference] {
        return pathHierarchy.modules.map { resolvedReferenceMap[$0.identifier]! }
    }
    
    // MARK: - Adding non-symbols
    
    /// Map the resolved identifiers to resolved topic references for a given bundle's article, tutorial, and technology root pages.
    func addMappingForRoots(bundle: DocumentationBundle) {
        resolvedReferenceMap[pathHierarchy.tutorialContainer.identifier] = bundle.technologyTutorialsRootReference
        resolvedReferenceMap[pathHierarchy.articlesContainer.identifier] = bundle.articlesDocumentationRootReference
        resolvedReferenceMap[pathHierarchy.tutorialOverviewContainer.identifier] = bundle.tutorialsRootReference
    }
    
    /// Map the resolved identifiers to resolved topic references for all symbols in the given symbol index.
    func addMappingForSymbols(symbolIndex: [String: ResolvedTopicReference]) {
        for (id, node) in pathHierarchy.lookup {
            guard let symbol = node.symbol, let reference = symbolIndex[symbol.identifier.precise] else {
                continue
            }
            resolvedReferenceMap[id] = reference
        }
    }
    
    /// Adds a tutorial and its landmarks to the path hierarchy.
    func addTutorial(_ tutorial: DocumentationContext.SemanticResult<Tutorial>) {
        addTutorial(
            reference: tutorial.topicGraphNode.reference,
            source: tutorial.source,
            landmarks: tutorial.value.landmarks
        )
    }
    
    /// Adds a tutorial article and its landmarks to the path hierarchy.
    func addTutorialArticle(_ tutorial: DocumentationContext.SemanticResult<TutorialArticle>) {
        addTutorial(
            reference: tutorial.topicGraphNode.reference,
            source: tutorial.source,
            landmarks: tutorial.value.landmarks
        )
    }
    
    private func addTutorial(reference: ResolvedTopicReference, source: URL, landmarks: [Landmark]) {
        let tutorialID = pathHierarchy.addTutorial(name: linkName(filename: source.deletingPathExtension().lastPathComponent))
        resolvedReferenceMap[tutorialID] = reference
        
        for landmark in landmarks {
            let landmarkID = pathHierarchy.addNonSymbolChild(parent: tutorialID, name: urlReadableFragment(landmark.title), kind: "landmark")
            resolvedReferenceMap[landmarkID] = reference.withFragment(landmark.title)
        }
    }
    
    /// Adds a technology and its volumes and chapters to the path hierarchy.
    func addTechnology(_ technology: DocumentationContext.SemanticResult<Technology>) {
        let reference = technology.topicGraphNode.reference

        let technologyID = pathHierarchy.addTutorialOverview(name: linkName(filename: technology.source.deletingPathExtension().lastPathComponent))
        resolvedReferenceMap[technologyID] = reference
        
        var anonymousVolumeID: ResolvedIdentifier?
        for volume in technology.value.volumes {
            if anonymousVolumeID == nil, volume.name == nil {
                anonymousVolumeID = pathHierarchy.addNonSymbolChild(parent: technologyID, name: "$volume", kind: "volume")
                resolvedReferenceMap[anonymousVolumeID!] = reference.appendingPath("$volume")
            }
            
            let chapterParentID: ResolvedIdentifier
            let chapterParentReference: ResolvedTopicReference
            if let name = volume.name {
                chapterParentID = pathHierarchy.addNonSymbolChild(parent: technologyID, name: name, kind: "volume")
                chapterParentReference = reference.appendingPath(name)
                resolvedReferenceMap[chapterParentID] = chapterParentReference
            } else {
                chapterParentID = technologyID
                chapterParentReference = reference
            }
            
            for chapter in volume.chapters {
                let chapterID = pathHierarchy.addNonSymbolChild(parent: technologyID, name: chapter.name, kind: "volume")
                resolvedReferenceMap[chapterID] = chapterParentReference.appendingPath(chapter.name)
            }
        }
    }
    
    /// Adds a technology root article and its headings to the path hierarchy.
    func addRootArticle(_ article: DocumentationContext.SemanticResult<Article>, anchorSections: [AnchorSection]) {
        let linkName = linkName(filename: article.source.deletingPathExtension().lastPathComponent)
        let articleID = pathHierarchy.addTechnologyRoot(name: linkName)
        resolvedReferenceMap[articleID] = article.topicGraphNode.reference
        addAnchors(anchorSections, to: articleID)
    }
    
    /// Adds an article and its headings to the path hierarchy.
    func addArticle(_ article: DocumentationContext.SemanticResult<Article>, anchorSections: [AnchorSection]) {
        addArticle(filename: article.source.deletingPathExtension().lastPathComponent, reference: article.topicGraphNode.reference, anchorSections: anchorSections)
    }
    
    /// Adds an article and its headings to the path hierarchy.
    func addArticle(filename: String, reference: ResolvedTopicReference, anchorSections: [AnchorSection]) {
        let articleID = pathHierarchy.addArticle(name: linkName(filename: filename))
        resolvedReferenceMap[articleID] = reference
        addAnchors(anchorSections, to: articleID)
    }
    
    /// Adds the headings for all symbols in the symbol index to the path hierarchy.
    func addAnchorForSymbols(symbolIndex: [String: ResolvedTopicReference], documentationCache: [ResolvedTopicReference: DocumentationNode]) {
        for (id, node) in pathHierarchy.lookup {
            guard let symbol = node.symbol, let reference = symbolIndex[symbol.identifier.precise], let node = documentationCache[reference] else { continue }
            addAnchors(node.anchorSections, to: id)
        }
    }
    
    private func addAnchors(_ anchorSections: [AnchorSection], to parent: ResolvedIdentifier) {
        for anchor in anchorSections {
            let identifier = pathHierarchy.addNonSymbolChild(parent: parent, name: anchor.reference.fragment!, kind: "anchor")
            resolvedReferenceMap[identifier] = anchor.reference
        }
    }
    
    /// Adds a task group on a given page to the documentation hierarchy.
    func addTaskGroup(named name: String, reference: ResolvedTopicReference, to parent: ResolvedTopicReference) {
        let parentID = resolvedReferenceMap[parent]!
        let taskGroupID = pathHierarchy.addNonSymbolChild(parent: parentID, name: urlReadableFragment(name), kind: "taskGroup")
        resolvedReferenceMap[taskGroupID] = reference
    }
    
    // MARK: Reference resolving
    
    /// Attempts to resolve an unresolved reference.
    ///
    /// - Parameters:
    ///   - unresolvedReference: The unresolved reference to resolve.
    ///   - parent: The parent reference to resolve the unresolved reference relative to.
    ///   - isCurrentlyResolvingSymbolLink: Whether or not the documentation link is a symbol link.
    ///   - context: The documentation context to resolve the link in.
    /// - Returns: The result of resolving the reference.
    func resolve(_ unresolvedReference: UnresolvedTopicReference, in parent: ResolvedTopicReference, fromSymbolLink isCurrentlyResolvingSymbolLink: Bool, context: DocumentationContext) throws -> TopicReferenceResolutionResult {
        let parentID = resolvedReferenceMap[parent]
        let found = try pathHierarchy.find(path: Self.path(for: unresolvedReference), parent: parentID, onlyFindSymbols: isCurrentlyResolvingSymbolLink)
        guard let foundReference = resolvedReferenceMap[found] else {
            // It's possible for the path hierarchy to find a symbol that the local build doesn't create a page for. Such symbols can't be linked to.
            let simplifiedFoundPath = sequence(first: pathHierarchy.lookup[found]!, next: \.parent)
                .map(\.name).reversed().joined(separator: "/")
            return .failure(unresolvedReference, .init("\(simplifiedFoundPath.singleQuoted) has no page and isn't available for linking."))
        }
        
        return .success(foundReference)
    }
    
    func fullName(of node: PathHierarchy.Node, in context: DocumentationContext) -> String {
        guard let identifier = node.identifier else { return node.name }
        if let symbol = node.symbol {
            if let fragments = symbol.declarationFragments {
                return fragments.map(\.spelling).joined().split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
            }
            return symbol.names.title
        }
        let reference = resolvedReferenceMap[identifier]!
        if reference.fragment != nil {
            return context.nodeAnchorSections[reference]!.title
        } else {
            return context.documentationCache[reference]!.name.description
        }
    }
    
    // MARK: Symbol reference creation
    
    /// Returns a map between symbol identifiers and topic references.
    ///
    /// - Parameters:
    ///   - symbolGraph: The complete symbol graph to walk through.
    ///   - bundle: The bundle to use when creating symbol references.
    func referencesForSymbols(in unifiedGraphs: [String: UnifiedSymbolGraph], bundle: DocumentationBundle, context: DocumentationContext) -> [SymbolGraph.Symbol.Identifier: ResolvedTopicReference] {
        let disambiguatedPaths = pathHierarchy.caseInsensitiveDisambiguatedPaths(includeDisambiguationForUnambiguousChildren: true, includeLanguage: true)
        
        var result: [SymbolGraph.Symbol.Identifier: ResolvedTopicReference] = [:]
        
        for (moduleName, symbolGraph) in unifiedGraphs {
            let paths: [ResolvedTopicReference?] = Array(symbolGraph.symbols.values).concurrentMap { unifiedSymbol -> ResolvedTopicReference? in
                let symbol = unifiedSymbol
                let uniqueIdentifier = unifiedSymbol.uniqueIdentifier
                
                if let pathComponents = context.knownDisambiguatedSymbolPathComponents?[uniqueIdentifier],
                   let componentsCount = symbol.defaultSymbol?.pathComponents.count,
                   pathComponents.count == componentsCount
                {
                    let symbolReference = SymbolReference(pathComponents: pathComponents, interfaceLanguages: symbol.sourceLanguages)
                    return ResolvedTopicReference(symbolReference: symbolReference, moduleName: moduleName, bundle: bundle)
                }
                
                guard let path = disambiguatedPaths[uniqueIdentifier] else {
                    return nil
                }
                
                return ResolvedTopicReference(
                    bundleIdentifier: bundle.documentationRootReference.bundleIdentifier,
                    path: NodeURLGenerator.Path.documentationFolder + path,
                    sourceLanguages: symbol.sourceLanguages
                )
            }
            for (symbol, reference) in zip(symbolGraph.symbols.values, paths) {
                guard let reference = reference else { continue }
                result[symbol.defaultIdentifier] = reference
            }
        }
        return result
    }
    
    // MARK: Links
    
    /// Determines the disambiguated relative links of all the direct descendants of the given page.
    ///
    /// - Parameters:
    ///   - reference: The identifier of the page whose descendants to generate relative links for.
    /// - Returns: A map topic references to pairs of links and flags indicating if the link is disambiguated or not.
    func disambiguatedRelativeLinksForDescendants(of reference: ResolvedTopicReference) -> [ResolvedTopicReference: (link: String, hasDisambiguation: Bool)] {
        guard let nodeID = resolvedReferenceMap[reference] else { return [:] }
        
        let links = pathHierarchy.disambiguatedChildLinks(of: nodeID)
        var result = [ResolvedTopicReference: (link: String, hasDisambiguation: Bool)]()
        result.reserveCapacity(links.count)
        for (id, link) in links {
            guard let reference = resolvedReferenceMap[id] else { continue }
            result[reference] = link
        }
        return result
    }
}

/// Creates a more writable version of an articles file name for use in documentation links.
///
/// Compared to `urlReadablePath(_:)` this preserves letters in other written languages.
private func linkName<S: StringProtocol>(filename: S) -> String {
    // It would be a nice enhancement to also remove punctuation from the filename to allow an article in a file named "One, two, & three!"
    // to be referenced with a link as `"One-two-three"` instead of `"One,-two-&-three!"` (rdar://120722917)
    return filename
        // Replace continuous whitespace and dashes
        .components(separatedBy: whitespaceAndDashes)
        .filter({ !$0.isEmpty })
        .joined(separator: "-")
}

private let whitespaceAndDashes = CharacterSet.whitespaces
    .union(CharacterSet(charactersIn: "-–—")) // hyphen, en dash, em dash
