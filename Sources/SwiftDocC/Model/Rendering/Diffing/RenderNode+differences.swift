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
    func isSimilar(to other: Self) -> Bool
}

public typealias Differences = [JSONPatchOperation]
public typealias Path = [CodingKey]

struct DifferenceBuilder<T> {
    
    var differences: Differences
    let current: T
    let other: T
    let path: Path
    
    init(current: T, other: T, basePath: Path) {
        self.differences = []
        self.current = current
        self.other = other
        self.path = basePath
    }
    
    /// Determines the difference between the two diffable objects at the KeyPaths given.
    mutating func addDifferences<D>(atKeyPath keyPath: KeyPath<T, D>, forKey codingKey: CodingKey) where D: Diffable & Equatable & Codable {
        let currentProperty = current[keyPath: keyPath]
        let otherProperty = other[keyPath: keyPath]
        
        if currentProperty == otherProperty {
            return
        }
        
        if currentProperty.isSimilar(to: otherProperty) {
            let diffs = currentProperty.difference(from: otherProperty, at: path + [codingKey])
            differences.append(contentsOf: diffs)
        } else {
            differences.append(.replace(pointer: JSONPointer(from: path + [codingKey]), encodableValue: currentProperty))
        }
    }
    
    /// Determines the difference between the two diffable objects at the KeyPaths given.
    mutating func addDifferences<Element>(atKeyPath keyPath: KeyPath<T, Array<Element>>, forKey codingKey: CodingKey) where Element: Diffable & Equatable & Codable {
        let currentProperty = current[keyPath: keyPath]
        let otherProperty = other[keyPath: keyPath]
        
        if currentProperty == otherProperty {
            return
        }
        
        if currentProperty.isSimilar(to: otherProperty) {
            let diffs = currentProperty.difference(from: otherProperty, at: path + [codingKey])
            differences.append(contentsOf: diffs)
        } else {
            differences.append(.replace(pointer: JSONPointer(from: path + [codingKey]), encodableValue: currentProperty))
        }
    }

    
    /// Adds the difference between two optional properties to the DifferenceBuilder.
    mutating func addPropertyDifference<E>(atKeyPath keyPath: KeyPath<T, E>, forKey codingKey: CodingKey) where E: Equatable & Codable {
        let currentProperty = current[keyPath: keyPath]
        let otherProperty = other[keyPath: keyPath]
        
        if currentProperty != otherProperty {
            differences.append(.replace(pointer: JSONPointer(from: path + [codingKey]), encodableValue: currentProperty))
        }
    }
    
    /// Unwraps and adds the difference between two optional properties.
    mutating func addOptionalPropertyDifference<O>(atKeyPath keyPath: KeyPath<T, O?>, forKey key: CodingKey) where O: Equatable & Codable {
        var difference = Differences()
        
        let currentProperty = current[keyPath: keyPath]
        let otherProperty = other[keyPath: keyPath]
        
        if let currentProperty = currentProperty, let otherProperty = otherProperty {
            if currentProperty != otherProperty {
                difference.append(.replace(pointer: JSONPointer(from: path + [key]), encodableValue: currentProperty))
            }
        } else if otherProperty != nil {
            difference.append(.remove(pointer: JSONPointer(from: path + [key])))
        } else if let currentProp = currentProperty {
            difference.append(.add(pointer: JSONPointer(from: path + [key]), encodableValue: currentProp))
        }
    }
    
    /// Determines the difference between the two diffable Arrays of RenderSections at the KeyPaths given.
    mutating func addDifferences(atKeyPath keyPath: KeyPath<T, Array<RenderSection>>, forKey codingKey: CodingKey) {
        let currentArray = current[keyPath: keyPath]
        let otherArray = other[keyPath: keyPath]
        
        let typeErasedCurrentArray = currentArray.map { section in
            return AnyRenderSection(section)
        }
        let typeErasedOtherArray = otherArray.map { section in
            return AnyRenderSection(section)
        }
        
        if typeErasedCurrentArray == typeErasedOtherArray {
            return
        }

        if typeErasedCurrentArray.isSimilar(to: typeErasedOtherArray) {
            let diffs = typeErasedCurrentArray.difference(from: typeErasedOtherArray, at: path + [codingKey])
            differences.append(contentsOf: diffs)
        } else {
            differences.append(.replace(pointer: JSONPointer(from: path + [codingKey]), encodableValue: typeErasedCurrentArray))
        }
    }
}

// To be deleted when I switch over to DifferenceBuilder
extension Diffable {
    func optionalPropertyDifference<T>(_ current: T?, from other: T?, at path: Path) -> Differences where T: Equatable & Codable {
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
    func propertyDifference<T>(_ current: T, from other: T, at path: Path) -> Differences where T: Equatable & Codable {
        var differences = Differences()
        if current != other {
            differences.append(.replace(pointer: JSONPointer(from: path), encodableValue: current))
        }
        return differences
    }
}


extension Diffable where Self: Equatable {
    func isSimilar(to other: Self) -> Bool {
        return self == other
    }
    
    func checkIfReplaced(comparingAgainst other: Self, at path: Path) -> [JSONPatchOperation]? where Self: Encodable {
        if self == other {
            return []
        } else if self.isSimilar(to: other) {
            return nil
        } else {
            return [.replace(pointer: JSONPointer(from: path), encodableValue: self)]
        }
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
    func isSimilar(to other: RenderNode) -> Bool {
        return identifier == other.identifier
    }
    
    /// Returns the differences between this render node and the given one.
    public func difference(from other: RenderNode, at path: Path) -> Differences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)
        
        diffBuilder.addPropertyDifference(atKeyPath: \.kind, forKey: CodingKeys.kind)
        diffBuilder.addDifferences(atKeyPath: \.abstract, forKey: CodingKeys.abstract)
        diffBuilder.addDifferences(atKeyPath: \.schemaVersion, forKey: CodingKeys.schemaVersion)
        diffBuilder.addDifferences(atKeyPath: \.identifier, forKey: CodingKeys.identifier)
        diffBuilder.differences.append(contentsOf: metadata.difference(from: other.metadata, at: path + [CodingKeys.metadata])) // RenderMetadata isn't Equatable
        diffBuilder.addDifferences(atKeyPath: \.hierarchy, forKey: CodingKeys.hierarchy)
        diffBuilder.addDifferences(atKeyPath: \.topicSections, forKey: CodingKeys.topicSections)
        diffBuilder.addDifferences(atKeyPath: \.seeAlsoSections, forKey: CodingKeys.seeAlsoSections)
        
        // Diffing render references
        // TODO: This should be dealt with in the DifferenceBuilder
//        let diffableReferences = references.mapValues { reference in
//            return AnyRenderReference(reference)
//        }
//        let otherDiffableReferences = other.references.mapValues { reference in
//            return AnyRenderReference(reference)
//        }
//        diffBuilder.differences.append(contentsOf: diffableReferences.difference(from:otherDiffableReferences, at: path + [CodingKeys.references]))

        diffBuilder.addDifferences(atKeyPath: \.primaryContentSections, forKey: CodingKeys.primaryContentSections)
        diffBuilder.addDifferences(atKeyPath: \.relationshipSections, forKey: CodingKeys.relationshipsSections)
        diffBuilder.addDifferences(atKeyPath: \.sections, forKey: CodingKeys.sections)
        
        return diffBuilder.differences
    }
}

extension Dictionary: Diffable where Key == String, Value: Encodable & Equatable {
    //TODO: This should be done in the DifferenceBuilder
    /// Returns the difference between two dictionaries with diffable values.
    func difference(from other: Dictionary<Key, Value>, at path: Path) -> Differences where Value: Diffable {
        var differences = Differences()
        let uniqueKeysSet = Set(self.keys).union(Set(other.keys))
        for key in uniqueKeysSet {
            differences.append(contentsOf: self[key].difference(from: other[key], at: path + [CustomKey(stringValue: key)]))
        }
        return differences
    }
    
    //TODO: This should be done in the DifferenceBuilder
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
    
    // For now, we are not replacing whole dictionaries
    func isSimilar(to other: Dictionary<String, Value>) -> Bool {
        return true
    }
}

extension Optional: Diffable where Wrapped: Diffable & Equatable {
    //TODO: This should be done in the DifferenceBuilder
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
    
    // TODO: Optionals should deal with replacements on their own.
    func isSimilar(to other: Optional<Wrapped>) -> Bool {
        return true
    }
}

extension Array: Diffable where Element: Equatable & Encodable {
    
    //TODO: This should be done in the DifferenceBuilder
    /// Returns the differences between this array and the given one.
    func difference(from other: Array<Element>, at path: Path) -> Differences {
        let arrayDiffs = self.difference(from: other)
        var differences = arrayDiffs.removals
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
    
    func difference(from other: Array<Element>, at path: Path) -> Differences where Element: Diffable {
        let arrayDiffs = self.difference(from: other) { element1, element2 in
            return element1.isSimilar(to: element2)
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
    
    // For now, we are not replacing whole arrays
    func isSimilar(to other: Array<Element>) -> Bool {
        return true
    }
}

// MARK: AnyRenderReference
/// A RenderReference value that can be diffed.
///
/// An `AnyRenderReference` value forwards difference operations to the underlying base type, which implement the difference differently.
struct AnyRenderReference: Diffable, Encodable, Equatable {
    
    var value: RenderReference & Codable
    init(_ value: RenderReference & Codable) { self.value = value }
    public func difference(from other: AnyRenderReference, at path: Path) -> Differences {
        var differences = Differences()
        
        // TODO: Fix this CodingKey accessibility issue
        differences.append(contentsOf: propertyDifference(value.identifier,
                                                          from: other.value.identifier,
                                                          at: path + [CustomKey(stringValue: "identifier")])
                           )
                           
        switch (value.type, other.value.type) {
        case (.file, .file):
            let value = value as! FileReference
            let otherValue = other.value as! FileReference
            differences.append(contentsOf: value.difference(from: otherValue, at: path))
        case (.image, .image):
            let value = value as! ImageReference
            let otherValue = other.value as! ImageReference
            differences.append(contentsOf: value.difference(from: otherValue, at: path))
        case (.video, .video):
            let value = value as! VideoReference
            let otherValue = other.value as! VideoReference
            differences.append(contentsOf: value.difference(from: otherValue, at: path))
        case (.fileType, .fileType):
            let value = value as! FileTypeReference
            let otherValue = other.value as! FileTypeReference
            differences.append(contentsOf: value.difference(from: otherValue, at: path))
        case (.xcodeRequirement, .xcodeRequirement):
            let value = value as! XcodeRequirementReference
            let otherValue = other.value as! XcodeRequirementReference
            differences.append(contentsOf: value.difference(from: otherValue, at: path))
        case (.topic, .topic):
            let value = value as! TopicRenderReference
            let otherValue = other.value as! TopicRenderReference
            differences.append(contentsOf: value.difference(from: otherValue, at: path))
        case (.section, .section):
            let value = value as! TopicRenderReference
            let otherValue = other.value as! TopicRenderReference
            differences.append(contentsOf: value.difference(from: otherValue, at: path))
        case (.download, .download):
            let value = value as! DownloadReference
            let otherValue = other.value as! DownloadReference
            differences.append(contentsOf: value.difference(from: otherValue, at: path))
        case (.unresolvable, .unresolvable):
            let value = value as! UnresolvedRenderReference
            let otherValue = other.value as! UnresolvedRenderReference
            differences.append(contentsOf: value.difference(from: otherValue, at: path))
        case (.link, .link):
            let value = value as! LinkReference
            let otherValue = other.value as! LinkReference
            differences.append(contentsOf: value.difference(from: otherValue, at: path))
        default:
            differences.append(.replace(pointer: JSONPointer(from: path), encodableValue: self.value))
        }
        return differences
    }
    
    static func == (lhs: AnyRenderReference, rhs: AnyRenderReference) -> Bool {
        switch (lhs.value.type, rhs.value.type) {
        case (.file, .file):
            return (lhs.value as! FileReference) == (rhs.value as! FileReference)
        case (.image, .image):
            return (lhs.value as! ImageReference) == (rhs.value as! ImageReference)
        case (.video, .video):
            return (lhs.value as! VideoReference) == (rhs.value as! VideoReference)
        case (.fileType, .fileType):
            return (lhs.value as! FileTypeReference) == (rhs.value as! FileTypeReference)
        case (.xcodeRequirement, .xcodeRequirement):
            return (lhs.value as! XcodeRequirementReference) == (rhs.value as! XcodeRequirementReference)
        case (.topic, .topic):
            return (lhs.value as! TopicRenderReference) == (rhs.value as! TopicRenderReference)
        case (.section, .section):
            return (lhs.value as! TopicRenderReference) == (rhs.value as! TopicRenderReference)
        case (.download, .download):
            return (lhs.value as! DownloadReference) == (rhs.value as! DownloadReference)
        case (.unresolvable, .unresolvable):
            return (lhs.value as! UnresolvedRenderReference) == (rhs.value as! UnresolvedRenderReference)
        case (.link, .link):
            return (lhs.value as! LinkReference) == (rhs.value as! LinkReference)
        default:
            return false
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
    
    func isSimilar(to other: AnyRenderReference) -> Bool {
        // TODO: Pass this down to the specific render references. Maybe abstract the casting into its own method and pass in a closure?
        self.value.identifier == other.value.identifier
    }
}

// MARK: AnyRenderSection

/// A RenderSection value that can be diffed.
///
/// An `AnyRenderSection` value forwards difference operations to the underlying base type, each of which determine the difference differently.
public struct AnyRenderSection: Equatable, Encodable, Diffable {
    
    // This forwards the difference methods on to the correct concrete type.
    func difference(from other: AnyRenderSection, at path: Path) -> Differences {
        switch (self.value.kind, other.value.kind) {
        case (.intro, .intro), (.hero, .hero):
            return (value as! IntroRenderSection).difference(from: (other.value as! IntroRenderSection), at: path)
//        case (.contentAndMedia, .contentAndMedia):
//            return (value as! ContentAndMediaSection).difference(from: (other.value as! ContentAndMediaSection), at: path)
//        case (.contentAndMediaGroup, .contentAndMediaGroup):
//            return (value as! ContentAndMediaGroupSection).difference(from: (other.value as! ContentAndMediaGroupSection), at: path)
//        case (.callToAction, .callToAction):
//            return (value as! CallToActionSection).difference(from: (other.value as! CallToActionSection), at: path)
//        case (.resources, .resources):
//            return (value as! ResourcesRenderSection).difference(from: (other.value as! ResourcesRenderSection), at: path)
//        case (.declarations, .declarations):
//            return (value as! DeclarationsRenderSection).difference(from: (other.value as! DeclarationsRenderSection), at: path)
        case (.discussion, .discussion), (.content, .content):
            return (value as! ContentRenderSection).difference(from: (other.value as! ContentRenderSection), at: path)
        case (.taskGroup, .taskGroup):
            return (value as! TaskGroupRenderSection).difference(from: (other.value as! TaskGroupRenderSection), at: path)
//        case (.relationships, .relationships):
//            return (value as! RelationshipsRenderSection).difference(from: (other.value as! RelationshipsRenderSection), at: path)
//        case (.parameters, .parameters):
//            return (value as! ParametersRenderSection).difference(from: (other.value as! ParametersRenderSection), at: path)
        default:
            return []
        }
    }
    
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
    
    public func isSimilar(to other: AnyRenderSection) -> Bool {
        return self.value.kind == other.value.kind
    }
}


