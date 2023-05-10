//
//  File.swift
//
//
//  Created by zhtg on 2022/11/16.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Combine

/// 默认实现的一个Model
public struct Response: Error {

    /// 请求成功的
    public init(start: TimeInterval,
         duration: TimeInterval,
         request: Request?,
         body: Data?,
         urlResponse: HTTPURLResponse?) {
        self.start = start
        self.duration = duration
        self.request = request
        self.body = body
        self.urlResponse = urlResponse
    }

    /// 请求失败的
    public init(start: TimeInterval,
         duration: TimeInterval,
         request: Request?,
         error: Error?) {
        self.start = start
        self.duration = duration
        self.request = request
        self.error = error
    }

    /// 未请求，就失败的
    public init(error: Error) {
        self.start = 0
        self.duration = 0
        self.error = error
    }

    /// 原始的网络请求，最终发出的网络请求就是这个
    public var request: Request?

    /// 返回的data
    public var body: Data?

    private var _bodyString: String?
    private var _bodyJson: Any?

    /// 原始返回的response对象，如果要查看网络请求的statusCode是不是200，可以在这查看，包括返回的header信息也在这里
    public var urlResponse: HTTPURLResponse?

    /// 原始返回的error，系统的error，可以查看系统的错误信息
    public var error: Error?

    /// 开始请求的时间，毫秒
    public var start: TimeInterval
    /// 请求出结果花费了多少时间
    public var duration: TimeInterval

    /// 从哪个字段开始解析，使用.格式
    public var dataKey: String?
    /// 数据对象，字典或者数组
    private var _data: Any?
    /// 解析的类型
    public var modelType: Decodable.Type?
    /// 解析的model对象，可能是数组或之类的
    public var model: Any?

    // 解密方法
    public static var decryptPublisher: ((Response) -> AnyPublisher<Data?, Never>)?
}

extension Response {
    /// 返回的字符串形式
    public var bodyString: String? {
        mutating get {
            guard let body = body else { return nil }
            if let bodyString = _bodyString {
                return bodyString
            }
            let string = String(data: body, encoding: .utf8)
            _bodyString = string
            return string
        }
    }

    /// 返回的JSON格式
    public var bodyJson: Any? {
        mutating get {
            guard let body = body else { return nil }
            if let bodyJson = _bodyJson {
                return bodyJson
            }
            let json = try? JSONSerialization.jsonObject(with: body)
            _bodyJson = json
            return json
        }
    }

    /// 返回的Data数据
    public var data: Any? {
        mutating get {
            if let data = _data {
                return data
            }
            guard let json = bodyJson else {
                return nil
            }
            guard let key = dataKey,
                  let dict = json as? [String: Any] else {
                return json
            }

            // 如果直接有data，则直接返回
            if let data = dict[key] {
                _data = data
                return data
            }

            if key.contains(".") {
                let arr = key.components(separatedBy: ".")
                var getDict: [String: Any]?
                for k in arr.dropLast() {
                    getDict = dict[k] as? [String: Any]
                    if getDict == nil {
                        return json
                    }
                }
                if let last = arr.last,
                   let data = getDict?[last] {
                    return data
                }
            }

            return nil
        }
    }

    /// 请求是否成功
    public var succeed: Bool {
        if let statusCode = urlResponse?.statusCode {
            return statusCode >= 200 && statusCode < 300
        }
        return false
    }
}

extension Response {
    mutating func decodeModel() throws {
        guard let json = data else { return }
        guard let modelType = self.modelType else { return }

        if JSONSerialization.isValidJSONObject(json) {
            let jsonData = try JSONSerialization.data(withJSONObject: json)
            self.model = try JSONDecoder().decode(modelType.self, from: jsonData)
        }
    }
}

extension Response {
    /// 请求的日志信息，组装成crul命令了，可以复制到cmd中再次调用
    public var description: String {
        guard let request = request else {
            return ""
        }
        var response = self
        var urlStr = request.urlStr
        if let urlResponse = response.urlResponse,
            let responseURL = urlResponse.url?.absoluteString {
            urlStr = responseURL
        }
        let headerFields = request.header
        let method = request.method
        let httpBodyStr = request.paramsString
        var message = ">>>>>>>>>>Start:\(response.start.dateDesc ?? "")"
        message.append("\ncurl -X \(method) \"\(urlStr)\" \\")
        if headerFields != nil {
            for (key, value) in headerFields! {
                message.append("\n -H \"\(key):\(value)\" \\")
            }
        }
        if request.method != .GET,
           httpBodyStr.count > 0 {
            message.append("\n -d \"\(httpBodyStr)\"")
        }
        if message.hasSuffix(" \\") {
            message = "\(message.prefix(message.count - 2))"
        }
        message.append("\n------Response:\(response.duration)ms\n")
        if let urlResponse = response.urlResponse {
            message.append("StatusCode:\(urlResponse.statusCode)\n")
        }
        if let bodyString = response.bodyString {
            message.append("\(bodyString)")
        } else if let error = response.error {
            message.append("\(error)")
        }
        message.append("\nEnd<<<<<<<<<<")
        return message
    }

    /// 打印日志信息，方便查看问题
    public func log() {
        DispatchQueue.global().async {
            print(description)
        }
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
