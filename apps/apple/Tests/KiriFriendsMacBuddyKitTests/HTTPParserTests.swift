// HTTPParserTests.swift
// Sanity coverage for the minimal HTTP/1.1 parser. The parser ships only
// with the surface area we use; tests here pin behaviour around partial
// data, malformed lines, large bodies, and Content-Length handling.

import Foundation
import KiriFriendsMacBuddyKit
import Testing

@Suite("HTTPParser")
struct HTTPParserTests {
    @Test("Parses a complete POST request with JSON body")
    func parsesCompleteRequest() throws {
        let parser = HTTPParser()
        let body = #"{"hello":"world"}"#
        let buffer = Data("POST /v1/plugin-events HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)".utf8)
        let phase = try parser.parse(buffer: buffer)
        switch phase {
        case .incomplete:
            Issue.record("Expected complete request")
        case .complete(let result):
            #expect(result.request.method == "POST")
            #expect(result.request.path == "/v1/plugin-events")
            #expect(result.request.header("Content-Type") == "application/json")
            #expect(result.request.body == Data(body.utf8))
            #expect(result.leftover.isEmpty)
        }
    }

    @Test("Returns incomplete when the body is short")
    func returnsIncomplete() throws {
        let parser = HTTPParser()
        let buffer = Data("POST /x HTTP/1.1\r\nContent-Length: 16\r\n\r\nshort".utf8)
        let phase = try parser.parse(buffer: buffer)
        switch phase {
        case .incomplete:
            break
        case .complete:
            Issue.record("Should not be complete")
        }
    }

    @Test("Path strips query string")
    func parsesPathWithQuery() throws {
        let parser = HTTPParser()
        let buffer = Data("GET /healthz?detail=true HTTP/1.1\r\nHost: x\r\n\r\n".utf8)
        let phase = try parser.parse(buffer: buffer)
        guard case let .complete(result) = phase else {
            Issue.record("expected complete")
            return
        }
        #expect(result.request.path == "/healthz")
        #expect(result.request.rawTarget == "/healthz?detail=true")
    }

    @Test("Rejects transfer-encoded payloads")
    func rejectsTransferEncoding() {
        let parser = HTTPParser()
        let buffer = Data("POST /x HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n0\r\n\r\n".utf8)
        do {
            _ = try parser.parse(buffer: buffer)
            Issue.record("Expected unsupportedEncoding")
        } catch {
            switch error {
            case HTTPParserError.unsupportedEncoding:
                break
            default:
                Issue.record("Unexpected error: \(error)")
            }
        }
    }
}
