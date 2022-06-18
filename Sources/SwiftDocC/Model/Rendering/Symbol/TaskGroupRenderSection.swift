/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A task group section that contains links to other symbols.
public struct TaskGroupRenderSection: RenderSection, Equatable {
    public let kind: RenderSectionKind = .taskGroup
    
    /// An optional title for the section.
    public let title: String?
    /// An optional abstract summary for the section.
    public let abstract: [RenderInlineContent]?
    /// An optional discussion for the section.
    public var discussion: RenderSection? {
        get {
            typeErasedSection?.value
        }
        set {
            if let newValue = newValue {
                typeErasedSection = AnyRenderSection(newValue)
            }
        }
    }
    
    private var typeErasedSection: AnyRenderSection?

    /// A list of topic graph references.
    public let identifiers: [String]
    /// If true, this is an automatically generated group. If false, this is an authored group.
    public let generated: Bool
    
    /// Creates a new task group.
    /// - Parameters:
    ///   - title: An optional title for the section.
    ///   - abstract: An optional abstract summary for the section.
    ///   - discussion: An optional discussion for the section.
    ///   - identifiers: A list of topic-graph references.
    ///   - generated: If `true`, this is an automatically generated group. If `false`, this is an authored group.
    public init(title: String?, abstract: [RenderInlineContent]?, discussion: RenderSection?, identifiers: [String], generated: Bool = false) {
        self.title = title
        self.abstract = abstract
        self.identifiers = identifiers
        self.generated = generated
        self.discussion = discussion
    }
    
    /// The list of keys you use to encode or decode this section.
    private enum CodingKeys: CodingKey {
        case title, abstract, discussion, identifiers, generated
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(abstract, forKey: .abstract)
        try container.encodeIfPresent(discussion.map(CodableRenderSection.init), forKey: .discussion)
        try container.encode(identifiers, forKey: .identifiers)
        if generated {
            try container.encode(generated, forKey: .generated)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        title = try container.decodeIfPresent(String.self, forKey: .title)
        abstract = try container.decodeIfPresent([RenderInlineContent].self, forKey: .abstract)
        identifiers = try container.decode([String].self, forKey: .identifiers)

        decoder.registerReferences(identifiers)

        generated = try container.decodeIfPresent(Bool.self, forKey: .generated) ?? false
        discussion = (try container.decodeIfPresent(CodableContentSection.self, forKey: .discussion)).map { $0.section }
    }
}

extension TaskGroupRenderSection {

    /// Creates a new instance with the given automatically curated task group data.
    init(taskGroup group: AutomaticCuration.TaskGroup) {
        self.title = group.title
        self.abstract = nil
        self.identifiers = group.references.map({ $0.absoluteString })
        self.generated = false
        self.discussion = nil
    }
}

// Conformance to Diffable
extension TaskGroupRenderSection: Diffable {
    func difference(from other: TaskGroupRenderSection, at path: Path) -> Differences {
        if let diff = self.checkIfReplaced(comparingAgainst: other, at: path) {
            return diff
        }
        var diffs = Differences()
        
        diffs.append(contentsOf: optionalPropertyDifference(title, from: other.title, at: path + [CodingKeys.title]))
        
        //TODO: RenderSection has to conform to Diffable
//        diffs.append(contentsOf: discussion.difference(from: other.discussion, at: path + [CodingKeys.discussion]))
        diffs.append(contentsOf: identifiers.difference(from: other.identifiers, at: path + [CodingKeys.identifiers]))
        diffs.append(contentsOf: propertyDifference(generated, from: other.generated, at: path + [CodingKeys.generated]))
        return diffs
    }
    
    func similar(to other: TaskGroupRenderSection) -> Bool {
        return ((title != nil) && title == other.title) || ((abstract != nil) && abstract == other.abstract) ||  identifiers == other.identifiers
        // TODO: || discussion == other.discussion
    }
}
