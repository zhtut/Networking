//
//  Request.swift
//  GoodMood
//
//  Created by zhtg on 2023/4/23.
//  Copyright © 2023 Buildyou Tech. All rights reserved.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public let kDefaultTimeOut: TimeInterval = 10.0
public let kDefaultResourceTimeOut: TimeInterval = 60.0

/// 请求方法
public enum HTTPMethod: String {
    case GET
    case POST
    case DELETE
    case PUT
    case PATCH
}

public class FormData {

    var name: String
    var data: Data
    var contentType: String?
    var filename: String?

    init(name: String, data: Data, contentType: String? = nil, filename: String? = nil) {
        self.name = name
        self.data = data
        self.contentType = contentType
        self.filename = filename
    }
}

public struct Request {
    public static var baseURL = ""

    public var urlStr: String {
        Request.baseURL + path
    }

    public var path: String
    public var method: HTTPMethod = .GET
    public var params: Any? = nil
    public var header: [String: String]? = nil
    public var timeOut: TimeInterval = kDefaultTimeOut
    public var printLog: Bool = true
    public var dataKey: String? = nil
    public var modelType: Decodable.Type? = nil
    public var datas: [FormData]?

    /// 请求体描述
    public var paramsString: String {
        if let params {
            if let str = params as? String {
                return str
            } else if let data = params as? Data, let str = String(data: data, encoding: .utf8) {
                return str
            } else if JSONSerialization.isValidJSONObject(params),
                      let data = try? JSONSerialization.data(withJSONObject: params),
                      let str = String(data: data, encoding: .utf8) {
                return str
            }
        }
        return ""
    }
}
