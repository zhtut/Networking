//
//  Challenge.swift
//  SSNetwork
//
//  Created by zhtg on 2023/5/8.
//

import Foundation
import CommonCrypto

public struct SSLPinning {
    public var host: String
    public var certHashes: [String]
    public init(host: String, certHashes: [String]) {
        self.host = host
        self.certHashes = certHashes
    }
}

public final class ChallengeHandler: NSObject {

    public static let shared = ChallengeHandler()

    public var pinnings: [SSLPinning]?

    private override init() {
        super.init()
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

        guard let pinning = pinnings.first(where: { $0.host == challenge.protectionSpace.host }) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        var policies = [SecPolicy]()
        policies.append(SecPolicyCreateBasicX509())

        SecTrustSetPolicies(serverTrust, policies as CFArray);

        var trustedPublicKeyCount = 0

        let publicKeys = certificateTrustChainForServerTrust(serverTrust)

        // 子证书匹配数量
        for publicKey in publicKeys {
            if let sha256 = publicKey.headSha256,
               pinning.certHashes.contains(sha256) {
                trustedPublicKeyCount += 1
            }
        }

        // 数量要大于或等于配置的数量
        if trustedPublicKeyCount >= pinning.certHashes.count {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }

        completionHandler(.cancelAuthenticationChallenge, nil)
    }

    func certificateTrustChainForServerTrust(_ serverTrust: SecTrust) -> [SecKey] {
        var trustChain = [SecKey]()

        let rootPublicKey: SecKey?
        if #available(iOS 14.0, *) {
            rootPublicKey = SecTrustCopyKey(serverTrust)
        } else {
            rootPublicKey = SecTrustCopyPublicKey(serverTrust)
        }
        if let rootPublicKey = rootPublicKey {
            trustChain.append(rootPublicKey)
        }

        let certificateCount = SecTrustGetCertificateCount(serverTrust)

        for i in 0..<certificateCount {
            let certificate = SecTrustGetCertificateAtIndex(serverTrust, i)

            let certificates = [certificate]

            let policy = SecPolicyCreateBasicX509()
            var trust: SecTrust?
            SecTrustCreateWithCertificates(certificates as CFTypeRef, policy, &trust)

            if let trust = trust {

                var error: CFError?
                if SecTrustEvaluateWithError(trust, &error) {
                    let publicKey: SecKey?
                    if #available(iOS 14.0, *) {
                        publicKey = SecTrustCopyKey(trust)
                    } else {
                        publicKey = SecTrustCopyPublicKey(trust)
                    }
                    if let publicKey = publicKey {
                        trustChain.append(publicKey)
                    }
                }
            }
        }

        return trustChain
    }
}

extension Data {
    var sha256: Data {
        let data = self
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        let out = Data(hash)
        return out
    }
}

extension SecKey {
    static var _header: Data?
    static var header: Data? {
        if let _header = _header {
            return _header
        }
        let str = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A"
        if let data = str.data(using: .utf8),
           let decode = Data(base64Encoded: data, options: .ignoreUnknownCharacters) {
            _header = decode
            return decode
        }
        return nil
    }
    var headSha256: String? {
        var error: Unmanaged<CFError>?
        if var data = SecKeyCopyExternalRepresentation(self, &error) as? Data {
            if let header = Self.header {
                data.insert(contentsOf: header, at: 0)
                let sha256Data = data.sha256
                let base64 = sha256Data.base64EncodedString(options: .lineLength64Characters)
                return base64
            }
        } else {
            print("seckey 转换成data失败：\(error)")
        }
        return nil
    }
    var sha256: String? {
        var error: Unmanaged<CFError>?
        if var data = SecKeyCopyExternalRepresentation(self, &error) as? Data {
            let sha256Data = data.sha256
            let hex = sha256Data.upperHex
            return hex
        } else {
            print("seckey 转换成data失败：\(error)")
        }
        return nil
    }
}


private extension Sequence where Element == UInt8 {
    var upperHex: String {
        return reduce("") {$0 + String(format: "%02X", $1)}
    }
}
