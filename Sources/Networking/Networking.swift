//
//  File.swift
//  
//
//  Created by zhtut on 2023/9/15.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 网络错误
public enum NetworkError: Error {
    /// 返回时出现参数错误
    case wrongResponse
}

public struct Networking {
    
    public static var decryptHandler: ((Response) -> Data)?
    public static var session = URLSession.shared
    
    /// 接口请求超时时间
    public static let timeOut: TimeInterval = 10.0
    
    /// 资源超时时间
    public static let resourceTimeOut: TimeInterval = 60.0
    
    /// 基础url
    public static var baseURL = ""
    
    public static func send(request: URLRequest) async throws -> (Data, URLResponse) {
#if os(macOS) || os(iOS)
        return try await session.data(for: request)
#else
        return withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let data, let response {
                    continuation.resume(returning: (data, response))
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: NetworkError.wrongResponse)
                }
            }
            task.resume()
        }
#endif
    }
    
    /// 发送请求
    /// - Parameter request: 请求对象
    /// - Returns: 返回请求响应对象
    public static func send(request: Request) async -> Response {
        let startTime = Date().timeIntervalSince1970 * 1000.0
        do {
            let urlRequest = try URLRequest.from(request)
            let (data, response) = try await send(request: urlRequest)
            let res = Response(start: startTime,
                               request: request,
                               body: data,
                               urlResponse: response as? HTTPURLResponse)
            
            // 如果配置有解密方法，则优先用解密方法解密一下
            if let decryptHandler = decryptHandler {
                res.body = decryptHandler(res)
            }
            
            // 解析Model
            res.dataKey = request.dataKey
            res.modelType = request.modelType
            if res.succeed, let _ = request.modelType {
                try await res.decodeModel()
            }
            
            if request.printLog {
                Task {
                    await res.log()
                }
            }
            return res
        } catch {
            let res = Response(start: startTime,
                               request: request,
                               error: error)
            return res
        }
    }
}
