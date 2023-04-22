import XCTest
@testable import SSNetwork

final class SSNetworkTests: XCTestCase {
    func testRequest() {
        let expectation = XCTestExpectation(description: debugDescription)
        Network.publisherWith(request: Request(path: "https://www.baidu.com"))
            .sink { response in
                var response = response
                if response.succeed {
                    print("请求成功")
                } else {
                    print("请求失败：\(response.bodyString ?? "")")
                }
                expectation.fulfill()
            }
            .store(in: &subscriptionSet)
        wait(for: [expectation], timeout: 60)
    }
}
