import Foundation
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "ActivityBridgeCLI")

func main() {
    let args = CommandLine.arguments

    // Syntax: DevNotchActivityBridge <providerID> [eventName]
    let provider = args.count > 1 ? args[1] : "antigravity"
    let event = args.count > 2 ? args[2] : "statusLine"

    logger.info("[\(provider, privacy: .public)] Hook received: \(event, privacy: .public)")

    let stdinData = FileHandle.standardInput.readDataToEndOfFile()

    let record = ActivityPayloadSanitizer.sanitize(
        rawJSON: stdinData,
        provider: provider,
        event: event
    )

    logger.info("[\(provider, privacy: .public)] Sanitized state: \(record.activityState, privacy: .public)")

    try? ActivityIPCWriter.write(record: record)
    ActivityIPCWriter.logTrace(provider: provider, message: "Hook received: \(event) -> \(record.activityState)")

    // Antigravity hook contract expects valid JSON on stdout
    if let stdoutJSON = "{}".data(using: .utf8) {
        FileHandle.standardOutput.write(stdoutJSON)
    }
}

main()
