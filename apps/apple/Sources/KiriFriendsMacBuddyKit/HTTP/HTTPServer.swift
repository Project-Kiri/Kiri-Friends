// HTTPServer.swift
// NWListener-based HTTP/1.1 server for the local bridge. The bridge only
// handles short JSON POST/GET payloads from local plugin scripts; the
// listener is bound to the loopback interface and never serves remote
// traffic.

import Foundation
import Network

public enum HTTPServerError: Error, Sendable {
    case alreadyListening
    case listenerFailed(String)
}

public actor HTTPServer {
    public struct Configuration: Sendable {
        public var host: String
        public var preferredPort: UInt16
        public var portFallbacks: [UInt16]
        public var requestTimeout: Duration

        public init(
            host: String = "127.0.0.1",
            preferredPort: UInt16 = MacBuddyKit.defaultBridgePort,
            portFallbacks: [UInt16] = [7475, 7476, 7477, 7478],
            requestTimeout: Duration = .seconds(15)
        ) {
            self.host = host
            self.preferredPort = preferredPort
            self.portFallbacks = portFallbacks
            self.requestTimeout = requestTimeout
        }

        public var candidatePorts: [UInt16] {
            [preferredPort] + portFallbacks
        }
    }

    private let configuration: Configuration
    private let router: HTTPRouter
    private var listener: NWListener?
    private var activePort: UInt16?
    private let queue = DispatchQueue(label: "com.kirifriends.macbuddy.http", qos: .userInitiated)

    public init(configuration: Configuration = Configuration(), router: HTTPRouter) {
        self.configuration = configuration
        self.router = router
    }

    public func boundPort() -> UInt16? {
        activePort
    }

    public func start() async throws {
        guard listener == nil else { throw HTTPServerError.alreadyListening }

        var lastError: Error?
        for port in configuration.candidatePorts {
            do {
                let listener = try makeListener(port: port)
                self.listener = listener
                self.activePort = port
                try await startListener(listener)
                return
            } catch {
                lastError = error
                self.listener?.cancel()
                self.listener = nil
                continue
            }
        }
        throw HTTPServerError.listenerFailed(
            "Exhausted bridge port candidates: \(configuration.candidatePorts) lastError=\(String(describing: lastError))"
        )
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        activePort = nil
    }

    private func makeListener(port: UInt16) throws -> NWListener {
        let parameters = NWParameters.tcp
        parameters.acceptLocalOnly = true
        parameters.allowLocalEndpointReuse = false
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw HTTPServerError.listenerFailed("Invalid port: \(port)")
        }
        let listener = try NWListener(using: parameters, on: nwPort)
        listener.newConnectionHandler = { [router, queue] connection in
            HTTPServerConnection(connection: connection, router: router, queue: queue).start()
        }
        return listener
    }

    /// Waits for the listener to reach `.ready` before declaring success.
    /// NWListener fails asynchronously via `stateUpdateHandler`, so the
    /// synchronous `start(queue:)` call returning is not enough to know
    /// the port bound cleanly.
    private func startListener(_ listener: NWListener) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let box = ContinuationBox(continuation: continuation)
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    box.resume(returning: ())
                case .failed(let error):
                    box.resume(throwing: error)
                case .cancelled:
                    box.resume(throwing: HTTPServerError.listenerFailed("listener cancelled before ready"))
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }
    }
}

/// Guards against double-resume by tracking the continuation state.
private final class ContinuationBox: @unchecked Sendable {
    private var continuation: CheckedContinuation<Void, Error>?
    private let lock = NSLock()

    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func resume(returning value: Void) {
        lock.lock()
        let c = continuation
        continuation = nil
        lock.unlock()
        c?.resume(returning: value)
    }

    func resume(throwing error: Error) {
        lock.lock()
        let c = continuation
        continuation = nil
        lock.unlock()
        c?.resume(throwing: error)
    }
}

// Mutable state (`buffer`) is queue-confined: every callback runs on the
// shared serial DispatchQueue, so we can claim `@unchecked Sendable`.
private final class HTTPServerConnection: @unchecked Sendable {
    private let connection: NWConnection
    private let router: HTTPRouter
    private let queue: DispatchQueue
    private let parser = HTTPParser()
    private var buffer = Data()

    init(connection: NWConnection, router: HTTPRouter, queue: DispatchQueue) {
        self.connection = connection
        self.router = router
        self.queue = queue
    }

    // Retain self inside the connection callbacks so the connection
    // object lives as long as NWConnection holds the closures. Each
    // callback drops a strong reference after running; once the
    // connection is cancelled NWConnection releases the closures and
    // self is deallocated naturally.
    func start() {
        connection.stateUpdateHandler = { state in
            switch state {
            case .failed, .cancelled:
                self.connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: queue)
        receive()
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
            if let data, !data.isEmpty {
                self.buffer.append(data)
                self.tryParse()
            }
            if let error {
                self.respondWithError(error)
                return
            }
            if isComplete {
                self.connection.cancel()
                return
            }
            self.receive()
        }
    }

    private func tryParse() {
        do {
            let phase = try parser.parse(buffer: buffer)
            guard case let .complete(result) = phase else { return }
            buffer = result.leftover
            dispatch(request: result.request)
        } catch {
            respondWithError(error)
        }
    }

    private func dispatch(request: HTTPRequest) {
        Task { [router] in
            let response = await router.dispatch(request)
            self.send(response: response)
        }
    }

    private func respondWithError(_ error: Error) {
        let status: Int
        switch error {
        case let parserError as HTTPParserError:
            switch parserError {
            case .payloadTooLarge:
                status = 413
            case .unsupportedEncoding:
                status = 501
            default:
                status = 400
            }
        default:
            status = 500
        }
        send(response: .text("\(error)", status: status))
    }

    private func send(response: HTTPResponse) {
        let data = response.serialize()
        connection.send(content: data, completion: .contentProcessed({ _ in
            self.connection.cancel()
        }))
    }
}
