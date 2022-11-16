//
//  File.swift
//
//
//  Created by zhtg on 2022/11/12.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public let kSSNetworkDefaultTimeOut: TimeInterval = 10.0

/// 请求方法
public enum SSHTTPMethod: String {
    case GET
    case POST
    case DELETE
    case PUT
    case PATCH
}

/// 请求器
public extension SSResponsive {
    
    /// 发送一个网络请求
    /// - Parameters:
    ///   - urlStr: 请求的URL地址，不可为空
    ///   - params: 请求的参数，可以是字典，数组，或者字符串，如果是get请求，仅支持字典，因为要放到url后面
    ///   - header: header头，默认为空
    ///   - method: 请求的http方法，默认为get
    ///   - timeOut: 超时时间，默认为10秒
    ///   - printLog: 是否打印日志，默认为false
    ///   - dataKey: 解析model的子键，使用.分隔
    ///   - modelType: 解析的model类型
    /// - Returns: 返回请求的SSResponsive，不管成功与否，这个SSResponsive都会返回，请求的详细情况都在SSResponsive中
    static func sendRequest(urlStr: String,
                            params: Any? = nil,
                            header: [String: String]? = nil,
                            method: SSHTTPMethod = .GET,
                            timeOut: TimeInterval = kSSNetworkDefaultTimeOut,
                            printLog: Bool = false,
                            dataKey: String? = nil,
                            modelType: Decodable.Type? = nil) async -> Self {
        guard let url = URL(string: urlStr) else {
            print("URL生成失败，请检查URL是否正确：\(urlStr)")
            let now = Date().timeIntervalSince1970 * 1000.0
            let response = Self(start: now,
                                request: nil,
                                body: nil,
                                urlResponse: nil,
                                error: nil,
                                duration: now)
            return response
        }
        
        // 创建请求
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeOut)
        request.httpMethod = method.rawValue
        
        // 集成参数
        await request.integrate(params: params)
        
        // 集成header
        if let header = header {
            for (key, value) in header {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        
        // 开始请求
        let startTime = Date().timeIntervalSince1970 * 1000.0
        
        let response: Self = await withCheckedContinuation({ continuation in
            sendRequest(request,
                        startTime: startTime,
                        printLog: printLog,
                        dataKey: dataKey,
                        modelType: modelType) { resp in
                continuation.resume(returning: resp)
            }
        })
        
        if printLog {
            response.log()
        }
        return response
    }
    
    static func sendRequest(_ request: URLRequest,
                            startTime: TimeInterval,
                            printLog: Bool = false,
                            dataKey: String? = nil,
                            modelType: Decodable.Type? = nil,
                            completion: @escaping (Self) -> Void) {
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            let duration = Date().timeIntervalSince1970 * 1000.0 - startTime
            var ssResponse = Self(start: startTime,
                                  request: request,
                                  body: data,
                                  urlResponse: response as? HTTPURLResponse,
                                  error: error,
                                  duration: duration)
            if let _ = data, let modelType = modelType {
                ssResponse.decodeModel(dataKey: dataKey, modelType: modelType)
            }
            completion(ssResponse)
        }
        task.resume()
    }
}
    
    extension URLRequest {
        mutating func integrate(params: Any?) async {
            guard let params = params else { return }
            let useBody = (self.httpMethod != SSHTTPMethod.GET.rawValue)
            if useBody {
                self.httpBody = await getHttpBody(params: params)
            } else {
                if let urlString = self.url?.absoluteString {
                    let newURLString = await getURLString(url: urlString, params: params)
                    self.url = URL(string: newURLString)
                }
            }
        }
        
        func getHttpBody(params: Any?) async -> Data? {
            guard let params = params else { return nil }
            var httpBody: Data?
            if params is Data {
                httpBody = params as? Data
            } else if JSONSerialization.isValidJSONObject(params) {
                httpBody = try? JSONSerialization.data(withJSONObject: params)
            } else if params is String {
                let str = params as? String
                httpBody = str?.data(using: .utf8)
            }
            return httpBody
        }
        
        func getURLString(url: String, params: Any?) async -> String {
            if params is [String: Any] {
                let dic = params as! [String : Any]
                var newURL = url
                let str = dic.urlQueryStr
                if str != nil {
                    if url.contains("?") {
                        newURL = "\(newURL)&\(str!)"
                    } else {
                        newURL = "\(newURL)?\(str!)"
                    }
                }
                return newURL
            }
            
            return url
        }
    }
    
    public extension Dictionary {
        /// URL参数拼接
        var urlQueryStr: String? {
            if count == 0 {
                return nil
            }
            var paramStr: String?
            for (key, value) in self {
                let valueStr: String
                if JSONSerialization.isValidJSONObject(value),
                   let data = try? JSONSerialization.data(withJSONObject: value, options: .init(rawValue: 0)),
                   let str = String(data: data, encoding: .utf8) {
                    valueStr = str.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                } else {
                    valueStr = "\(value)"
                }
                let str = "\(key)=\(valueStr)"
                if let last = paramStr {
                    paramStr = "\(last)&\(str)"
                } else {
                    paramStr = str
                }
            }
            return paramStr
        }
    }
