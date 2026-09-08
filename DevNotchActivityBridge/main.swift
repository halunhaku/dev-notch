import Foundation

func main() {
    let args = CommandLine.arguments

    // Syntax: DevNotchActivityBridge <providerID> [eventName]
    let provider = args.count > 1 ? args[1] : "antigravity"
    let event = args.count > 2 ? args[2] : "statusLine"

    let stdinData = FileHandle.standardInput.readDataToEndOfFile()

    let record = ActivityPayloadSanitizer.sanitize(
        rawJSON: stdinData,
        provider: provider,
        event: event
    )

    try? ActivityIPCWriter.write(record: record)

    // Antigravity hook contract expects valid JSON on stdout
    if let stdoutJSON = "{}".data(using: .utf8) {
        FileHandle.standardOutput.write(stdoutJSON)
    }
}

main()
