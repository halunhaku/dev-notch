import SwiftUI
import Carbon

/// Interactive shortcut recorder view capturing local key combinations in Settings.
struct ShortcutRecorderView: View {
    @Binding var shortcut: KeyboardShortcutDefinition
    var onChange: ((KeyboardShortcutDefinition) -> Void)? = nil

    @State private var isRecording: Bool = false
    @State private var localMonitor: Any?

    var body: some View {
        Button(action: toggleRecording) {
            HStack(spacing: 6) {
                if isRecording {
                    Text("Press shortcut…")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.cyan)
                } else {
                    Text(shortcut.displayString)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                }

                if isRecording {
                    Image(systemName: "record.circle")
                        .font(.system(size: 10))
                        .foregroundColor(.cyan)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isRecording ? Color.cyan : Color.secondary.opacity(0.3), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isRecording ? Color.cyan.opacity(0.08) : Color.primary.opacity(0.04))
                    )
            )
        }
        .buttonStyle(.plain)
        .onDisappear {
            stopRecording()
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        stopRecordingMonitor()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            // Pressing Esc without modifiers cancels recording
            if event.keyCode == UInt16(kVK_Escape) && event.modifierFlags.intersection([.command, .option, .control]).isEmpty {
                self.stopRecording()
                return nil
            }

            let carbonMods = KeyboardShortcutDefinition.carbonModifiers(from: event.modifierFlags)
            let newDef = KeyboardShortcutDefinition(
                keyCode: UInt32(event.keyCode),
                carbonModifiers: carbonMods
            )

            // Reject single-key shortcuts without modifiers
            if newDef.isValid {
                self.shortcut = newDef
                self.onChange?(newDef)
                self.stopRecording()
                return nil
            }

            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        stopRecordingMonitor()
    }

    private func stopRecordingMonitor() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}
