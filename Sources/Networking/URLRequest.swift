//
//  File.swift
//  
//
//  Created by zhtg on 2023/4/23.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private let boundary = "wfWiEWrgEFA9A78512weF7106A";

public extension URLRequest {

    static func from(_ request: Request) throws -> URLRequest {
        guard let url = URL(string: request.urlStr) else {
            print("URL生成失败，请检查URL是否正确：\(request.urlStr)")
            throw URLError(.badURL)
        }

        // 创建请求
        var urlRequest = URLRequest(url: url,
                                    cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                    timeoutInterval: request.timeOut)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpShouldHandleCookies = true

        // 集成header
        if let header = request.header {
            for (key, value) in header {
                urlRequest.addValue(value, forHTTPHeaderField: key)
            }
        }

        if let datas = request.datas {
            // 集成参数，FromData
            urlRequest.integrate(datas: datas)
            urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        } else {
            // 集成参数
            urlRequest.integrate(params: request.params)
        }

        return urlRequest
    }

    mutating func integrate(datas: [FormData]) {

        var body = Data()
        for data in datas {
            if let start = "--\(boundary)\r\n".data(using: .utf8) {
                body.append(start)
            }
            if let filename = data.filename {
                let contentDisposition =
                "Content-Disposition: form-data; name=\"\(data.name)\"; filename=\"\(filename)\"\r\n"
                if let data = contentDisposition.data(using: .utf8) {
                    body.append(data)
                }
            } else {
                if let data = "Content-Disposition: form-data; file=\"\(data.name)\"\r\n".data(using: .utf8) {
                    body.append(data)
                }
            }
            if let contentType = data.contentType,
               let data = "Content-Type: \(contentType)\r\n\r\n".data(using: .utf8) {
                body.append(data)
            } else if let line = "\r\n".data(using: .utf8) {
                body.append(line)
            }

            body.append(data.data)
        }

        if let line = "\r\n".data(using: .utf8) {
            body.append(line)
        }

        if let end = "--\(boundary)--\r\n".data(using: .utf8) {
            body.append(end)
        }

        self.httpBody = body
    }

    mutating func integrate(params: Any?) {
        guard let params = params else { return }
        let useBody = (self.httpMethod != HTTPMethod.GET.rawValue)
        if useBody {
            self.httpBody = getHttpBody(params: params)
        } else {
            if let urlString = self.url?.absoluteString {
                let newURLString = getURLString(url: urlString, params: params)
                self.url = URL(string: newURLString)
            }
        }
    }

    func getHttpBody(params: Any?) -> Data? {
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

    func getURLString(url: String, params: Any?) -> String {
        if params is [String: Any] {
            let dic = params as! [String : Any]
            var newURL = url
            if let str = dic.urlQueryStr {
                if url.contains("?") {
                    newURL = "\(newURL)&\(str)"
                } else {
                    newURL = "\(newURL)?\(str)"
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

        var components = URLComponents()
        var queryItems = [URLQueryItem]()
        for (key, value) in self {
            let valueStr: String
            if JSONSerialization.isValidJSONObject(value),
               let data = try? JSONSerialization.data(withJSONObject: value, options: .init(rawValue: 0)),
               let str = String(data: data, encoding: .utf8) {
                valueStr = str
            } else {
                valueStr = "\(value)"
            }
            queryItems.append(.init(name: "\(key)", value: valueStr))
        }
        components.queryItems = queryItems
        if let query = components.query {
            return query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        }
        return nil
    }
}
