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

public protocol SSResponsive: CustomStringConvertible {
    
    init()
    
    init(start: TimeInterval,
         request: URLRequest?,
         body: Data?,
         urlResponse: HTTPURLResponse?,
         error: Error?,
         duration: TimeInterval)
    
    /// 原始的网络请求，最终发出的网络请求就是这个
    var request: URLRequest? { get set }
    
    /// 返回的data
    var body: Data? { get set }
    
    /// 原始返回的response对象，如果要查看网络请求的statusCode是不是200，可以在这查看，包括返回的header信息也在这里
    var urlResponse: HTTPURLResponse? { get set }
    
    /// 原始返回的error，系统的error，可以查看系统的错误信息
    var error: Error? { get set }
    
    /// 开始请求的时间，毫秒
    var start: TimeInterval { get set }
    /// 请求出结果花费了多少时间
    var duration: TimeInterval { get set }
    
    /// 从哪个字段开始解析，使用.格式
    var dataKey: String? { get set }
    /// 解析的类型
    var modelType: Decodable.Type? { get set }
    /// 解析的model对象，可能是数组或之类的
    var model: Decodable? { get set }
}

private var kSSResponsiveRequest = "kSSResponsiveRequest"
private var kSSResponsiveBody = "kSSResponsiveBody"
private var kSSResponsiveURLResponse = "kSSResponsiveURLResponse"
private var kSSResponsiveError = "kSSResponsiveError"
private var kSSResponsiveStart = "kSSResponsiveStart"
private var kSSResponsiveDuration = "kSSResponsiveDuration"
private var kSSResponsiveDataKey = "kSSResponsiveDataKey"
private var kSSResponsiveModelType = "kSSResponsiveModelType"
private var kSSResponsiveModel = "kSSResponsiveModel"

/// 默认实现
extension SSResponsive {
    init(start: TimeInterval,
         request: URLRequest?,
         body: Data?,
         urlResponse: HTTPURLResponse?,
         error: Error?,
         duration: TimeInterval) {
        self.init()
        self.start = start
        self.request = request
        self.body = body
        self.urlResponse = urlResponse
        self.error = error
        self.duration = duration
    }
    
    /// 原始的网络请求，最终发出的网络请求就是这个
    var request: URLRequest? {
        set {
            objc_setAssociatedObject(self, &kSSResponsiveRequest, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            objc_getAssociatedObject(self, &kSSResponsiveRequest) as? URLRequest
        }
    }
    
    /// 返回的data
    var body: Data? {
        set {
            objc_setAssociatedObject(self, &kSSResponsiveBody, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            objc_getAssociatedObject(self, &kSSResponsiveBody) as? Data
        }
    }
    
    /// 原始返回的response对象，如果要查看网络请求的statusCode是不是200，可以在这查看，包括返回的header信息也在这里
    var urlResponse: HTTPURLResponse? {
        set {
            objc_setAssociatedObject(self, &kSSResponsiveURLResponse, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            objc_getAssociatedObject(self, &kSSResponsiveURLResponse) as? HTTPURLResponse
        }
    }
    
    /// 原始返回的error，系统的error，可以查看系统的错误信息
    var error: Error? {
        set {
            objc_setAssociatedObject(self, &kSSResponsiveError, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            objc_getAssociatedObject(self, &kSSResponsiveError) as? Error
        }
    }
    
    /// 开始请求的时间，毫秒
    var start: TimeInterval {
        set {
            objc_setAssociatedObject(self, &kSSResponsiveStart, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            objc_getAssociatedObject(self, &kSSResponsiveStart) as? TimeInterval ?? 0
        }
    }
    /// 请求出结果花费了多少时间
    var duration: TimeInterval {
        set {
            objc_setAssociatedObject(self, &kSSResponsiveDuration, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            objc_getAssociatedObject(self, &kSSResponsiveDuration) as? TimeInterval ?? 0
        }
    }
    
    /// 从哪个字段开始解析，使用.格式
    var dataKey: String? {
        set {
            objc_setAssociatedObject(self, &kSSResponsiveDataKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            objc_getAssociatedObject(self, &kSSResponsiveDataKey) as? String
        }
    }
    /// 解析的类型
    var modelType: Decodable.Type? {
        set {
            objc_setAssociatedObject(self, &kSSResponsiveModelType, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            objc_getAssociatedObject(self, &kSSResponsiveModelType) as? Decodable.Type
        }
    }
    /// 解析的model对象，可能是数组或之类的
    var model: Decodable? {
        set {
            objc_setAssociatedObject(self, &kSSResponsiveModel, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            objc_getAssociatedObject(self, &kSSResponsiveModel) as? Decodable
        }
    }
}

extension SSResponsive {
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
    
    /// 请求是否成功
    public var succeed: Bool {
        return urlResponse?.statusCode == 200
    }
}

extension SSResponsive {
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

extension SSResponsive {
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
        message.append("\n------SSResponsive:\(response.duration)ms\n")
        
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
