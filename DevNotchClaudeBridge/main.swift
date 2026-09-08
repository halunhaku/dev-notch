import Foundation

func main() {
    let args = CommandLine.arguments
    let event = args.count > 1 ? args[1] : "statusLine"
    let stdinData = FileHandle.standardInput.readDataToEndOfFile()

    let record = ActivityPayloadSanitizer.sanitize(
        rawJSON: stdinData,
        provider: "claude",
        event: event
    )

    try? ActivityIPCWriter.write(record: record)
}

main()
