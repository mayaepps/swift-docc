/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A semantic version.
///
/// A version that follows the [Semantic Versioning](https://semver.org) specification.
public struct SemanticVersion: Codable, Equatable, CustomStringConvertible, Diffable {
    
    /// The major version number.
    ///
    /// For example, the `1` in `1.2.3`
    public var major: Int
    
    /// The minor version number.
    ///
    /// For example, the `2` in `1.2.3`
    public var minor: Int
    
    /// The patch version number.
    ///
    /// For example, the `3` in `1.2.3`
    public var patch: Int

    /// The optional prerelease version component, which may contain non-numeric characters.
    ///
    /// For example, the `4` in `1.2.3-4`.
    public var prerelease: String?

    /// Optional build metadata.
    public var buildMetadata: String?

    public init(major: Int, minor: Int, patch: Int, prerelease: String? = nil, buildMetadata: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.major = try container.decode(Int.self, forKey: .major)
        self.minor = try container.decodeIfPresent(Int.self, forKey: .minor) ?? 0
        self.patch = try container.decodeIfPresent(Int.self, forKey: .patch) ?? 0
        self.prerelease = try container.decodeIfPresent(String.self, forKey: .prerelease)
        self.buildMetadata = try container.decodeIfPresent(String.self, forKey: .buildMetadata)
    }

    public var description: String {
        var result = "\(major).\(minor).\(patch)"
        if let prerelease = prerelease {
            result += "-\(prerelease)"
        }
        if let buildMetadata = buildMetadata {
            result += "+\(buildMetadata)"
        }
        return result
    }
    
    /// Returns the differences between this SemanticVersion and the given one.
    public func difference(from other: SemanticVersion, at path: Path) -> Differences {
        var diff = Differences()

        if major != other.major {
            diff.append(.replace(pointer: JSONPointer(from: path + [CodingKeys.major]), value: AnyCodable(major)))
        }
        if minor != other.minor {
            diff.append(.replace(pointer: JSONPointer(from: path + [CodingKeys.minor]), value: AnyCodable(minor)))
        }
        if patch != other.patch  {
            diff.append(.replace(pointer: JSONPointer(from: path + [CodingKeys.patch]), value: AnyCodable(patch)))
        }
        return diff
    }
}
