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

/// 使用系统的URLSessionWebSocketTask实现的WebSocket客户端
@available(iOS 13.0, *)
@available(macOS 10.15, *)
open class WebSocket: NSObject, URLSessionWebSocketDelegate {
    
    public var session: URLSession!

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

    /// 请求task，保持长连接的task
    private var task: URLSessionWebSocketTask?

    private var publisherQueue = DispatchQueue(label: "publisherQueue", attributes: .concurrent)

    /// 连接状态
    open var state: URLSessionTask.State {
        guard let task else {
            return .suspended
        }
        return task.state
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
        session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        
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
        if state == .running {
            log("state为running，不需要连接")
            return
        }
        self.onWillOpenPublisher.send()
        guard let request else {
            log("连接时发现错误，没有URLRequest")
            return
        }
        task = session.webSocketTask(with: request)
        task?.maximumMessageSize = 4096
        log("开始连接\(request.url?.absoluteString ?? "")")
        task?.resume()
    }

    /// 关闭连接
    /// - Parameters:
    ///   - closeCode: 关闭的code，可不填
    ///   - reason: 关闭的原因，可不填
    open func close(_ closeCode: URLSessionWebSocketTask.CloseCode = .normalClosure,
                    reason: String? = nil) {
        if state == .running {
            task?.cancel(with: closeCode, reason: reason?.data(using: .utf8))
        }
    }

    /// 发送字符串
    /// - Parameter string: 要发送的字符串
    open func send(string: String) async throws {
        guard state == .running else {
            log("连接没有成功，发送失败")
            return
        }
        log("发送string:\(string)")
        try await task?.send(.string(string))
    }

    /// 发送data
    /// - Parameter data: 要发送的data
    open func send(data: Data) async throws {
        guard state == .running else {
            log("连接没有成功，发送失败")
            return
        }
        log("发送Data:\(data.count)")
        try await task?.send(.data(data))
    }

    /// 发送一个ping
    /// - Parameter completionHandler: 完成的回调，可不传
    open func sendPing(_ completionHandler: @escaping ((Error?) -> Void)) {
        task?.sendPing(pongReceiveHandler: completionHandler)
    }

    private func receive() async throws {
        guard let task = task else {
            throw WebSocketError.noTask
        }
        guard task.state == .running else {
            throw WebSocketError.taskNotRunning
        }

        let message = try await task.receive()
        switch message {
        case .string(let string):
            if let data = string.data(using: .utf8) {
                publisherQueue.async {
                    self.onDataPublisher.send(data)
                    self.log("收到string:\(string)")
                }
            }
        case .data(let data):
            publisherQueue.async {
                self.onDataPublisher.send(data)
                self.log("收到data: \(String(data: data, encoding: .utf8) ?? "")")
            }
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

    func didClose(code: Int, reason: String?) {
        publisherQueue.async {
            self.onClosePublisher.send((code, reason))
        }
        task = nil
        if autoReconnect {
            reConnect()
        }
    }

    func reConnect() {
        log("尝试重新连接")
        if state == .running {
            log("当前状态是连接中，不用重连")
            return
        }
        onReopenPublisher.send()
    }
}
