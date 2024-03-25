/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

extension Metadata {
    /// A directive that sets the filter tags for a documentation page.
    ///
    /// This directive is only valid within a ``Metadata`` directive:
    ///
    /// ```markdown
    /// @Metadata {
    ///     @FilterTag("New")
    ///     @FilterTag("Foundations")
    /// }
    /// ```
    public final class FilterTag: Semantic, AutomaticDirectiveConvertible {
        public static var introducedVersion: String = "6.0"
        public var originalMarkup: Markdown.BlockDirective
        
        /// The name of the tag that applies to this page.
        @DirectiveArgumentWrapped(name: .unnamed)
        public var tag: String
        
        static var keyPaths: [String : AnyKeyPath] = [
            "tag" : \FilterTag._tag,
        ]
        
        @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
        init(originalMarkup: Markdown.BlockDirective) {
            self.originalMarkup = originalMarkup
        }
    }
}
