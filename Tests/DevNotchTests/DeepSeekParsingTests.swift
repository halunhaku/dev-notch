import XCTest
@testable import DevNotch

final class DeepSeekParsingTests: XCTestCase {
    func testValidCNYBalanceResponse() throws {
        let json = """
        {
          "is_available": true,
          "balance_infos": [
            {
              "currency": "CNY",
              "total_balance": "35.72",
              "granted_balance": "5.72",
              "topped_up_balance": "30.00"
            }
          ]
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(DeepSeekBalanceResponse.self, from: data)

        XCTAssertTrue(response.isAvailable)
        XCTAssertEqual(response.balanceInfos.count, 1)

        let info = response.balanceInfos[0]
        XCTAssertEqual(info.currency, "CNY")
        XCTAssertEqual(info.totalDecimal, Decimal(string: "35.72"))
        XCTAssertEqual(info.grantedDecimal, Decimal(string: "5.72"))
        XCTAssertEqual(info.toppedUpDecimal, Decimal(string: "30.00"))

        let balance = AIBalance(
            currency: info.currency,
            total: info.totalDecimal,
            granted: info.grantedDecimal,
            toppedUp: info.toppedUpDecimal,
            isAvailable: response.isAvailable
        )

        XCTAssertEqual(balance.formattedTotal, "¥35.72")
        XCTAssertEqual(balance.formattedGranted, "¥5.72")
        XCTAssertEqual(balance.formattedToppedUp, "¥30.00")
        XCTAssertTrue(balance.isAvailable)
    }

    func testUSDBalanceFormatting() throws {
        let json = """
        {
          "is_available": true,
          "balance_infos": [
            {
              "currency": "USD",
              "total_balance": "12.43",
              "granted_balance": "0.00",
              "topped_up_balance": "12.43"
            }
          ]
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(DeepSeekBalanceResponse.self, from: data)
        let info = response.balanceInfos[0]

        let balance = AIBalance(
            currency: info.currency,
            total: info.totalDecimal,
            granted: info.grantedDecimal,
            toppedUp: info.toppedUpDecimal,
            isAvailable: response.isAvailable
        )

        XCTAssertEqual(balance.formattedTotal, "$12.43")
        XCTAssertEqual(balance.currencySymbol, "$")
    }

    func testMultipleBalanceInfos() throws {
        let json = """
        {
          "is_available": false,
          "balance_infos": [
            {
              "currency": "CNY",
              "total_balance": "0.00",
              "granted_balance": "0.00",
              "topped_up_balance": "0.00"
            },
            {
              "currency": "USD",
              "total_balance": "4.93",
              "granted_balance": "1.00",
              "topped_up_balance": "3.93"
            }
          ]
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(DeepSeekBalanceResponse.self, from: data)

        XCTAssertFalse(response.isAvailable)
        XCTAssertEqual(response.balanceInfos.count, 2)
        XCTAssertEqual(response.balanceInfos[0].currency, "CNY")
        XCTAssertEqual(response.balanceInfos[1].currency, "USD")
    }

    func testDecimalPrecisionIntegrity() {
        // Test that financial amounts avoid IEEE floating-point errors (e.g. 0.1 + 0.2 != 0.30000000000000004)
        let total = Decimal(string: "35.72")!
        let toppedUp = Decimal(string: "30.00")!
        let granted = Decimal(string: "5.72")!

        XCTAssertEqual(toppedUp + granted, total)

        let balance = AIBalance(currency: "CNY", total: total, granted: granted, toppedUp: toppedUp)
        XCTAssertEqual(balance.formattedTotal, "¥35.72")
    }

    func testUnknownFutureFieldsIgnored() throws {
        let json = """
        {
          "is_available": true,
          "balance_infos": [
            {
              "currency": "CNY",
              "total_balance": "0.73",
              "granted_balance": "0.00",
              "topped_up_balance": "0.73",
              "future_billing_tier": "tier_3"
            }
          ],
          "organization_quota": { "unlimited": true }
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(DeepSeekBalanceResponse.self, from: data)
        XCTAssertEqual(response.balanceInfos[0].totalDecimal, Decimal(string: "0.73"))
    }

    func testMalformedBalanceThrows() {
        let invalid = "{ invalid json content }".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(DeepSeekBalanceResponse.self, from: invalid))
    }
}
