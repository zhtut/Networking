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

/// 请求方法
public enum HTTPMethod: String {
    case GET
    case POST
    case DELETE
    case PUT
    case PATCH
}

open class FormData {

    open var name: String
    open var data: Data
    open var contentType: String?
    open var filename: String?

    public init(name: String, data: Data, contentType: String? = nil, filename: String? = nil) {
        self.name = name
        self.data = data
        self.contentType = contentType
        self.filename = filename
    }
}

extension Request: Identifiable, Equatable {

    public static func == (lhs: Request, rhs: Request) -> Bool {
        return lhs.id == rhs.id
    }

    public var id: String {
        var idStr = ""
        idStr += urlString ?? ""
        idStr += method.rawValue
        idStr += jsonToString(json: header) ?? ""
        idStr += jsonToString(json: params) ?? ""
        return idStr
    }
}

public struct Request {

    public var urlString: String?
    public var path: String
    public var method: HTTPMethod
    public var params: Any?
    public var header: [String: String]?
    public var timeOut: TimeInterval = 10
    public var printLog: Bool
    public var dataKey: String?
    public var modelType: Decodable.Type?
    public var datas: [FormData]?

    public init(path: String,
                method: HTTPMethod = .GET,
                params: Any? = nil,
                header: [String : String]? = nil,
                timeOut: TimeInterval = Session.shared.timeOut,
                printLog: Bool = true,
                dataKey: String? = nil,
                modelType: Decodable.Type? = nil,
                datas: [FormData]? = nil) {
        self.path = path
        self.method = method
        self.params = params
        self.header = header
        self.timeOut = timeOut
        self.printLog = printLog
        self.dataKey = dataKey
        self.modelType = modelType
        self.datas = datas
    }
}

public extension Request {
    
    func jsonToString(json: Any?) -> String? {
        if let json,
           let data = try? JSONSerialization.data(withJSONObject: json, options: .sortedKeys),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return nil
    }
    
    mutating func urlString(_ baseURL: String) -> String {
        var string: String
        if path.hasPrefix("http") {
            string = path
        } else {
            string = (baseURL as NSString).appendingPathComponent(path)
        }
        self.urlString = string
        return string
    }
    
    /// 请求体描述
    var paramsString: String {
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
