/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A reference to another page which cannot be resolved.
public struct UnresolvedRenderReference: RenderReference, Equatable {
    /// The type of this unresolvable reference.
    ///
    /// This value is always `.unresolvable`.
    public var type: RenderReferenceType = .unresolvable
    
    /// The identifier of this unresolved reference.
    public var identifier: RenderReferenceIdentifier
    
    /// The title of this unresolved reference.
    public var title: String

    /// Creates a new unresolved reference with a given identifier and title.
    /// 
    /// - Parameters:
    ///   - identifier: The identifier of this unresolved reference.
    ///   - title: The title of this unresolved reference.
    public init(identifier: RenderReferenceIdentifier, title: String) {
        self.identifier = identifier
        self.title = title
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        type = try values.decode(RenderReferenceType.self, forKey: .type)
        identifier = try values.decode(RenderReferenceIdentifier.self, forKey: .identifier)
        title = try values.decode(String.self, forKey: .title)
    }
}

// Diffable conformance
extension UnresolvedRenderReference: Diffable {
    /// Returns the difference between this UnresolvedRenderReference and the given one.
    public func difference(from other: UnresolvedRenderReference, at path: Path) -> Differences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)
        
        diffBuilder.addPropertyDifference(atKeyPath: \.title, forKey: CodingKeys.title)
        
        return diffBuilder.differences
    }
}
