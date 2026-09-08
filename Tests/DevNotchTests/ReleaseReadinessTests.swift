import XCTest
@testable import DevNotch

final class ReleaseReadinessTests: XCTestCase {
    func testNoHardcodedDeveloperHomePathsInProductSources() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let productRoot = projectRoot.appendingPathComponent("DevNotch")
        let forbiddenHome = ["", "Users", "halunhaku"].joined(separator: "/")

        let files = try sourceFiles(below: productRoot)
        for file in files {
            let contents = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(contents.contains(forbiddenHome), "Developer home path found in \(file.path)")
            XCTAssertFalse(contents.contains("Derived" + "Data"), "Derived data path found in \(file.path)")
        }
    }

    func testBundledHelperPathsUseContentsHelpers() {
        let bundle = URL(fileURLWithPath: "/Applications/Dev Notch.app")
        XCTAssertEqual(
            BundledHelperLocator.url(for: .claude, bundleURL: bundle).path,
            "/Applications/Dev Notch.app/Contents/Helpers/DevNotchClaudeBridge"
        )
        XCTAssertEqual(
            BundledHelperLocator.url(for: .activity, bundleURL: bundle).path,
            "/Applications/Dev Notch.app/Contents/Helpers/DevNotchActivityBridge"
        )
    }

    func testStableApplicationLocations() {
        let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
        XCTAssertTrue(AppInstallation.isStable(
            bundleURL: URL(fileURLWithPath: "/Applications/DevNotch.app"),
            homeDirectoryURL: home
        ))
        XCTAssertTrue(AppInstallation.isStable(
            bundleURL: URL(fileURLWithPath: "/Users/tester/Applications/DevNotch.app"),
            homeDirectoryURL: home
        ))
    }

    func testUnstableAndTranslocatedLocationsAreRejected() {
        let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
        let unstableURLs = [
            URL(fileURLWithPath: "/Volumes/DevNotch/DevNotch.app"),
            URL(fileURLWithPath: "/private/var/folders/AppTranslocation/DevNotch.app"),
            URL(fileURLWithPath: "/Users/tester/Downloads/DevNotch.app")
        ]

        for url in unstableURLs {
            XCTAssertFalse(AppInstallation.isStable(bundleURL: url, homeDirectoryURL: home))
            XCTAssertThrowsError(try AppInstallation.requireStable(bundleURL: url, homeDirectoryURL: home))
        }
    }

    func testBundleVersionParsing() {
        let info: [String: Any] = [
            "CFBundleShortVersionString": "0.9.0",
            "CFBundleVersion": "1"
        ]
        XCTAssertEqual(BundleVersion.marketingVersion(infoDictionary: info), "0.9.0")
        XCTAssertEqual(BundleVersion.buildNumber(infoDictionary: info), "1")
        XCTAssertNil(BundleVersion.marketingVersion(infoDictionary: [:]))
        XCTAssertNil(BundleVersion.buildNumber(infoDictionary: ["CFBundleVersion": " "]))
    }

    func testReleaseProviderRegistryRegression() {
        let registry = AIProviderRegistry.makeDefaultRegistry()
        XCTAssertEqual(
            Set(registry.allProviders.map(\.id)),
            Set([.codex, .claude, .antigravity, .openCodeGo, .deepseek])
        )
    }

    func testNoCredentialOrFixtureResourceIsBundled() throws {
        let forbiddenNames = ["credential", "credentials", "api_key", "apikey", "fixture", "mock"]
        let resourceURLs = Bundle.main.resourceURL.map { try? sourceFiles(below: $0) } ?? nil
        for url in resourceURLs ?? [] {
            let name = url.lastPathComponent.lowercased()
            XCTAssertFalse(forbiddenNames.contains(where: name.contains), "Forbidden Release resource: \(name)")
        }
    }

    private func sourceFiles(below root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return enumerator.compactMap { item in
            guard let url = item as? URL,
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                return nil
            }
            return url
        }
    }

    func testHookCommandParserExtractsPathsWithSpaces() {
        XCTAssertEqual(
            HookCommandParser.executablePath(in: "'/Applications/Dev Notch.app/Contents/Helpers/B' 'Stop'"),
            "/Applications/Dev Notch.app/Contents/Helpers/B"
        )
        XCTAssertEqual(
            HookCommandParser.executablePath(in: "\"/Users/halunhaku/Library/Application Support/X\" antigravity Stop"),
            "/Users/halunhaku/Library/Application Support/X"
        )
        XCTAssertEqual(
            HookCommandParser.executablePath(in: "/usr/bin/true"),
            "/usr/bin/true"
        )
        XCTAssertNil(HookCommandParser.executablePath(in: ""))
    }
}
