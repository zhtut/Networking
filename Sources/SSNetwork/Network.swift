//
//  CombineNetwork.swift
//  GoodMood
//
//  Created by zhtg on 2023/4/22.
//  Copyright © 2023 Buildyou Tech. All rights reserved.
//

import Foundation
import Combine
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum Network {

    /// 发送一个网络请求
    public static func publisherWith(request: Request) -> AnyPublisher<Response, Never> {

        var urlRequest: URLRequest

        do {
            urlRequest = try URLRequest.from(request)
        } catch {
            return Just(Response(error: error))
                .eraseToAnyPublisher()
        }

        // 开始请求
        let startTime = Date().timeIntervalSince1970 * 1000.0
        let publisher = URLSession.shared.dataTaskPublisher(for: urlRequest)
            .map { out in
                // 转换output为Response对象
                let duration = Date().timeIntervalSince1970 * 1000.0 - startTime
                var res = Response(start: startTime,
                                   duration: duration,
                                   request: request,
                                   body: out.data,
                                   urlResponse: out.response as? HTTPURLResponse)
                // 解析Model
                res.dataKey = request.dataKey
                res.modelType = request.modelType
                if res.succeed, let _ = request.modelType {
                    try? res.decodeModel()
                }

                return res
            }
            .catch { error in
                // 转换error为Response对象
                let duration = Date().timeIntervalSince1970 * 1000.0 - startTime
                let res = Response(start: startTime,
                                   duration: duration,
                                   request: request,
                                   error: error)
                return Just(res)
            }

        if request.printLog {
            return publisher
                .print("Network-->:")
                .receive(on: RunLoop.main)
                .eraseToAnyPublisher()
        } else {
            return publisher
                .receive(on: RunLoop.main)
                .eraseToAnyPublisher()
        }
    }
}
