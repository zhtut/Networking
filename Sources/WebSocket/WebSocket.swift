//
//  File.swift
//
//
//  Created by shutut on 2021/9/7.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(CombineX)
import CombineX
#else
import Combine
#endif

#if canImport(WebSocketKit)
import WebSocketKit
import NIO
import NIOWebSocket
import NIOPosix
#endif

/// 使用系统的URLSessionWebSocketTask实现的WebSocket客户端
#if canImport(WebSocketKit)
@available(macOS 12, *)
@available(iOS 15.0, *)
#else
@available(macOS 10.15, *)
@available(iOS 13.0, *)
#endif
open class WebSocket: NSObject {
    
#if canImport(WebSocketKit)
    /// eventLoop组
    var elg = MultiThreadedEventLoopGroup(numberOfThreads: 2)
    
    /// websocket对象
    open var ws: WebSocketKit.WebSocket?
    
#else
    
    public var session: URLSession!
    
    /// 请求task，保持长连接的task
    private var task: URLSessionWebSocketTask?
    
#endif

    /// url地址
    open var url: URL? {
        didSet {
            if let url, request?.url != url {
                request = URLRequest(url: url)
            }
        }
    }

    /// 请求对象
    open var request: URLRequest? {
        didSet {
            if url != request?.url {
                url = request?.url
            }
        }
    }
    
    /// 是否打印日志
    open var isPrintLog = true
    
    open var subscriptionSet = Set<AnyCancellable>()

    /// 代理
    open var onWillOpenPublisher = PassthroughSubject<Void, Never>()
    open var onOpenPublisher = PassthroughSubject<Void, Never>()
    open var onPongPublisher = PassthroughSubject<Void, Never>()
    open var onDataPublisher = PassthroughSubject<Data, Never>()
    open var onErrorPublisher = PassthroughSubject<Error, Never>()
    open var onClosePublisher = PassthroughSubject<(Int, String?), Never>()

    private var onReopenPublisher = PassthroughSubject<Void, Never>()

    private var publisherQueue = DispatchQueue(label: "publisherQueue", attributes: .concurrent)
    
#if canImport(WebSocketKit)
    private var _state = WebSocketState.closed
#endif

    /// 连接状态
    open var state: WebSocketState {
#if canImport(WebSocketKit)
        guard let ws else {
            return WebSocketState.closed
        }
        return ws.isClosed ? WebSocketState.closed : _state
#else
        guard let task else {
            return WebSocketState.closed
        }
        switch task.state {
        case .running:
            return WebSocketState.connected
        case .suspended:
            return WebSocketState.suspended
        case .canceling:
            return WebSocketState.closing
        case .completed:
            return WebSocketState.closed
        @unknown default:
            return WebSocketState.closed
        }
#endif
    }

    /// 自动重连接
    open var autoReconnect = true
    var lastConnectTime = 0.0
    var retryDuration = 10.0

    public init(url: URL) {
        super.init()
        self.url = url
        self.request = URLRequest(url: url)
        setup()
    }

    public init(request: URLRequest) {
        super.init()
        self.request = request
        self.url = request.url
        setup()
    }

    public override init() {
        super.init()
        setup()
    }
    
    private func log(_ str: String) {
        if isPrintLog {
            print("Websocket-->:\(str)")
        }
    }

    open func setup() {
#if canImport(WebSocketKit)
#else
        session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
#endif
        
        onReopenPublisher
            .sink { [weak self] in
                guard let self else { return }
                log("重新连接")
                self.open()
            }
            .store(in: &subscriptionSet)
    }

    /// 开始连接
    open func open() {
        if state == .connected || state == .connecting {
            log("state为connected，不需要连接")
            return
        }
        self.onWillOpenPublisher.send()
        guard let request else {
            log("连接时发现错误，没有URLRequest")
            return
        }
#if canImport(WebSocketKit)
            let urlStr = request.url?.absoluteString
            log("开始连接\(urlStr ?? "")")
            
            guard let urlStr = urlStr else {
                print("url和request的url都为空，无法连接websocket")
                return
            }
            
            Task {
                var httpHeaders = HTTPHeaders()
                if let requestHeaders = request.allHTTPHeaderFields {
                    for (key, value) in requestHeaders {
                        httpHeaders.add(name: key, value: value)
                    }
                }
                let config = WebSocketClient.Configuration()
                try await WebSocketKit.WebSocket.connect(to: urlStr,
                                                         headers: httpHeaders,
                                                         configuration: config,
                                                         on: elg,
                                                         onUpgrade: setupWebSocket)
            }
#else
            
            task = session.webSocketTask(with: request)
            task?.maximumMessageSize = 4096
            log("开始连接\(request.url?.absoluteString ?? "")")
            task?.resume()
#endif
    }

    func reConnect() {
        log("尝试重新连接")
        if state == .connected {
            log("当前状态是连接中，不用重连")
            return
        }
        onReopenPublisher.send()
    }
}

#if canImport(WebSocketKit)
@available(macOS 12, *)
extension WebSocket {
    
    /// 连接上了
    /// - Parameter ws: websocket对象
    @Sendable func setupWebSocket(ws: WebSocketKit.WebSocket) async {
        self.ws = ws
        configWebSocket()
        publisherQueue.async {
            self.onOpenPublisher.send()
        }
    }
    
    /// 详细配置回调的方法
    func configWebSocket() {
        log("websocket连接成功")
        ws?.pingInterval = TimeAmount.minutes(8)
        ws?.onText({ [weak self] (_, string) async in
            self?.didReceive(string)
        })
        ws?.onBinary({ [weak self] (_, buffer) async in
            let data = Data(buffer: buffer)
            self?.didReceive(data)
        })
        ws?.onPong({ [weak self] (_, _) async in
            self?.didReceivePong()
        })
        ws?.onPing({ [weak self] _, _ async in
            self?.didReceivePing()
        })
        ws?.onClose.whenComplete({ [weak self] result in
            var code = -1
            if let closeCode = self?.ws?.closeCode {
                switch closeCode {
                case .normalClosure:
                    code = 1000
                case .goingAway:
                    code = 1001
                case .protocolError:
                    code = 1002
                case .unacceptableData:
                    code = 1003
                case .dataInconsistentWithMessage:
                    code = 1007
                case .policyViolation:
                    code = 1008
                case .messageTooLarge:
                    code = 1009
                case .missingExtension:
                    code = 1010
                case .unexpectedServerError:
                    code = 1011
                default:
                    code = -1
                }
            }
            self?.didClose(code: code)
        })
    }
}
#else
extension WebSocket: URLSessionWebSocketDelegate {
    private func receive() async throws {
        guard let task = task else {
            throw WebSocketError.noTask
        }
        guard state == .connected else {
            throw WebSocketError.taskNotRunning
        }
        
        let message = try await task.receive()
        switch message {
        case .string(let string):
            didReceive(string)
        case .data(let data):
            didReceive(data)
        @unknown default:
            self.log("task.receive error")
        }
        
        try await receive()
    }
    
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        log("didBecomeInvalidWithError:\(error?.localizedDescription ?? "")")
        var code = -1
        if let nsError = error as? NSError {
            code = nsError.code
        }
        let reason = error?.localizedDescription ?? "URLSession become invalid"
        didClose(code: code, reason: reason)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        log("didCompleteWithError:\(error?.localizedDescription ?? "")")
        
        if let err = error as NSError?,
           err.code == 57 {
            log("读取数据失败，连接已中断：\(err)")
            didClose(code: err.code, reason: err.localizedDescription)
            return
        }
        if let error {
            publisherQueue.async {
                self.onErrorPublisher.send(error)
            }
        }
        if autoReconnect {
            reConnect()
        }
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        log("webSocketTask:didOpenWithProtocol:\(`protocol` ?? "")")
        publisherQueue.async {
            self.onOpenPublisher.send()
        }
        Task {
            do {
                try await self.receive()
            }
            catch {
                self.log("读取数据错误：\(error)")
            }
        }
    }
    
    public func urlSession(_ session: URLSession,
                           webSocketTask: URLSessionWebSocketTask,
                           didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                           reason: Data?) {
        log("urlSession:didCloseWith:\(closeCode)")
        var r = ""
        if let d = reason {
            r = String(data: d, encoding: .utf8) ?? ""
        }
        let intCode = closeCode.rawValue
        didClose(code: intCode, reason: r)
    }
}
#endif

// MARK: receive
#if canImport(WebSocketKit)
@available(macOS 12, *)
#endif
extension WebSocket {
    func didReceive(_ string: String) {
        if let data = string.data(using: .utf8) {
            publisherQueue.async {
                self.onDataPublisher.send(data)
                self.log("收到string:\(string)")
            }
        }
    }
    
    func didReceive(_ data: Data) {
        publisherQueue.async {
            self.onDataPublisher.send(data)
            self.log("收到data: \(String(data: data, encoding: .utf8) ?? "")")
        }
    }
    
    func didReceivePong() {
        log("收到pong")
        publisherQueue.async {
            self.onPongPublisher.send()
        }
    }
    
    func didReceivePing() {
#if canImport(WebSocketKit)
        log("收到ping")
        Task {
            try await sendPong()
        }
#endif
    }
    
    func didClose(code: Int, reason: String? = nil) {
        log("已关闭：\(code) \(reason ?? "")")
        publisherQueue.async {
            self.onClosePublisher.send((code, reason))
        }
#if canImport(WebSocketKit)
#else
        task = nil
#endif
        if autoReconnect {
            reConnect()
        }
    }
}

// MARK: send

#if canImport(WebSocketKit)
@available(macOS 12, *)
#endif
extension WebSocket {
    
    /// 关闭连接
    /// - Parameters:
    ///   - closeCode: 关闭的code，可不填
    ///   - reason: 关闭的原因，可不填
    public func close(_ closeCode: URLSessionWebSocketTask.CloseCode = .normalClosure,
                    reason: String? = nil) async throws {
        if state == .connected {
#if canImport(WebSocketKit)
            try await ws?.close(code: .init(codeNumber: closeCode.rawValue))
#else
            task?.cancel(with: closeCode, reason: reason?.data(using: .utf8))
#endif
        }
    }
    
    /// 发送字符串
    /// - Parameter string: 要发送的字符串
    public func send(string: String) async throws {
        guard state == .connected else {
            log("连接没有成功，发送失败")
            return
        }
        log("发送string:\(string)")
#if canImport(WebSocketKit)
        try await ws?.send(string)
#else
        try await task?.send(.string(string))
#endif
    }
    
    /// 发送data
    /// - Parameter data: 要发送的data
    public func send(data: Data) async throws {
        guard state == .connected else {
            log("连接没有成功，发送失败")
            return
        }
        log("发送Data:\(data.count)")
#if canImport(WebSocketKit)
        let bytes = [UInt8](data)
        try await ws?.send(bytes)
#else
        try await task?.send(.data(data))
#endif
    }
    
    /// 发送一个ping
    public func sendPing() async throws {
#if canImport(WebSocketKit)
        try await ws?.sendPing()
#else
        return try await withCheckedThrowingContinuation { continuation in
            task?.sendPing(pongReceiveHandler: { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
#endif
    }
    
#if canImport(WebSocketKit)
    /// 系统的自己会回pong，连方法都没有给出
    public func sendPong() async throws {
        try await ws?.send(raw: Data(), opcode: .pong, fin: true)
    }
#endif
}
