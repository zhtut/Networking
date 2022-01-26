//
//  SSNetworkHelper.swift
//  SmartFeatures
//
//  Created by zhtg on 2021/6/28.
//
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 请求方法，GET和POST
public enum SSHttpMethod: String {
    case GET
    case POST
    case DELETE
    case PUT
}

public let SSTIMEOUT: TimeInterval = 10.0

/// 网络发送工具，使用了系统的URLSession去发送网络请求
open class SSNetworkHelper: NSObject, URLSessionDelegate, URLSessionDataDelegate {
    
    @discardableResult
    /// 发送网络请求
    /// - Parameters:
    ///   - urlStr: url字符串
    ///   - params: 参数，POST方法可以是字典，数组，字符串，会放到HTTPBody中，GET只支持字典，并且会拼接到url中
    ///   - header: 请求头
    ///   - method: 方法，GET或者POST
    ///   - timeOut: 超时时间，默认为10秒
    ///   - printLog: 打印日志，默认不打印
    ///   - completion: 完成的回调，Response必不为空
    /// - Returns: 返回\(URLSesstionDataTask)
    open class func sendRequest(urlStr: String,
                                params: Any? = nil,
                                header: [String: String]? = nil,
                                method: SSHttpMethod = .GET,
                                timeOut: TimeInterval = SSTIMEOUT,
                                printLog: Bool = false,
                                completion: @escaping SSResponseHandler) -> URLSessionDataTask? {
        var urlString = urlStr
        if method == .GET {
            urlString = getURLString(url: urlStr, params: params)
        }
        guard let nsURL = URL(string: urlString) else {
            print("URL生成失败，请检查URL是否正确：\(urlString)")
            return nil
        }
        var request = URLRequest(url: nsURL)
        request.httpMethod = "\(method)"
        request.timeoutInterval = timeOut
        if header != nil {
            for (key, value) in header! {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        let needBody = (method == .POST || method == .PUT)
        if needBody && params != nil {
            if params is Data {
                let data = params as? Data
                request.httpBody = data
            } else if params is [String: Any] || params is [Any] {
                let data = try? JSONSerialization.data(withJSONObject: params!, options: JSONSerialization.WritingOptions(rawValue: 0))
                request.httpBody = data
            } else if params is String {
                let str = params as? String
                let data = str?.data(using: .utf8)
                request.httpBody = data
            }
        }
        let startTime = Date().timeIntervalSince1970 * 1000.0
        let task = URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            let resp = SSResponse.responseWith(data: data, response: response, error: error)
            resp.start = startTime
            resp.duration = Date().timeIntervalSince1970 * 1000.0 - startTime
            resp.originRequest = request
            if printLog || !resp.fetchSucceed {
                resp.logResponse()
            }
            // URLSession回调在子线程，这里回到主线程去回调给上层
            DispatchQueue.main.async {
                completion(resp)
            }
        }
        task.resume()
        return task
    }
    
    open class func getURLString(url: String, params: Any?) -> String {
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
    
    
    open class func downloadFile(urlStr: String,
                          completion: @escaping (String?, Error?) -> Void) -> URLSessionDownloadTask? {
        if let url = URL(string: urlStr) {
            let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
                if error != nil {
                    completion(nil, error)
                } else {
                    completion(localURL?.absoluteString, nil)
                }
            }
            task.resume()
            return task
        }
        return nil
    }
}

extension TimeInterval {
    public var dateDesc: String? {
        var interval = self
        if interval > 16312039620 {
            interval = interval / 1000.0
        }
        let date = Date(timeIntervalSince1970: interval)
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier:"Asia/Hong_Kong")!
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let str = formatter.string(from: date)
        return str
    }
}

public extension Dictionary {
    
    /// URL参数拼接
    var urlQueryStr: String? {
        if count == 0 {
            return nil
        }
        var paramStr: String?
        for (key,value) in self {
            var valueStr = "\(value)"
            if JSONSerialization.isValidJSONObject(value) {
                if let data = try? JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed),
                 let str = String(data: data, encoding: .utf8) {
                    valueStr = str.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
                }
            }
            let str = "\(key)=\(valueStr)"
            if paramStr == nil {
                paramStr = str
            } else {
                paramStr = "\(paramStr!)&\(str)"
            }
        }
        return paramStr
    }
}
