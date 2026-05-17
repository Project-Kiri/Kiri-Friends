// HTTPMessage.swift
// Minimal HTTP/1.1 request and response value types used by the local
// bridge listener. The bridge only handles short JSON bodies from plugin
// scripts; we avoid pulling in NIO and write a tight parser instead.

import Foundation

public struct HTTPRequest: Sendable, Hashable {
    public var method: String
    public var path: String
    public var rawTarget: String
    public var headers: [String: String]
    public var body: Data

    public init(method: String, path: String, rawTarget: String, headers: [String: String], body: Data) {
        self.method = method
        self.path = path
        self.rawTarget = rawTarget
        self.headers = headers
        self.body = body
    }

    public func header(_ name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    public func decodeJSON<T: Decodable>(as type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: body)
    }
}

public struct HTTPResponse: Sendable, Hashable {
    public var status: Int
    public var reasonPhrase: String
    public var headers: [String: String]
    public var body: Data

    public init(
        status: Int,
        reasonPhrase: String? = nil,
        headers: [String: String] = [:],
        body: Data = Data()
    ) {
        self.status = status
        self.reasonPhrase = reasonPhrase ?? HTTPResponse.defaultReason(for: status)
        self.headers = headers
        self.body = body
    }

    public static func json<T: Encodable>(_ value: T, status: Int = 200) throws -> HTTPResponse {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        return HTTPResponse(
            status: status,
            headers: [
                "Content-Type": "application/json; charset=utf-8",
                "Cache-Control": "no-store",
            ],
            body: data
        )
    }

    public static func text(_ string: String, status: Int = 200) -> HTTPResponse {
        let data = Data(string.utf8)
        return HTTPResponse(
            status: status,
            headers: [
                "Content-Type": "text/plain; charset=utf-8",
            ],
            body: data
        )
    }

    public static func empty(status: Int) -> HTTPResponse {
        HTTPResponse(status: status, headers: ["Content-Length": "0"])
    }

    public func serialize() -> Data {
        var output = "HTTP/1.1 \(status) \(reasonPhrase)\r\n"
        var headers = headers
        if headers["Content-Length"] == nil {
            headers["Content-Length"] = "\(body.count)"
        }
        if headers["Connection"] == nil {
            headers["Connection"] = "close"
        }
        for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
            output += "\(key): \(value)\r\n"
        }
        output += "\r\n"
        var data = Data(output.utf8)
        data.append(body)
        return data
    }

    private static func defaultReason(for status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 201: return "Created"
        case 202: return "Accepted"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 408: return "Request Timeout"
        case 413: return "Payload Too Large"
        case 415: return "Unsupported Media Type"
        case 500: return "Internal Server Error"
        case 503: return "Service Unavailable"
        default: return "HTTP"
        }
    }
}
