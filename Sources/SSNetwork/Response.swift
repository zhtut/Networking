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

public struct Response {
    
    /// 原始的网络请求，最终发出的网络请求就是这个
    public var request: URLRequest?
    
    /// 返回的data
    public var body: Data?
    
    /// 返回的字符串形式
    public var bodyString: String? {
        guard let body = body else { return nil }
        let string = String(data: body, encoding: .utf8)
        return string ?? ""
    }
    
    /// 返回的JSON格式
    public var bodyJson: Any? {
        guard let body = body else { return nil }
        guard JSONSerialization.isValidJSONObject(body) else { return nil }
        let json = try? JSONSerialization.jsonObject(with: body)
        return json
    }
    
    /// 原始返回的response对象，如果要查看网络请求的statusCode是不是200，可以在这查看，包括返回的header信息也在这里
    public var urlResponse: HTTPURLResponse?
    
    /// 原始返回的error，系统的error，可以查看系统的错误信息
    public var error: Error?
    
    /// 请求是否成功
    public var succeed: Bool {
        return urlResponse?.statusCode == 200
    }
    
    /// 开始请求的时间，毫秒
    public var start: TimeInterval
    /// 请求出结果花费了多少时间
    public var duration: TimeInterval
    
    /// 从哪个字段开始解析，使用.格式
    public var dataKey: String?
    /// 解析的类型
    public var modelType: Decodable.Type?
    /// 解析的model对象，可能是数组或之类的
    public var model: Decodable?
}

extension Response {
    mutating func decodeModel(dataKey: String?, modelType: Decodable.Type) async {
        self.dataKey = dataKey
        self.modelType = modelType
        
        var json: Any?
        if let dataKey = dataKey, let dict = bodyJson as? [String: Any] {
            json = dict[dataKey]
        } else {
            json = bodyJson
        }
        
        guard let json = json else { return }
        
        if let arr = json as? [Any] {
            var models = [Any]()
            for info in arr {
                if let dict = info as? [String: Any],
                   let dictData = try? JSONSerialization.data(withJSONObject: dict),
                   let model = try? JSONDecoder().decode(modelType.self, from: dictData) {
                    models.append(model)
                }
            }
            self.model = models as? any Decodable
        } else if json is [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: json) {
            self.model = try? JSONDecoder().decode(modelType.self, from: jsonData)
        }
    }
}

extension Response: CustomStringConvertible {
    /// 请求的日志信息，组装成crul命令了，可以复制到cmd中再次调用
    public var description: String {
        guard let request = request else {
            return ""
        }
        let response = self
        let urlStr = request.url?.absoluteString ?? ""
        let headerFields = request.allHTTPHeaderFields
        let method = request.httpMethod ?? ""
        var httpBodyStr: String?
        if request.httpBody != nil {
            httpBodyStr = String(data: request.httpBody!, encoding: .utf8)
        }
        var message = ">>>>>>>>>>Start:\(response.start.dateDesc ?? "")"
        message.append("\ncurl -X \(method) \"\(urlStr)\" \\")
        if headerFields != nil {
            for (key, value) in headerFields! {
                message.append("\n -H \"\(key):\(value)\" \\")
            }
        }
        if httpBodyStr != nil {
            message.append("\n -d \"\(httpBodyStr!)\"")
        }
        if message.hasSuffix(" \\") {
            message = "\(message.prefix(message.count - 2))"
        }
        message.append("\n------Response:\(response.duration)ms\n")
        
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
        print(description)
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
