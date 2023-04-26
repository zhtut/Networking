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

        var startTime: TimeInterval = 0
        // 创建Request的publisher，创建完成后会回调给我们
        return request.urlRequestPublisher
            .subscribe(on: DispatchQueue.global())
            .print("Network-->:")
            .handleEvents(receiveSubscription: { subscription in
                startTime = Date().timeIntervalSince1970 * 1000.0
            })
            // 这里数据是URLRequst, 错误是URLError，map会把数据进行转换，这里转换成另一个publisher
            .map { urlRequest -> AnyPublisher<Response, Never> in
                return URLSession.shared.dataTaskPublisher(for: urlRequest)
                    .map { out in
                        // 转换output为Response对象
                        let duration = Date().timeIntervalSince1970 * 1000.0 - startTime
                        var res = Response(start: startTime,
                                           duration: duration,
                                           request: request,
                                           body: out.data,
                                           urlResponse: out.response as? HTTPURLResponse)
                        // 如果配置有解密方法，则优先用解密方法解密一下
                        if let decrypt = Response.decryptPublisher {
                            _ = decrypt(res)
                                .sink { body in
                                    res.body = body
                                }
                        }
                        // 解析Model
                        res.dataKey = request.dataKey
                        res.modelType = request.modelType
                        if res.succeed, let _ = request.modelType {
                            try? res.decodeModel()
                        }
                        if request.printLog {
                            res.log()
                        }
                        return res
                    }
                    .subscribe(on: DispatchQueue.global())
                    .catch { error in
                        // 转换error为Response对象
                        let duration = Date().timeIntervalSince1970 * 1000.0 - startTime
                        let res = Response(start: startTime,
                                           duration: duration,
                                           request: request,
                                           error: error)
                        return Just(res)
                    }
                    .eraseToAnyPublisher()
            }
            // 转换成publisher之后，需要调用sink或者assign或者这个switchToLatest来再转换成数据
            // 转换数据有个要求，错误类型必须为Never，所以下面把上面URLRequest的错误捕获住，这样就能转换了
            .switchToLatest()
            .catch { error in
                // 转换error为Response对象，这里的错误还是生成Request的错误
                let duration = Date().timeIntervalSince1970 * 1000.0 - startTime
                let res = Response(error: error)
                return Just(res)
            }
            // 回调放到主线程，防止子线程调用UI
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
}
