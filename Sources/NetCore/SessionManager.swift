//
//  URLSession.swift
//  NetCore
//
//  Created by zhtg on 2023/5/8.
//

import Foundation

open class SessionManager: NSObject, URLSessionDelegate {

    public static let shared = SessionManager()
    public var session: URLSession!

    private override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    public func urlSession(_ session: URLSession,
                           didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        ChallengeHandler.shared.authenticate(challenge: challenge, completionHandler: completionHandler)
    }
}
