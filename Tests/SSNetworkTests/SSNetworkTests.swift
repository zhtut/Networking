import XCTest
@testable import SSNetwork

final class SSNetworkTests: XCTestCase {
    
    func testRequest() async {
        let _ = await SSNetwork.sendRequest(urlStr: "https://www.baidu.com", printLog: true)
    }
}
