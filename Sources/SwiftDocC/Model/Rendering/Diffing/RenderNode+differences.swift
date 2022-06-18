/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

protocol Diffable {
    func difference(from other: Self, at path: Path) -> Differences
    func similar(to other: Self) -> Bool
}

public typealias Differences = [JSONPatchOperation]
public typealias Path = [CodingKey]

extension Diffable where Self: Equatable {
    func similar(to other: Self) -> Bool {
        return self == other
    }
    
    func checkIfReplaced(comparingAgainst other: Self, at path: Path) -> [JSONPatchOperation]? where Self: Encodable {
        if self == other {
            return []
        } else if self.similar(to: other) {
            return nil
        } else {
            return [.replace(pointer: JSONPointer(from: path), encodableValue: self)]
        }
    }
}

extension Diffable {
    /// Returns the difference between two optional properties.
    func propertyDifference<T: Equatable & Encodable>(_ current: T, from other: T, at path: Path) -> Differences {
        if current != other {
            return [.replace(pointer: JSONPointer(from: path), encodableValue: current)]
        }
        return []
    }
    
    /// Unwraps and returns the difference between two optional properties.
    func optionalPropertyDifference<T>(_ current: T?, from other: T?, at path: Path) -> Differences where T: Equatable, T: Codable {
        var difference = Differences()
        if let current = current, let other = other {
            if current != other {
                difference.append(.replace(pointer: JSONPointer(from: path), encodableValue: current))
            }
        } else if other != nil {
            difference.append(.remove(pointer: JSONPointer(from: path)))
        } else if let current = current {
            difference.append(.add(pointer: JSONPointer(from: path), encodableValue: current))
        }
        return difference
    }
}

/// An integer coding key.
private struct CustomKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init(intValue: Int) {
        self.intValue = intValue
        self.stringValue = intValue.description
    }
    
    init(stringValue: String) {
        if let intValue = Int(stringValue) {
            self.intValue = intValue
        } else {
            self.intValue = stringValue.hashValue
        }
        self.stringValue = stringValue
    }
}

extension RenderNode: Diffable {
    func similar(to other: RenderNode) -> Bool {
        return identifier == other.identifier
    }
    
    /// Returns the differences between this render node and the given one.
    public func difference(from other: RenderNode, at path: Path) -> Differences {
        
        var diffs = Differences()
        
        diffs.append(contentsOf: propertyDifference(kind, from: other.kind, at: path + [CodingKeys.kind]))
        diffs.append(contentsOf: abstract.difference(from: other.abstract, at: path + [CodingKeys.abstract]))
        diffs.append(contentsOf: schemaVersion.difference(from:other.schemaVersion, at: path + [CodingKeys.schemaVersion]))
        diffs.append(contentsOf: identifier.difference(from:other.identifier, at: path + [CodingKeys.identifier]))
        diffs.append(contentsOf: metadata.difference(from:other.metadata, at: path + [CodingKeys.metadata]))
//        diffs.append(contentsOf: hierarchy.difference(from:other.hierarchy, at: path + [CodingKeys.hierarchy]))
        diffs.append(contentsOf: topicSections.difference(from: other.topicSections, at: path + [CodingKeys.topicSections]))
        diffs.append(contentsOf: seeAlsoSections.difference(from: other.seeAlsoSections, at: path + [CodingKeys.seeAlsoSections]))
        // Diffing render references
//        let diffableReferences = references.mapValues { reference in
//            return AnyRenderReference(reference)
//        }
//        let otherDiffableReferences = other.references.mapValues { reference in
//            return AnyRenderReference(reference)
//        }
//        diffs.append(contentsOf: diffableReferences.difference(from:otherDiffableReferences, at: path + [CodingKeys.references]))

        // Diffing primary content sections
        let equatablePrimaryContentSections = primaryContentSections.map { section in
            return AnyRenderSection(section)
        }
        let otherEquatablePrimaryContentSections = other.primaryContentSections.map { section in
            return AnyRenderSection(section)
        }
        diffs.append(contentsOf: equatablePrimaryContentSections.difference(from: otherEquatablePrimaryContentSections, at: path + [CodingKeys.primaryContentSections]))

        // Diffing relationship sections
        let equatableRelationshipSections = relationshipSections.map { section in
            return AnyRenderSection(section)
        }
        let otherEquatableRelationshipSections = other.relationshipSections.map { section in
            return AnyRenderSection(section)
        }
        diffs.append(contentsOf: equatableRelationshipSections.difference(from: otherEquatableRelationshipSections, at: path + [CodingKeys.relationshipsSections]))

        // Diffing sections
        let equatableSections = sections.map { section in
            return AnyRenderSection(section)
        }
        let otherEquatableSections = other.sections.map { section in
            return AnyRenderSection(section)
        }
        diffs.append(contentsOf: equatableSections.difference(from: otherEquatableSections, at: path + [CodingKeys.sections]))
        
        return diffs
    }
}

extension Dictionary: Diffable where Key == String, Value: Encodable & Equatable {
    /// Returns the difference between two dictionaries with diffable values.
    func difference(from other: Dictionary<Key, Value>, at path: Path) -> Differences where Value: Diffable {
        var differences = Differences()
        let uniqueKeysSet = Set(self.keys).union(Set(other.keys))
        for key in uniqueKeysSet {
            differences.append(contentsOf: self[key].difference(from: other[key], at: path + [CustomKey(stringValue: key)]))
        }
        return differences
    }
    
    /// Returns the difference between two dictionaries with diffable values.
    func difference(from other: Dictionary<Key, Value>, at path: Path) -> Differences {
        var differences = Differences()
        let uniqueKeysSet = Set(self.keys).union(Set(other.keys))
        for key in uniqueKeysSet {
            if self[key] != other[key] {
                differences.append(.replace(
                    pointer: JSONPointer(from: path + [CustomKey(stringValue: key)]),
                    encodableValue: self[key]))
            }
        }
        return differences
    }
}

extension Optional: Diffable where Wrapped: Diffable & Equatable {
    /// Returns the differences between this optional and the given one.
    func difference(from other: Optional<Wrapped>, at path: Path) -> Differences {
        var difference = Differences()
        if let current = self, let other = other {
            difference.append(contentsOf: current.difference(from: other, at: path))
        } else if other != nil {
            difference.append(JSONPatchOperation.remove(
                pointer: JSONPointer(from: path)))
        } else if let current = self {
            difference.append(JSONPatchOperation.add(
                pointer: JSONPointer(from: path), value: AnyCodable(current as! Encodable)))
        }
        return difference
    }
}

extension Array: Diffable where Element: Equatable & Encodable {
    /// Returns the differences between this array and the given one.
    func difference(from other: Array<Element>, at path: Path) -> Differences where Element: Diffable {
        let arrayDiffs = self.difference(from: other) { element1, element2 in
            return element1.similar(to: element2)
        }
        var differences = arrayDiffs.removals
        differences.append(contentsOf: arrayDiffs.insertions)
        var patchOperations = differences.map { diff -> JSONPatchOperation in
            switch diff {
            case .remove(let offset, _, _):
                let pointer = JSONPointer(from: path + [CustomKey(intValue: offset)])
                return .remove(pointer: pointer)
            case .insert(let offset, let element, _):
                let pointer = JSONPointer(from: path + [CustomKey(intValue: offset)])
                return .add(pointer: pointer, encodableValue: element)
            }
        }
        let similarOther = other.applying(arrayDiffs)! // Apply the changes so all elements are now similar.

        for (index, value) in enumerated() {
            if similarOther[index] != value {
                patchOperations.append(contentsOf: value.difference(from: similarOther[index], at: path + [CustomKey(intValue: index)]))
            }
        }
        
        return patchOperations
    }
    
    /// Returns the differences between this array and the given one assuming none of the elements are similar.
    func difference(from other: Array<Element>, at path: Path) -> Differences {
        let arrayDiffs = self.difference(from: other)
        var differences: [CollectionDifference.Change] = arrayDiffs.removals
        differences.append(contentsOf: arrayDiffs.insertions)
        let patchOperations = differences.map { diff -> JSONPatchOperation in
            switch diff {
            case .remove(let offset, _, _):
                let pointer = JSONPointer(from: path + [CustomKey(intValue: offset)])
                return .remove(pointer: pointer)
            case .insert(let offset, let element, _):
                let pointer = JSONPointer(from: path + [CustomKey(intValue: offset)])
                return .add(pointer: pointer, encodableValue: element)
            }
        }
        return patchOperations
    }
}

///// A RenderReference value that can be diffed.
/////
///// An `AnyRenderReference` value forwards difference operations to the underlying base type, which implement the difference differently.
//struct AnyRenderReference: Diffable {
//    var value: RenderReference
//    init(_ value: RenderReference) { self.value = value }
//    public func difference(from other: AnyRenderReference, at path: Path) -> Differences {
//        var differences = Differences()
//
//        if value.identifier != other.value.identifier {
//            differences["\(path)/identifier"] = "Replace with \(value.identifier)"
//        }
//
//        switch (value.type, other.value.type) {
//        case (.file, .file):
//            let value = value as! FileReference
//            let otherValue = other.value as! FileReference
//            differences.merge(value.difference(from: otherValue, at: path)) { (current, _) in current }
//        case (.image, .image):
//            let value = value as! ImageReference
//            let otherValue = other.value as! ImageReference
//            differences.merge(value.difference(from: otherValue, at: path)) { (current, _) in current }
//        case (.video, .video):
//            let value = value as! VideoReference
//            let otherValue = other.value as! VideoReference
//            differences.merge(value.difference(from: otherValue, at: path)) { (current, _) in current }
//        case (.fileType, .fileType):
//            let value = value as! FileTypeReference
//            let other = other.value as! FileTypeReference
//            differences.merge(value.difference(from: other, at: path)) { (current, _) in current }
//        case (.xcodeRequirement, .xcodeRequirement):
//            let value = value as! XcodeRequirementReference
//            let otherValue = other.value as! XcodeRequirementReference
//            differences.merge(value.difference(from: otherValue, at: path)) { (current, _) in current }
//        case (.topic, .topic):
//            let value = value as! TopicRenderReference
//            let otherValue = other.value as! TopicRenderReference
//            differences.merge(value.difference(from: otherValue, at: path)) { (current, _) in current }
//        case (.section, .section):
//            let value = value as! TopicRenderReference
//            let otherValue = other.value as! TopicRenderReference
//            differences.merge(value.difference(from: otherValue, at: path)) { (current, _) in current }
//        case (.download, .download):
//            let value = value as! DownloadReference
//            let otherValue = other.value as! DownloadReference
//            differences.merge(value.difference(from: otherValue, at: path)) { (current, _) in current }
//        case (.unresolvable, .unresolvable):
//            let value = value as! UnresolvedRenderReference
//            let otherValue = other.value as! UnresolvedRenderReference
//            differences.merge(value.difference(from: otherValue, at: path)) { (current, _) in current }
//        case (.link, .link):
//            let value = value as! LinkReference
//            let otherValue = other.value as! LinkReference
//            differences.merge(value.difference(from: otherValue, at: path)) { (current, _) in current }
//        default:
//            return [path: "Replace with \(value)"]
//        }
//        return differences
//    }
//}

//extension TopicRenderReference: Diffable {
//    /// Returns the difference between two TopicRenderReferences.
//    public func difference(from other: TopicRenderReference, at path: Path) -> Differences {
//        var differences = Differences()
//
//        if let roleDiff = optionalPropertyDifference(role, from: other.role) {
//            differences["\(path)/role"] = roleDiff
//        }
//        if title != other.title {
//            differences["\(path)/title"] = "Replace with \(title)"
//        }
//        if identifier != other.identifier {
//            differences["\(path)/identifier"] = "Replace with \(identifier)"
//        }
//        if kind != other.kind {
//            differences["\(path)/kind"] = "Replace with \(kind)"
//        }
//        if self.required != other.required {
//            differences["\(path)/required"] = "Replace with \(self.required)"
//        }
//        if type != other.type {
//            differences["\(path)/type"] = "Replace with \(type)"
//        }
//        if url != other.url {
//            differences["\(path)/url"] = "Replace with \(url)"
//        }
//        differences.merge(abstract.difference(from: other.abstract, at: "\(path)/abstract")) { (current, _) in current }
//        differences.merge(fragments.difference(from: other.fragments, at: "\(path)/fragments")) { (current, _) in current }
//
//        return differences
//    }
//}
//
//extension FileReference: Diffable {
//    /// Returns the difference between this FileReference and the given one.
//    public func difference(from other: FileReference, at path: Path) -> Differences {
//        var differences = Differences()
//        if fileName != other.fileName {
//            differences["\(path)/fileName"] = "Replace with \(fileName)"
//        }
//        if fileType != other.fileType {
//            differences["\(path)/fileType"] = "Replace with \(fileType)"
//        }
//        if syntax != other.syntax {
//            differences["\(path)/syntax"] = "Replace with \(syntax)"
//        }
//        differences.merge(content.difference(from: other.content, at: "\(path)/content")) { (current, _) in current }
//        differences.merge(highlights.difference(from: other.highlights, at: "\(path)/highlights")) { (current, _) in current }
//        return differences
//    }
//}
//
//extension ImageReference: Diffable {
//    /// Returns the difference between this ImageReference and the given one.
//    public func difference(from other: ImageReference, at path: Path) -> Differences {
//        var differences = Differences()
//
//        if let altTextDiff = optionalPropertyDifference(altText, from: other.altText) {
//            differences["\(path)/altText"] = altTextDiff
//        }
//        if asset != other.asset {
//            differences["\(path)/asset"] = "Replace with \(asset)"
//        }
//        return differences
//    }
//}
//
//extension VideoReference: Diffable {
//    /// Returns the difference between this VideoReference and the given one.
//    public func difference(from other: VideoReference, at path: Path) -> Differences {
//        var differences = Differences()
//
//        if let altTextDiff = optionalPropertyDifference(altText, from: other.altText) {
//            differences["\(path)/altText"] = altTextDiff
//        }
//        if asset != other.asset {
//            differences["\(path)/asset"] = "Replace with \(asset)"
//        }
//        differences.merge(poster.difference(from: other.poster, at: "\(path)/poster")) { (current, _) in current }
//        return differences
//    }
//}
//
//extension FileTypeReference: Diffable {
//    /// Returns the difference between this FileTypeReference and the given one.
//    public func difference(from other: FileTypeReference, at path: Path) -> Differences {
//        var differences = Differences()
//        if displayName != other.displayName {
//            differences["\(path)/displayName"] = "Replace with \(displayName)"
//        }
//        if iconBase64 != other.iconBase64 {
//            differences["\(path)/iconBase64"] = "Replace with \(iconBase64)"
//        }
//        return differences
//    }
//}
//
//extension XcodeRequirementReference: Diffable {
//    /// Returns the difference between this XcodeRequirementReference and the given one.
//    public func difference(from other: XcodeRequirementReference, at path: Path) -> Differences {
//        var differences = Differences()
//        if title != other.title {
//            differences["\(path)/title"] = "Replace with \(title)"
//        }
//        if url != other.url {
//            differences["\(path)/url"] = "Replace with \(url)"
//        }
//
//        return differences
//    }
//}
//
//extension DownloadReference: Diffable {
//    /// Returns the difference between this DownloadReference and the given one.
//    public func difference(from other: DownloadReference, at path: Path) -> Differences {
//        var differences = Differences()
//
//        if url != other.url {
//            differences["\(path)/url"] = "Replace with \(url)"
//        }
//        if sha512Checksum != other.sha512Checksum {
//            differences["\(path)/sha512Checksum"] = "Replace with \(sha512Checksum)"
//        }
//
//        return differences
//    }
//}
//
//extension UnresolvedRenderReference: Diffable {
//    /// Returns the difference between this UnresolvedRenderReference and the given one.
//    public func difference(from other: UnresolvedRenderReference, at path: Path) -> Differences {
//        var differences = Differences()
//        if title != other.title {
//            differences["\(path)/title"] = "Replace with \(title)"
//        }
//        return differences
//    }
//}
//
//extension LinkReference: Diffable {
//    /// Returns the difference between this LinkReference and the given one.
//    public func difference(from other: LinkReference, at path: Path) -> Differences {
//        var differences = Differences()
//
//        differences.merge(titleInlineContent.difference(from: other.titleInlineContent, at: "\(path)/titleInlineContent")) { (current, _) in current }
//        if url != other.url {
//            differences["\(path)/url"] = "Replace with \(url)"
//        }
//        if title != other.title {
//            differences["\(path)/title"] = "Replace with \(title)"
//        }
//
//        return differences
//    }
//}
//
// MARK: Equatable Conformance

public struct AnyRenderSection: Equatable, Encodable {
    public static func == (lhs: AnyRenderSection, rhs: AnyRenderSection) -> Bool {
        switch (lhs.value.kind, rhs.value.kind) {
        case (.intro, .intro), (.hero, .hero):
            return (lhs.value as! IntroRenderSection) == (rhs.value as! IntroRenderSection)
        case (.tasks, .tasks):
            return (lhs.value as! TutorialSectionsRenderSection) == (rhs.value as! TutorialSectionsRenderSection)
        case (.assessments, .assessments):
            return (lhs.value as! TutorialAssessmentsRenderSection) == (rhs.value as! TutorialAssessmentsRenderSection)
        case (.volume, .volume):
            return (lhs.value as! VolumeRenderSection) == (rhs.value as! VolumeRenderSection)
        case (.contentAndMedia, .contentAndMedia):
            return (lhs.value as! ContentAndMediaSection) == (rhs.value as! ContentAndMediaSection)
        case (.contentAndMediaGroup, .contentAndMediaGroup):
            return (lhs.value as! ContentAndMediaGroupSection) == (rhs.value as! ContentAndMediaGroupSection)
        case (.callToAction, .callToAction):
            return (lhs.value as! CallToActionSection) == (rhs.value as! CallToActionSection)
        case (.articleBody, .articleBody):
            return (lhs.value as! TutorialArticleSection) == (rhs.value as! TutorialArticleSection)
        case (.resources, .resources):
            return (lhs.value as! ResourcesRenderSection) == (rhs.value as! ResourcesRenderSection)
        case (.declarations, .declarations):
            return (lhs.value as! DeclarationsRenderSection) == (rhs.value as! DeclarationsRenderSection)
        case (.discussion, .discussion):
            return (lhs.value as! ContentRenderSection) == (rhs.value as! ContentRenderSection)
        case (.content, .content):
            return (lhs.value as! ContentRenderSection) == (rhs.value as! ContentRenderSection)
        case (.taskGroup, .taskGroup):
            return (lhs.value as! TaskGroupRenderSection) == (rhs.value as! TaskGroupRenderSection)
        case (.relationships, .relationships):
            return (lhs.value as! RelationshipsRenderSection) == (rhs.value as! RelationshipsRenderSection)
        case (.parameters, .parameters):
            return (lhs.value as! ParametersRenderSection) == (rhs.value as! ParametersRenderSection)
        case (.sampleDownload, .sampleDownload):
            return (lhs.value as! SampleDownloadSection) == (rhs.value as! SampleDownloadSection)
        default:
            print("RENDER SECTION USED THAT IS NOT EQUATABLE \(type(of: lhs.value))")
            return false
        }
    }

    public func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }

    public var value: RenderSection
    init(_ value: RenderSection) { self.value = value }
}


