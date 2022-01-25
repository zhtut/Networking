//
//  File.swift
//
//
//  Created by shutut on 2021/9/25.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public typealias SSResponseHandler = (SSResponse) -> Void

/// 网络请求的结果
open class SSResponse: NSObject {
    
    /// 子类初始化父类使用，比较方便
    /// - Parameter response: 父类response
    public convenience init(response: SSResponse) {
        self.init()
        self.originData = response.originData
        self.originResponse = response.originResponse
        self.originRequest = response.originRequest
        self.originError = response.originError
        self.originJson = response.originJson
        self.originString = response.originString
        self.start = response.start
        self.duration = response.duration
    }
    
    /// 创建一个reponse实例
    /// - Parameters:
    ///   - data: 返回的数据
    ///   - response: 返回的response对象
    ///   - error: 返回的error
    /// - Returns: 返回创建好的SSResponse实例
    open class func responseWith(data: Data?, response: URLResponse?, error: Error?) -> SSResponse {
        let obj = SSResponse()
        obj.originData = data
        obj.originResponse = response
        obj.originError = error
        return obj
    }
    
    /// 原始data
    open var originData: Data? {
        didSet {
            if originData != nil {
                originJson = try? JSONSerialization.jsonObject(with: originData!, options: .mutableContainers)
                originString = String(data: originData!, encoding: .utf8)
            }
        }
    }
    
    /// 原始的网络请求，最终发出的网络请求就是这个
    open var originRequest: URLRequest?
    /// 原始json，有可能为空
    open var originJson: Any?
    /// 原始字符串
    open var originString: String?
    /// 原始返回的response对象，如果要查看网络请求的statusCode是不是200，可以在这查看，包括返回的header信息也在这里
    open var originResponse: URLResponse?
    /// 原始返回的error，系统的error，可以查看系统的错误信息
    open var originError: Error?
    /// 获取服务器返回成功
    open var reachSucceed: Bool {
        return originData != nil
    }
    open var fetchSucceed: Bool {
        if let originResponse = originResponse as? HTTPURLResponse {
            return originResponse.statusCode == 200
        }
        return false
    }
    /// 是否系统错误或者网络错误，未到达服务器
    open var systemErrMsg: String? {
        if let originError = originError {
            return originError.localizedDescription
        }
        return originString
    }
    
    /// 开始请求的时间，毫秒
    open var start: TimeInterval?
    /// 请求回来花费了多少时间
    open var duration: TimeInterval?
    
    /// 请求的日志信息，组装成crul命令了，可以复制到cmd中再次调用
    open override var description: String {
        let response = self
        if let request = self.originRequest {
            let urlStr = request.url?.absoluteString ?? ""
            let headerFields = request.allHTTPHeaderFields
            let method = request.httpMethod ?? ""
            var httpBodyStr: String?
            if request.httpBody != nil {
                httpBodyStr = String(data: request.httpBody!, encoding: .utf8)
            }
            var message = ">>>>>>>>>>Start:\(response.start?.dateDesc ?? "")"
            message.append("\ncurl -X \(method) \"\(urlStr)\"")
            if headerFields != nil {
                for (key, value) in headerFields! {
                    message.append(" -H \"\(key):\(value)\"")
                }
            }
            if httpBodyStr != nil {
                message.append(" -d \"\(httpBodyStr!)\"")
            }
            message.append("\n------Response:\(response.duration ?? 0.0)ms\n")
            if response.originString != nil {
                message.append("\(response.originString!)")
            } else if response.originError != nil {
                message.append("\(response.originError!)")
            }
            message.append("\n<<<<<<<<<<End<<<<<<<<<<")
            return message
        }
        return super.description
    }
    
    /// 打印日志信息，方便查看问题
    open func logResponse() {
        print(description)
    }
}
