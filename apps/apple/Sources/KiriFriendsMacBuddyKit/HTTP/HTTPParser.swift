// HTTPParser.swift
// Hand-rolled HTTP/1.1 request parser tuned for the bridge's tiny
// surface area (short JSON bodies, no chunked transfer, no pipelining).
// The parser tracks state across multiple data chunks so it works inside
// the streaming `NWConnection.receive` callback.

import Foundation

public enum HTTPParserError: Error, Sendable, Equatable {
    case invalidRequestLine
    case invalidHeader
    case payloadTooLarge(limit: Int)
    case unsupportedEncoding(String)
}

public struct HTTPParser: Sendable {
    public static let maxBodyBytes: Int = 1 * 1024 * 1024

    public struct Result: Sendable {
        public var request: HTTPRequest
        public var consumedBytes: Int
        public var leftover: Data
    }

    public enum Phase: Sendable {
        case incomplete
        case complete(Result)
    }

    public init() {}

    /// Attempts to parse a full HTTP request from `buffer`. Returns
    /// `.incomplete` when more bytes are needed.
    public func parse(buffer: Data) throws -> Phase {
        guard let headerEndRange = buffer.range(of: Data("\r\n\r\n".utf8)) else {
            return .incomplete
        }

        let headerEnd = headerEndRange.lowerBound
        let headerData = buffer.prefix(upTo: headerEnd)
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            throw HTTPParserError.invalidHeader
        }

        var lines = headerString.split(separator: "\r\n", omittingEmptySubsequences: false).map(String.init)
        guard !lines.isEmpty else { throw HTTPParserError.invalidRequestLine }
        let requestLine = lines.removeFirst()
        let requestComponents = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard requestComponents.count >= 3 else { throw HTTPParserError.invalidRequestLine }
        let method = requestComponents[0]
        let rawTarget = requestComponents[1]
        let path = String(rawTarget.split(separator: "?", maxSplits: 1).first ?? Substring(rawTarget))

        var headers: [String: String] = [:]
        for line in lines {
            if line.isEmpty { continue }
            guard let colonIndex = line.firstIndex(of: ":") else {
                throw HTTPParserError.invalidHeader
            }
            let key = line[..<colonIndex].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        if let transferEncoding = headerValue(for: "Transfer-Encoding", in: headers) {
            throw HTTPParserError.unsupportedEncoding(transferEncoding)
        }

        let contentLength: Int = {
            guard let raw = headerValue(for: "Content-Length", in: headers), let value = Int(raw) else {
                return 0
            }
            return max(0, value)
        }()

        if contentLength > Self.maxBodyBytes {
            throw HTTPParserError.payloadTooLarge(limit: Self.maxBodyBytes)
        }

        let bodyStart = headerEnd + 4
        let bodyAvailable = buffer.count - bodyStart
        if bodyAvailable < contentLength {
            return .incomplete
        }

        let body = buffer.subdata(in: bodyStart..<(bodyStart + contentLength))
        let consumed = bodyStart + contentLength
        let leftover = buffer.suffix(from: consumed)

        let request = HTTPRequest(
            method: method,
            path: path,
            rawTarget: rawTarget,
            headers: headers,
            body: body
        )
        return .complete(Result(request: request, consumedBytes: consumed, leftover: Data(leftover)))
    }

    private func headerValue(for name: String, in headers: [String: String]) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
}
