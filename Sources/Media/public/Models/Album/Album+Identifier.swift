//
//  Album+Identifier.swift
//  Media
//
//  Created by Christian Elies on 08.12.19.
//

extension Album {
    public struct Identifier {
        public let localIdentifier: String
    }
}

extension Album.Identifier: Hashable {}

extension Album.Identifier: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        localIdentifier = value
    }
}

extension Album.Identifier: CustomStringConvertible {
    public var description: String { localIdentifier }
}