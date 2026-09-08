import XCTest
@testable import DevNotch

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("Handler is not set")
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class DeepSeekClientTests: XCTestCase {
    private var client: DeepSeekClient!
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        client = DeepSeekClient(session: session)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        session = nil
        client = nil
        super.tearDown()
    }

    func testFetchBalanceSuccess() async throws {
        let json = """
        {
          "is_available": true,
          "balance_infos": [
            {
              "currency": "CNY",
              "total_balance": "0.73",
              "granted_balance": "0.00",
              "topped_up_balance": "0.73"
            }
          ]
        }
        """

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test_key")
            XCTAssertEqual(request.httpMethod, "GET")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, json.data(using: .utf8)!)
        }

        let result = try await client.fetchBalance(apiKey: "test_key")
        XCTAssertTrue(result.isAvailable)
        XCTAssertEqual(result.balanceInfos[0].totalDecimal, Decimal(string: "0.73"))
    }

    func test401UnauthorizedError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        do {
            _ = try await client.fetchBalance(apiKey: "bad_key")
            XCTFail("Should throw unauthorized error")
        } catch let err as DeepSeekAPIError {
            XCTAssertEqual(err, .unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test402InsufficientBalanceError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 402, httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        do {
            _ = try await client.fetchBalance(apiKey: "key")
            XCTFail("Should throw insufficientBalance")
        } catch let err as DeepSeekAPIError {
            XCTAssertEqual(err, .insufficientBalance)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test429RateLimitedError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        do {
            _ = try await client.fetchBalance(apiKey: "key")
            XCTFail("Should throw rateLimited")
        } catch let err as DeepSeekAPIError {
            XCTAssertEqual(err, .rateLimited)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test500ServerUnavailableError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 502, httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        do {
            _ = try await client.fetchBalance(apiKey: "key")
            XCTFail("Should throw serverUnavailable")
        } catch let err as DeepSeekAPIError {
            XCTAssertEqual(err, .serverUnavailable(statusCode: 502))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
