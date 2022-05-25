/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

protocol Diffable {
    func difference(from other: Self, at path: String) -> [String: Any]
}

extension RenderNode: Diffable {
    
    /// Returns the differences between this render node and the given one.
    public func difference(from other: RenderNode, at path: String) -> [String: Any] {
        
        var diffs: [String: Any] = [:]
        
        if kind != other.kind {
            diffs["\(path)/kind"] = "Replace with \(kind)"
        }
        
        diffs.merge(abstract.difference(from: other.abstract, at: "\(path)/abstract")) { (current, _) in current }
        diffs.merge(schemaVersion.difference(from:other.schemaVersion, at: "\(path)/schemaVersion")) { (current, _) in current }
        diffs.merge(identifier.difference(from:other.identifier, at: "\(path)/identifier")) { (current, _) in current }
        diffs.merge(metadata.difference(from:other.metadata, at: "\(path)/metadata")) { (current, _) in current }
        diffs.merge(hierarchy.difference(from:other.hierarchy, at: "\(path)/hierarchy")) { (current, _) in current }
        diffs.merge(topicSections.difference(from: other.topicSections, at: "\(path)/TopicSections")) { (current, _) in current }
        diffs.merge(seeAlsoSections.difference(from: other.seeAlsoSections, at: "\(path)/SeeAlsoSections")) { (current, _) in current }
        
        // TODO: Error that RenderReference cannot conform to Diffable
//        diffs.merge(references.difference(from:other.references, at: "\(path)/references")) { (current, _) in current }
        
        // TODO: Fix error that Protocol xyz as a type cannot conform to 'Equatable':
//        diffs.merge(primaryContentSections.difference(from: other.primaryContentSections, at: "RenderNode/PrimaryContentSection")) { (current, _) in current }
//        diffs.merge(relationshipSections.difference(from: other.relationshipSections, at: "RenderNode/RelationshipSections")) { (current, _) in current }
        
        // TODO: variants
        // TODO: sections
        
        return diffs
    }
}

extension Optional: Diffable where Wrapped: Diffable {
    func difference(from other: Optional<Wrapped>, at path: String) -> [String : Any] {
        
        var difference: [String : Any] = [:]
        if let current = self, let other = other {
            difference.merge(current.difference(from: other, at: path)) { (current, _) in current }
        } else if let other = other {
            difference = [path: "Remove \(other)"]
        } else if let current = self {
            difference = [path: "Add \(current)"]
        }
        return difference
    }
}

extension Array: Diffable where Element: Equatable {
    
    func difference(from other: Array<Element>, at path: String) -> [String : Any] {
        // TODO: Deal with arrays of big structs--drill into their specific differences
        return [path: self.difference(from: other)]
    }
}

extension ResolvedTopicReference: Diffable {
    
    /// Returns the differences between this resolved topic reference and the given one.
    public func difference(from other: ResolvedTopicReference, at path: String) -> [String: Any] {
        var diffs: [String: Any] = [:]
        if url != other.url {
            diffs["\(path)/url"] = "Replace with \(url)"
        }
        if sourceLanguage != other.sourceLanguage {
            diffs["\(path)/sourceLanguage"] = "Replace with \(sourceLanguage)"
        }
        return diffs
    }
}

extension RenderMetadata: Diffable {
    
    /// Returns the differences between this render metadata and the given one.
    public func difference(from other: RenderMetadata, at path: String) -> [String: Any] {
        var diffs: [String : Any] = [:]
        
        // Diffing optional properties:
        if let titleDiff = optionalPropertyDifference(title, from: other.title) {
            diffs["\(path)/title"] = titleDiff
        }
        if let idDiff = optionalPropertyDifference(externalID, from: other.externalID) {
            diffs["\(path)/externalID"] = idDiff
        }
        if let currentSymbolKind = optionalPropertyDifference(symbolKind, from: other.symbolKind) {
            diffs["\(path)/symbolKind"] = currentSymbolKind
        }
        if let currentRole = optionalPropertyDifference(role, from: other.role) {
            diffs["\(path)/role"] = currentRole
        }
        if let currentRoleHeading = optionalPropertyDifference(roleHeading, from: other.roleHeading) {
            diffs["\(path)/roleHeading"] = currentRoleHeading
        }
        
        // Diffing structs and arrays
        diffs.merge(modules.difference(from: other.modules, at: "\(path)/modules")) { (current, _) in current }
        diffs.merge(fragments.difference(from: other.fragments, at: "\(path)/fragments")) { (current, _) in current }
        diffs.merge(navigatorTitle.difference(from: other.navigatorTitle, at: "\(path)/navigatorTitle")) { (current, _) in current }

        return diffs
    }
}

extension RenderMetadata.Module: Diffable, Equatable {
    public static func == (lhs: RenderMetadata.Module, rhs: RenderMetadata.Module) -> Bool {
        return lhs.name == rhs.name && lhs.relatedModules == rhs.relatedModules
    }
    
    func difference(from other: RenderMetadata.Module, at path: String) -> [String : Any] {
        var differences = [String: Any]()
        if name != other.name {
            differences["\(path)/name"] = "Replace with \(name)"
        }
        differences.merge(relatedModules.difference(from: other.relatedModules, at: "\(path)/relatedModules")) { (current, _) in current }
        
        return differences
    }
}

extension SemanticVersion: Diffable {
    /// Returns the differences between this semantic version and the given one.
    public func difference(from other: SemanticVersion, at path: String) -> [String: Any] {
        var diff = [String: Any]()
        
        if major != other.major {
            diff["\(path)/major"] = "Replace with \(major)"
        }
        if minor != other.minor {
            diff["\(path)/minor"] = "Replace with \(minor)"
        }
        if patch != other.patch  {
            diff["\(path)/patch"] = "Replace with \(patch)"
        }
        return diff
    }
}

extension Dictionary: Diffable where Value: Diffable {
    func difference(from other: Dictionary<Key, Value>, at path: String) -> [String : Any] {
        var differences: [String: Any] = [:]
        for (key, value) in self {
            differences.merge(value.difference(from: other[key]!, at: "\(path)/\(key)")) { (current, _) in current }
        }
        return differences
    }
}

extension TopicRenderReference: Diffable {
    
    /// Returns the difference between two TopicRenderReferences.
    public func difference(from other: TopicRenderReference, at path: String) -> [String: Any] {
        var differences: [String: Any] = [:]
        
        if let roleDiff = optionalPropertyDifference(role, from: other.role) {
            differences["\(path)/role"] = roleDiff
        }
        if title != other.title {
            differences["\(path)/title"] = "Replace with \(title)"
        }
        if identifier != other.identifier {
            differences["\(path)/identifier"] = "Replace with \(identifier)"
        }
        if kind != other.kind {
            differences["\(path)/kind"] = "Replace with \(kind)"
        }
        if self.required != other.required {
            differences["\(path)/required"] = "Replace with \(self.required)"
        }
        if type != other.type {
            differences["\(path)/type"] = "Replace with \(type)"
        }
        if url != other.url {
            differences["\(path)/url"] = "Replace with \(url)"
        }
        differences.merge(abstract.difference(from: other.abstract, at: "\(path)/abstract")) { (current, _) in current }
        differences.merge(fragments.difference(from: other.fragments, at: "\(path)/fragments")) { (current, _) in current }
        
        // TODO: Title variants (Should this be handled differently?)
        
        return differences
    }
}

extension RenderHierarchy: Diffable {
    
    func difference(from other: RenderHierarchy, at path: String) -> [String : Any] {
        var differences = [String: Any]()
        switch (self, other) {
            case (let .reference(selfReferenceHierarchy), let .reference(otherReferenceHierarchy)):
                differences.merge(selfReferenceHierarchy.difference(from: otherReferenceHierarchy, at: path)) { (current, _) in current }
            case (let .tutorials(selfTutorialsHierarchy), let .tutorials(otherTutorialsHierarchy)):
                differences.merge(selfTutorialsHierarchy.difference(from: otherTutorialsHierarchy, at: path)) { (current, _) in current }
            default:
            differences[path] = "Replace with \(self)"
        }
        return differences
    }
}

extension RenderReferenceHierarchy: Diffable {
    func difference(from other: RenderReferenceHierarchy, at path: String) -> [String : Any] {
        return paths.difference(from: other.paths, at: "\(path)/paths")
    }
    
}
extension RenderTutorialsHierarchy: Diffable {
    func difference(from other: RenderTutorialsHierarchy, at path: String) -> [String : Any] {
        var differences = [String: Any]()
        differences.merge(paths.difference(from: other.paths, at: "\(path)/paths")) { (current, _) in current }
        
        //TODO: reference, modules ?
        
        return differences
    }
}

// MARK: Equatable Conformance

extension TaskGroupRenderSection: Equatable {
    public static func == (lhs: TaskGroupRenderSection, rhs: TaskGroupRenderSection) -> Bool {
        return lhs.kind == rhs.kind && lhs.title == rhs.title && lhs.abstract == rhs.abstract && lhs.discussion?.kind == rhs.discussion?.kind && lhs.identifiers == rhs.identifiers && lhs.generated == rhs.generated
    }
}


// MARK: Diff Helpers

/// Unwraps and returns the difference between two optional properties.
private func optionalPropertyDifference<T>(_ current: T?, from other: T?) -> String? where T: Equatable {
    var difference: String? = nil
    if let current = current, let other = other {
        if current != other {
            difference = "Replace with \(current)"
        }
    } else if let other = other {
        difference = "Remove \(other)"
    } else if let current = current {
        difference = "Add \(current)"
    }
    return difference
}
