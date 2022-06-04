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
}
extension Diffable {
    /// Builds and returns a JSON pointer at the given path and .
    func buildPointer(from path: Path, atKey key: CodingKey) -> JSONPointer {
        return JSONPointer(from: path + [key])
    }
    
    /// Unwraps and returns the difference between two optional properties.
    func optionalPropertyDifference<T>(_ current: T?, from other: T?, at path: Path) -> JSONPatchOperation? where T: Equatable, T: Codable {
        var difference: JSONPatchOperation? = nil
        if let current = current, let other = other {
            if current != other {
                difference = .replace(pointer: JSONPointer(from: path), encodableValue: current)
            }
        } else if other != nil {
            difference = .remove(pointer: JSONPointer(from: path))
        } else if let current = current {
            difference = .add(pointer: JSONPointer(from: path), encodableValue: current)
        }
        return difference
    }
}

public typealias Differences = [JSONPatchOperation]
public typealias Path = [CodingKey]

/// An integer coding key.
private struct IntegerKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init(_ value: Int) {
        self.intValue = value
        self.stringValue = value.description
    }
    
    init?(stringValue: String) {
        guard let intValue = Int(stringValue) else {
            return nil
        }
        
        self.intValue = intValue
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.init(intValue)
    }
}

extension RenderNode: Diffable {
    /// Returns the differences between this render node and the given one.
    public func difference(from other: RenderNode, at path: Path) -> Differences {
        
        var diffs = Differences()
        
        if kind != other.kind {
            let patch = JSONPatchOperation.replace(pointer: buildPointer(from: path, atKey: CodingKeys.kind), encodableValue: kind)
            diffs.append(patch)
        }
        diffs.append(contentsOf: abstract.difference(from: other.abstract, at: path + [CodingKeys.abstract]))
        diffs.append(contentsOf: schemaVersion.difference(from:other.schemaVersion, at: path + [CodingKeys.schemaVersion]))
        diffs.append(contentsOf: identifier.difference(from:other.identifier, at: path + [CodingKeys.identifier]))
        diffs.append(contentsOf: metadata.difference(from:other.metadata, at: path + [CodingKeys.metadata]))
//        diffs.merge(hierarchy.difference(from:other.hierarchy, at: "\(path)/hierarchy")) { (current, _) in current }
        diffs.append(contentsOf: topicSections.difference(from: other.topicSections, at: path + [CodingKeys.topicSections]))
        diffs.append(contentsOf: seeAlsoSections.difference(from: other.seeAlsoSections, at: path + [CodingKeys.seeAlsoSections]))

//        // Diffing render references
//        let diffableReferences = references.mapValues { reference in
//            return AnyRenderReference(reference)
//        }
//        let otherDiffableReferences = other.references.mapValues { reference in
//            return AnyRenderReference(reference)
//        }
//        diffs.merge(diffableReferences.difference(from:otherDiffableReferences, at: "\(path)/references")) { (current, _) in current }
//
//        //Diffing primary content sections
//        let equatablePrimaryContentSections = primaryContentSections.map { section in
//            return AnyRenderSection(section)
//        }
//        let otherEquatablePrimaryContentSections = other.primaryContentSections.map { section in
//            return AnyRenderSection(section)
//        }
//        diffs.merge(equatablePrimaryContentSections.difference(from: otherEquatablePrimaryContentSections, at: "\(path)/primaryContentSection")) { (current, _) in current }
//
//        // Diffing relationship sections
//        let equatableRelationshipSections = relationshipSections.map { section in
//            return AnyRenderSection(section)
//        }
//        let otherEquatableRelationshipSections = other.relationshipSections.map { section in
//            return AnyRenderSection(section)
//        }
//        diffs.merge(equatableRelationshipSections.difference(from: otherEquatableRelationshipSections, at: "\(path)/relationshipSections")) { (current, _) in current }
//
//        // Diffing sections
//        let equatableSections = sections.map { section in
//            return AnyRenderSection(section)
//        }
//        let otherEquatableSections = other.sections.map { section in
//            return AnyRenderSection(section)
//        }
//        diffs.merge(equatableSections.difference(from: otherEquatableSections, at: "\(path)/sections")) { (current, _) in current }
        
        return diffs
    }
}

//extension Dictionary: Diffable where Value: Diffable {
//    /// Returns the difference between two dictionaries with diffable values.
//    func difference(from other: Dictionary<Key, Value>, at path: Path) -> Differences {
//        var differences = Differences()
//        for (key, value) in self {
//            differences.merge(value.difference(from: other[key]!, at: "\(path)/\(key)")) { (current, _) in current }
//        }
//        return differences
//    }
//}

extension Optional: Diffable where Wrapped: Diffable {
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
                pointer: JSONPointer(from: path), value: current as! AnyCodable))
        }
        return difference
    }
}

extension Array: Diffable where Element: Equatable {
    /// Returns the differences between this array and the given one.
    public func difference(from other: Array<Element>, at path: Path) -> Differences {
        let arrayDiffs = self.difference(from: other)
        var differences: [CollectionDifference.Change] = arrayDiffs.insertions
        differences.append(contentsOf: arrayDiffs.removals)
        let patchOperations = differences.map { diff -> JSONPatchOperation in
            switch diff {
            case .remove(let offset, _, _):
                let pointer = JSONPointer(from: path + [IntegerKey(offset)])
                return .remove(pointer: pointer)
            case .insert(let offset, let element, _):
                let pointer = JSONPointer(from: path + [IntegerKey(offset)])
                return .add(pointer: pointer, encodableValue: element as! Encodable)
            }
        }
        
        return patchOperations
    }
}

//extension DeclarationRenderSection.Token: Diffable {
//    /// Returns the differences between this Token and the given one.
//    public func difference(from other: DeclarationRenderSection.Token, at path: Path) -> Differences {
//        var difference = Differences()
//        if text != other.text {
//            difference["\(path)/text"] = "Replace with \(text)"
//        }
//        if kind != other.kind {
//            difference["\(path)/kind"] = "Replace with \(kind)"
//        }
//        return difference
//    }
//}
//
//extension RenderHierarchy: Diffable {
//    /// Returns the difference between this RenderHierarchy and the given one.
//    public func difference(from other: RenderHierarchy, at path: Path) -> Differences {
//        var differences = Differences()
//        switch (self, other) {
//            case (let .reference(selfReferenceHierarchy), let .reference(otherReferenceHierarchy)):
//                differences.merge(selfReferenceHierarchy.difference(from: otherReferenceHierarchy, at: path)) { (current, _) in current }
//            case (let .tutorials(selfTutorialsHierarchy), let .tutorials(otherTutorialsHierarchy)):
//                differences.merge(selfTutorialsHierarchy.difference(from: otherTutorialsHierarchy, at: path)) { (current, _) in current }
//            default:
//            differences[path] = "Replace with \(self)"
//        }
//        return differences
//    }
//}
//
//extension RenderReferenceHierarchy: Diffable {
//    /// Returns the difference between this RenderReferenceHierarchy and the given one.
//    func difference(from other: RenderReferenceHierarchy, at path: Path) -> Differences {
//        return paths.difference(from: other.paths, at: "\(path)/paths")
//    }
//}
//
//extension RenderTutorialsHierarchy: Diffable {
//    /// Returns the difference between this RenderTutorialsHierarchy and the given one.
//    public func difference(from other: RenderTutorialsHierarchy, at path: Path) -> Differences {
//        var differences = Differences()
//        differences.merge(paths.difference(from: other.paths, at: "\(path)/paths")) { (current, _) in current }
//        differences.merge(reference.difference(from: other.reference, at: "\(path)/reference")) { (current, _) in current }
//        differences.merge(modules.difference(from: other.modules, at: "\(path)/modules")) { (current, _) in current }
//
//        return differences
//    }
//}
//
//extension RenderReferenceIdentifier: Diffable {
//    /// Returns the difference between this RenderReferenceIdentifier and the given one.
//    public func difference(from other: RenderReferenceIdentifier, at path: Path) -> Differences {
//
//        var differences = Differences()
//        if identifier != other.identifier {
//            differences["\(path)/identifier"] = "Replace with \(identifier)"
//        }
//        return differences
//    }
//}
//
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
//
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

extension TaskGroupRenderSection: Equatable {
    public static func == (lhs: TaskGroupRenderSection, rhs: TaskGroupRenderSection) -> Bool {
        return lhs.kind == rhs.kind && lhs.title == rhs.title && lhs.abstract == rhs.abstract && lhs.discussion?.kind == rhs.discussion?.kind && lhs.identifiers == rhs.identifiers && lhs.generated == rhs.generated
    }
}

extension RenderHierarchyChapter: Equatable {
    public static func == (lhs: RenderHierarchyChapter, rhs: RenderHierarchyChapter) -> Bool {
        return lhs.reference == rhs.reference && lhs.tutorials == rhs.tutorials
    }
}

extension RenderHierarchyTutorial: Equatable {
    public static func == (lhs: RenderHierarchyTutorial, rhs: RenderHierarchyTutorial) -> Bool {
        return lhs.reference == rhs.reference && lhs.landmarks == rhs.landmarks
    }
}

extension RenderHierarchyLandmark: Equatable {
    public static func == (lhs: RenderHierarchyLandmark, rhs: RenderHierarchyLandmark) -> Bool {
        return lhs.reference == rhs.reference && lhs.kind == rhs.kind
    }
}

extension LineHighlighter.Highlight: Equatable {
    public static func == (lhs: LineHighlighter.Highlight, rhs: LineHighlighter.Highlight) -> Bool {
        return lhs.line == rhs.line && lhs.start == rhs.start && lhs.length == rhs.length
    }
}

extension DataAsset: Equatable {
    public static func == (lhs: DataAsset, rhs: DataAsset) -> Bool {
        return lhs.context == rhs.context && lhs.variants == rhs.variants
    }
}

struct AnyRenderSection: Equatable {
    static func == (lhs: AnyRenderSection, rhs: AnyRenderSection) -> Bool {
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
        default:
            return false
        }
    }

    var value: RenderSection
    init(_ value: RenderSection) { self.value = value }
}

extension TutorialSectionsRenderSection: Equatable {
    public static func == (lhs: TutorialSectionsRenderSection, rhs: TutorialSectionsRenderSection) -> Bool {
        return lhs.tasks == rhs.tasks
    }
}

extension TutorialSectionsRenderSection.Section: Equatable {
    public static func == (lhs: TutorialSectionsRenderSection.Section, rhs: TutorialSectionsRenderSection.Section) -> Bool {
        return lhs.title == rhs.title && lhs.contentSection == rhs.contentSection && lhs.stepsSection == rhs.stepsSection && lhs.anchor == rhs.anchor
    }
}

extension ContentLayout: Equatable {
    public static func == (lhs: ContentLayout, rhs: ContentLayout) -> Bool {
        switch (lhs, rhs) {
        case (.fullWidth(let lhsContent), .fullWidth(let rhsContent)):
            return lhsContent == rhsContent
        case (.contentAndMedia(let lhsContent), .contentAndMedia(let rhsContent)):
            return lhsContent == rhsContent
        case (.columns(let lhsContent), .columns(let rhsContent)):
            return lhsContent == rhsContent
        default:
            return false
        }
    }
}

extension ContentAndMediaSection: Equatable {
    public static func == (lhs: ContentAndMediaSection, rhs: ContentAndMediaSection) -> Bool {
        return lhs.layout == rhs.layout && lhs.title == rhs.title && lhs.eyebrow == rhs.eyebrow && lhs.content == rhs.content && lhs.media == rhs.media && lhs.mediaPosition == rhs.mediaPosition
    }
}

extension TutorialAssessmentsRenderSection: Equatable {
    public static func == (lhs: TutorialAssessmentsRenderSection, rhs: TutorialAssessmentsRenderSection) -> Bool {
        return lhs.assessments == rhs.assessments && lhs.anchor == rhs.anchor
    }
}

extension TutorialAssessmentsRenderSection.Assessment: Equatable {
    public static func == (lhs: TutorialAssessmentsRenderSection.Assessment, rhs: TutorialAssessmentsRenderSection.Assessment) -> Bool {
        lhs.type == rhs.type && lhs.title == rhs.title && lhs.content == rhs.content && lhs.choices == rhs.choices
    }
}

extension TutorialAssessmentsRenderSection.Assessment.Choice: Equatable {
    public static func == (lhs: TutorialAssessmentsRenderSection.Assessment.Choice, rhs: TutorialAssessmentsRenderSection.Assessment.Choice) -> Bool {
        return lhs.content == rhs.content && lhs.isCorrect == rhs.isCorrect && lhs.justification == rhs.justification && lhs.reaction == rhs.reaction
    }
}

extension VolumeRenderSection: Equatable {
    public static func == (lhs: VolumeRenderSection, rhs: VolumeRenderSection) -> Bool {
        return lhs.name == rhs.name && lhs.image == rhs.image && lhs.content == rhs.content && lhs.chapters == rhs.chapters
    }
}

extension VolumeRenderSection.Chapter: Equatable {
    public static func == (lhs: VolumeRenderSection.Chapter, rhs: VolumeRenderSection.Chapter) -> Bool {
        return lhs.name == rhs.name && lhs.content == rhs.content && lhs.tutorials == rhs.tutorials && lhs.image == rhs.image && lhs.headings == rhs.headings
    }
}

extension ContentAndMediaGroupSection: Equatable {
    public static func == (lhs: ContentAndMediaGroupSection, rhs: ContentAndMediaGroupSection) -> Bool {
        return lhs.layout == rhs.layout && lhs.sections == rhs.sections && lhs.headings == rhs.headings
    }
}

extension CallToActionSection: Equatable {
    public static func == (lhs: CallToActionSection, rhs: CallToActionSection) -> Bool {
        return lhs.title == rhs.title && lhs.abstract == rhs.abstract && lhs.media == rhs.media && lhs.action == rhs.action && lhs.featuredEyebrow == rhs.featuredEyebrow
    }
}

extension TutorialArticleSection: Equatable {
    public static func == (lhs: TutorialArticleSection, rhs: TutorialArticleSection) -> Bool {
        return lhs.content == rhs.content
    }
}

extension ResourcesRenderSection: Equatable {
    public static func == (lhs: ResourcesRenderSection, rhs: ResourcesRenderSection) -> Bool {
        return lhs.tiles == rhs.tiles && lhs.content == rhs.content
    }
}

extension RenderTile: Equatable {
    public static func == (lhs: RenderTile, rhs: RenderTile) -> Bool {
        return lhs.identifier == rhs.identifier && lhs.title == rhs.title && lhs.content == rhs.content && lhs.action == rhs.action && lhs.media == rhs.media
    }
}

