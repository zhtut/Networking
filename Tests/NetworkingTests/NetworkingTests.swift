import XCTest
@testable import Networking
@testable import Challenge
@testable import WebSocket

final class NetworkingTests: XCTestCase {
    func testRequest() async {
        let response = await Session.shared.send(request: Request(path: "https://www.baidu.com"))
        XCTAssert(response.succeed)
        if response.succeed {
            print("请求成功")
        } else {
            print("请求失败：\(await response.bodyString() ?? "")")
        }
    }
    
    func testChallenge() async {
        // 配置百度的指纹
        ChallengeHandler.shared.pinnings = [
            .init(host: "baidu.com", sha256s: [
                "D8AA2D806C571FB62ED487484190923F9324F0319CFFFEDF7B621F134E6BC100"
            ])
        ]
        Session.shared.session = ChallengeHandler.shared.session
        // 进行请求，如果连上抓包代理，则请求不通过
        let response = await Session.shared.send(request: Request(path: "https://www.baidu.com"))
        XCTAssert(response.succeed)
        if response.succeed {
            print("请求成功")
        } else {
            print("请求失败：\(await response.bodyString() ?? "")")
        }
    }
    
    func testWebSocket() async {
        let url = "ws://124.222.224.186:8800"
        let wb = WebSocket(url: URL(string: url)!)
        let expectation = XCTestExpectation(description: debugDescription)
        wb.open()
        let _ = wb.onOpenPublisher.sink {
            print("连接成功")
            Task {
                try await wb.send(string: "你好")
            }
        }
        let _ = wb.onDataPublisher.sink { data in
            if let str = String(data: data, encoding: .utf8) {
                print("收到消息：\(str)")
                expectation.fulfill()
            }
        }
        await fulfillment(of: [expectation])
    }
}
