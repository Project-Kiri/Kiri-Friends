// HTTPRouterTests.swift
// Cheap tests for the (method, path) router used by the bridge.

import Foundation
import KiriFriendsMacBuddyKit
import Testing

@Suite("HTTPRouter")
struct HTTPRouterTests {
    @Test("Dispatch invokes the matching handler")
    func dispatchesHandler() async {
        var router = HTTPRouter()
        router.register(method: "POST", path: "/echo") { request in
            HTTPResponse(status: 200, body: request.body)
        }
        let request = HTTPRequest(
            method: "POST",
            path: "/echo",
            rawTarget: "/echo",
            headers: [:],
            body: Data("ping".utf8)
        )
        let response = await router.dispatch(request)
        #expect(response.status == 200)
        #expect(response.body == Data("ping".utf8))
    }

    @Test("Unknown path yields 404")
    func unknownPath() async {
        let router = HTTPRouter()
        let request = HTTPRequest(
            method: "GET",
            path: "/missing",
            rawTarget: "/missing",
            headers: [:],
            body: Data()
        )
        let response = await router.dispatch(request)
        #expect(response.status == 404)
    }

    @Test("Wrong method on a known path yields 405 with Allow header")
    func wrongMethod() async {
        var router = HTTPRouter()
        router.register(method: "POST", path: "/state") { _ in
            HTTPResponse(status: 204)
        }
        let request = HTTPRequest(
            method: "GET",
            path: "/state",
            rawTarget: "/state",
            headers: [:],
            body: Data()
        )
        let response = await router.dispatch(request)
        #expect(response.status == 405)
        #expect(response.headers["Allow"]?.contains("POST") == true)
    }
}
