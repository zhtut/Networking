//
//  File.swift
//  
//
//  Created by shutut on 2021/9/7.
//

import Foundation

public protocol WebSocketDelegate: AnyObject {
    func webSocketDidOpen()
    func webSocketDidReceivePing()
    func webSocketDidReceivePong()
    func webSocket(didReceiveMessageWith string: String)
    func webSocket(didReceiveMessageWith data: Data)
    func webSocket(didFailWithError error: Error)
    func webSocket(didCloseWithCode code: Int, reason: String?)
}

extension WebSocketDelegate {
    func webSocketDidOpen() {}
    func webSocketDidReceivePing() {}
    func webSocketDidReceivePong() {}
    func webSocket(didReceiveMessageWith string: String) {}
    func webSocket(didReceiveMessageWith data: Data) {}
    func webSocket(didFailWithError error: Error) {}
    func webSocket(didCloseWithCode code: Int, reason: String?) {}
}
