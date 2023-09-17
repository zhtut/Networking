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

public struct Networking {
    
    public static var decryptHandler: ((Response) -> Data)?
    public static var session = URLSession.shared
    
    /// 接口请求超时时间
    public static let timeOut: TimeInterval = 10.0
    
    /// 资源超时时间
    public static let resourceTimeOut: TimeInterval = 60.0
    
    /// 基础url
    public static var baseURL = ""
    
    /// 发送请求
    /// - Parameter request: 请求对象
    /// - Returns: 返回请求响应对象
    public static func send(request: Request) async -> Response {
        let startTime = Date().timeIntervalSince1970 * 1000.0
        do {
            let urlRequest = try URLRequest.from(request)
            let (data, response) = try await session.data(for: urlRequest)
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
