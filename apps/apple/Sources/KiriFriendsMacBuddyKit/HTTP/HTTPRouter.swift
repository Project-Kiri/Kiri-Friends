// HTTPRouter.swift
// Compact (method, path) → handler dispatch helper used by the bridge
// HTTP server. Designed for a fixed handful of routes rather than
// arbitrary REST mapping.

import Foundation

public typealias HTTPHandler = @Sendable (HTTPRequest) async -> HTTPResponse

public struct HTTPRouter: Sendable {
    public struct Route: Sendable {
        public let method: String
        public let path: String
        public let handler: HTTPHandler

        public init(method: String, path: String, handler: @escaping HTTPHandler) {
            self.method = method.uppercased()
            self.path = path
            self.handler = handler
        }
    }

    private var routes: [Route]

    public init(routes: [Route] = []) {
        self.routes = routes
    }

    public mutating func register(method: String, path: String, handler: @escaping HTTPHandler) {
        routes.append(Route(method: method, path: path, handler: handler))
    }

    public func handler(for method: String, path: String) -> HTTPHandler? {
        let upper = method.uppercased()
        return routes.first { $0.method == upper && $0.path == path }?.handler
    }

    public func dispatch(_ request: HTTPRequest) async -> HTTPResponse {
        guard let handler = handler(for: request.method, path: request.path) else {
            // Compose an Allow header listing the methods we accept for the
            // requested path so clients can distinguish "wrong path" from
            // "wrong method".
            let matchingPaths = routes.filter { $0.path == request.path }
            if matchingPaths.isEmpty {
                return .empty(status: 404)
            }
            let allow = matchingPaths.map(\.method).joined(separator: ", ")
            return HTTPResponse(
                status: 405,
                headers: ["Allow": allow, "Content-Length": "0"]
            )
        }
        return await handler(request)
    }
}
