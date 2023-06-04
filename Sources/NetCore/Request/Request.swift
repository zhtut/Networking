//
//  Request.swift
//  GoodMood
//
//  Created by zhtg on 2023/4/23.
//  Copyright © 2023 Buildyou Tech. All rights reserved.
//

import Foundation
import Combine
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
        idStr += urlStr
        idStr += method.rawValue
        idStr += jsonToString(json: header) ?? ""
        idStr += jsonToString(json: params) ?? ""
        return idStr
    }
}

public struct Request {

    func jsonToString(json: Any?) -> String? {
        if let json,
           let data = try? JSONSerialization.data(withJSONObject: json, options: .sortedKeys),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return nil
    }

    public static var baseURL = ""

    public var urlStr: String {
        if path.hasPrefix("http") {
            return path
        }
        return Request.baseURL + path
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
    public var useCache: Bool = false

    public init(path: String,
                method: HTTPMethod = .GET,
                params: Any? = nil,
                header: [String : String]? = nil,
                timeOut: TimeInterval = kDefaultTimeOut,
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

    var urlRequestPublisher: AnyPublisher<URLRequest, Error> {
        return Future { promise in
            DispatchQueue.global().async {
                var urlRequest: URLRequest
                do {
                    urlRequest = try URLRequest.from(self)
                    promise(.success(urlRequest))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
