//
//  SesstionController.swift
//  NetCore
//
//  Created by zhtg on 2023/5/13.
//

import Foundation

open class SesstionController: NSObject, URLSessionDelegate {

    /// 代理队列
    open var delegateQueue = OperationQueue()

    /// URLSession对象
    open var session: URLSession!

    public override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: delegateQueue)
    }

    public func urlSession(_ session: URLSession,
                           didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        ChallengeHandler.shared.authenticate(challenge: challenge, completionHandler: completionHandler)
    }
}
