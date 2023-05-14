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
import Combine

@available(iOS 13.0, *)
@available(macOS 10.15, *)
/// 使用系统的URLSessionWebSocketTask实现的WebSocket客户端
open class WebSocket: SesstionController, URLSessionWebSocketDelegate {
    
    /// url地址
    open var url: URL? {
        return request.url
    }
    
    /// 请求对象
    open private(set) var request: URLRequest
    
    /// 代理
    open var onOpenPublisher = PassthroughSubject<Void, Never>()
    open var onPongPublisher = PassthroughSubject<Void, Never>()
    open var onDataPublisher = PassthroughSubject<Data, Never>()
    open var onErrorPublisher = PassthroughSubject<Error, Never>()
    open var onClosePublisher = PassthroughSubject<(Int, String?), Never>()
    
    /// 请求task，保持长连接的task
    private var task: URLSessionWebSocketTask?
    
    /// 连接状态
    open var state: URLSessionTask.State {
        guard let task else {
            return .suspended
        }
        return task.state
    }

    /// 自动重连接
    open var autoReconnect = true
    
    public init(url: URL) {
        self.request = URLRequest(url: url)
        super.init()
    }
    
    public init(request: URLRequest) {
        self.request = request
        super.init()
    }
    
    /// 开始连接
    open func open() {
        if state == .running {
            return
        }
        task = session.webSocketTask(with: request)
        task?.maximumMessageSize = 4096
        task?.resume()
    }
    
    /// 关闭连接
    /// - Parameters:
    ///   - closeCode: 关闭的code，可不填
    ///   - reason: 关闭的原因，可不填
    open func close(_ closeCode: URLSessionWebSocketTask.CloseCode = .normalClosure,
                    reason: String? = nil) {
        task?.cancel(with: closeCode, reason: reason?.data(using: .utf8))
    }
    
    /// 发送字符串
    /// - Parameter string: 要发送的字符串
    open func send(string: String) async throws {
        try await task?.send(.string(string))
    }
    
    /// 发送data
    /// - Parameter data: 要发送的data
    open func send(data: Data) async throws {
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
                onDataPublisher.send(data)
            }
        case .data(let data):
            onDataPublisher.send(data)
        }

        try await receive()
    }
    
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        webScoketPrint("didBecomeInvalidWithError:\(error?.localizedDescription ?? "")")
        var code = -1
        if let nsError = error as? NSError {
            code = nsError.code
        }
        let reason = error?.localizedDescription ?? "URLSession become invalid"
        didClose(code: code, reason: reason)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil {
            webScoketPrint("didCompleteWithError:\(error?.localizedDescription ?? "")")
        }
        
        if let err = error as NSError?,
            err.code == 57 {
            webScoketPrint("读取数据失败，连接已中断：\(err)")
            didClose(code: err.code, reason: err.localizedDescription)
            return
        }
        if let error {
            onErrorPublisher.send(error)
        }
        if autoReconnect {
            reConnect()
        }
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        webScoketPrint("webSocketTask:didOpenWithProtocol:\(`protocol` ?? "")")
        onOpenPublisher.send()
        Task {
            do {
                try await self.receive()
            }
            catch {
                print("读取数据错误：\(error)")
            }
        }
    }
    
    public func urlSession(_ session: URLSession,
                           webSocketTask: URLSessionWebSocketTask,
                           didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                           reason: Data?) {
        webScoketPrint("urlSession:didCloseWith:\(closeCode)")
        var r = ""
        if let d = reason {
            r = String(data: d, encoding: .utf8) ?? ""
        }
        let intCode = closeCode.rawValue
        didClose(code: intCode, reason: r)
    }
    
    func didClose(code: Int, reason: String?) {
        onClosePublisher.send((code, reason))
        task = nil
        if autoReconnect {
            reConnect()
        }
    }

    func reConnect() {
        if state != .running {
            print("一秒后重新连接")
            let time = Date().addingTimeInterval(1)
            let type = OperationQueue.SchedulerTimeType(time)
            delegateQueue.schedule(after: type) {
                print("重新连接")
                self.open()
            }
        }
    }
}
