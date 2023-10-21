//
//  Challenge.swift
//  NetCore
//
//  Created by zhtg on 2023/5/8.
//

import Foundation
#if canImport(CommonCrypto)
import CommonCrypto
#else
import Crypto
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct SSLPinning {
    /// 域名，如：api.buildyou.tech
    public var host: String
    /// 证书256指纹，大写64位，如 ["069B5CE14BE51FF06DD1E0C0554CC3EA0C9DE2171BCCF82C315CD2EF01AAB20C"]
    public var sha256s: [String]
    public init(host: String, sha256s: [String]) {
        self.host = host.replacingOccurrences(of: "*.", with: "")
        self.sha256s = sha256s
    }
}

public final class ChallengeHandler: NSObject, URLSessionDelegate {
    
    public func urlSession(_ session: URLSession,
                           didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        authenticate(challenge: challenge, completionHandler: completionHandler)
    }

    public static let shared = ChallengeHandler()

    public var pinnings: [SSLPinning]?
    
    public var session: URLSession!
    /// 代理队列
    public var delegateQueue = OperationQueue()

    private override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: delegateQueue)
    }

    public func authenticate(challenge: URLAuthenticationChallenge,
                               completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if Thread.isMainThread {
            DispatchQueue.global().async {
                self.asyncAuthenticate(challenge: challenge, completionHandler: completionHandler)
            }
        } else {
            asyncAuthenticate(challenge: challenge, completionHandler: completionHandler)
        }
    }

    func asyncAuthenticate(challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard let pinnings else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard let pinning = pinnings.first(where: { challenge.protectionSpace.host.contains($0.host) }) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard let serverTrustSha256 = serverTrust.sha256 else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // 从serverTrust copy出的第一个证书，就是我们的域名证书，取这个证书的data进行sha256，就能匹配上我们预置的sha256指纹
        if pinning.sha256s.contains(serverTrustSha256) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }

        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}

public extension Data {
    var hex: String {
        return map { String(format: "%02hhX", $0) }.joined()
    }

    var sha256: String {
        let data = self
        
#if canImport(CommonCrypto)
        
        // 创建一个指向内存缓冲区的指针，用于存储哈希结果
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(CC_SHA256_DIGEST_LENGTH))
        defer { buffer.deallocate() }
        
        // 计算哈希值
        _ = data.withUnsafeBytes {
            CC_SHA256($0.baseAddress, CC_LONG(data.count), buffer)
        }
        
        // 将哈希结果转换为 Data 对象
        let hashData = Data(bytes: buffer, count: Int(CC_SHA256_DIGEST_LENGTH))
        return hashData.hex
        
#else
        let hash = Data(SHA256.hash(data: data)).hex
        return hash
#endif
    }
}


extension SecTrust {
    /// 获取第一个证书
    var certificate: Data? {
        let certsCount = SecTrustGetCertificateCount(self)
        guard certsCount > 0 else {
            return nil
        }
        var cert: SecCertificate
        if #available(iOS 15.0, macOS 12.0, *) {
            guard let certs = SecTrustCopyCertificateChain(self) as? [SecCertificate],
                  let ccc = certs.first else {
                return nil
            }
            cert = ccc
        } else {
            // Fallback on earlier versions
            guard let ccc = SecTrustGetCertificateAtIndex(self, 0) else {
                return nil
            }
            cert = ccc
        }
        let data = SecCertificateCopyData(cert) as Data
        return data
    }

    var hex: String? {
        certificate?.hex
    }
    var sha256: String? {
        certificate?.sha256
    }
}
