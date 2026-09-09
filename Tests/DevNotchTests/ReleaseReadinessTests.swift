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
            guard file.pathExtension != "icns" else { continue }
            guard let contents = try? String(contentsOf: file, encoding: .utf8) else { continue }
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
        XCTAssertEqual(
            BundledHelperLocator.url(for: .nowPlaying, bundleURL: bundle).path,
            "/Applications/Dev Notch.app/Contents/Helpers/DevNotchNowPlaying"
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
            Set([.codex, .claude, .antigravity, .openCodeGo, .deepseek, .grok])
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

    func testGitHubReleaseModeAndArtifactNaming() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scriptURL = projectRoot.appendingPathComponent("script/release.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(script.contains("MODE=\"${1:-github}\""), "Default release mode should be github")
        XCTAssertTrue(script.contains("VERSION=\"1.1.0\""), "Release version should be 1.1.0")
        XCTAssertTrue(script.contains("GITHUB_DMG=\"$DIST_ROOT/DevNotch-${VERSION}.dmg\""), "GitHub DMG naming should be DevNotch-1.1.0.dmg")
        XCTAssertTrue(script.contains("shasum -a 256 \"$GITHUB_DMG\" >\"$GITHUB_DMG.sha256\""), "Checksum should match artifact naming")
    }

    func testReleaseScriptDoesNotRequireDeveloperIDOrNotaryInGitHubMode() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scriptURL = projectRoot.appendingPathComponent("script/release.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(script.contains("if [[ \"$MODE\" == \"github\" ]]; then"), "Script must branch specifically for github mode")
        XCTAssertTrue(script.contains("create_dmg \"$EXPORTED_APP\" \"$GITHUB_DMG\""), "GitHub mode must create GitHub DMG directly")
        XCTAssertTrue(script.contains("if [[ \"$MODE\" == \"github\" || \"$MODE\" == \"local\" ]]; then"), "Archive and export should support github mode without Developer ID")
    }

    func testReadmeContainsSecurityOpeningInstructions() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let readmeURL = projectRoot.appendingPathComponent("README.md")
        let readme = try String(contentsOf: readmeURL, encoding: .utf8)

        XCTAssertTrue(readme.contains("DevNotch-1.1.0.dmg"), "README must reference DevNotch-1.1.0.dmg")
        XCTAssertTrue(readme.contains("System Settings"), "README must explain System Settings flow")
        XCTAssertTrue(readme.contains("Privacy & Security"), "README must explain Privacy & Security")
        XCTAssertTrue(readme.contains("Open Anyway"), "README must explain Open Anyway")
        XCTAssertFalse(readme.contains("The public distribution artifact must be Developer ID signed"), "README should not claim public artifact must be Developer ID signed")
    }

    func testHelperSigningConsistencyConfiguration() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectYmlURL = projectRoot.appendingPathComponent("project.yml")
        let projectYml = try String(contentsOf: projectYmlURL, encoding: .utf8)

        XCTAssertTrue(projectYml.contains("MARKETING_VERSION: \"1.1.0\""))
        XCTAssertTrue(projectYml.contains("DevNotchClaudeBridge:"))
        XCTAssertTrue(projectYml.contains("DevNotchActivityBridge:"))
        XCTAssertTrue(projectYml.contains("DevNotchNowPlaying:"))
        XCTAssertTrue(projectYml.contains("ENABLE_HARDENED_RUNTIME: YES"))
    }

    func testInstallTextAndReleaseArtifactsDocs() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let installURL = projectRoot.appendingPathComponent("INSTALL.txt")
        let installText = try String(contentsOf: installURL, encoding: .utf8)
        XCTAssertTrue(installText.contains("Open Anyway"))
        XCTAssertTrue(installText.contains("Privacy & Security"))

        let notesURL = projectRoot.appendingPathComponent("GITHUB_RELEASE_NOTES.md")
        let notesText = try String(contentsOf: notesURL, encoding: .utf8)
        XCTAssertTrue(notesText.contains("Dev Notch 1.1.0"))
        XCTAssertTrue(notesText.contains("Open Anyway"))

        let checklistURL = projectRoot.appendingPathComponent("RELEASE_CHECKLIST.md")
        let checklistText = try String(contentsOf: checklistURL, encoding: .utf8)
        XCTAssertTrue(checklistText.contains("N/A — GitHub Direct Distribution"))
        XCTAssertTrue(checklistText.contains("DevNotch-1.1.0.dmg"))
    }
}
