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

public enum NetworkError: Error {
    case urlInvalid(_ invalidURL: String)
    case systemError(_ error: Error)
    case serverError(_ code: Int, _ reason: String)
}

public enum Network {

    /// 发送一个网络请求
    public static func publisherWith(request: Request) -> AnyPublisher<Response, Never> {

        var urlRequest: URLRequest

        do {
            urlRequest = try URLRequest.from(request)
        } catch {
//            return Fail(error: Response(error: error))
            return Just(Response(error: error))
                .eraseToAnyPublisher()
        }

        // 开始请求
        let startTime = Date().timeIntervalSince1970 * 1000.0
        let publisher = URLSession.shared.dataTaskPublisher(for: urlRequest)
            .subscribe(on: DispatchQueue.global())
            .receive(on: RunLoop.main)
            .handleEvents { subscription in
                print("收到subscription")
            } receiveOutput: { _ in
                print("收到输出")
            } receiveCompletion: { completion in
                print("输出完成")
            } receiveCancel: {
                print("收到取消")
            } receiveRequest: { demand in
                print("收到请求")
            }
            .print("Network-->:")
            .map ({ out in
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
            })
            .catch({ error in
                let duration = Date().timeIntervalSince1970 * 1000.0 - startTime
                let res = Response(start: startTime,
                                   duration: duration,
                                   request: request,
                                   error: error)
                return Just(res)
            })
            .eraseToAnyPublisher()

        return publisher
    }
}
