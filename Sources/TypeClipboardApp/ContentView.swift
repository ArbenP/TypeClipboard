import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: ClipboardViewModel
    @FocusState private var bufferFocused: Bool

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                header
                bufferSection
                controlsSection
                statusSection
                accessibilitySection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .background(
            WindowConfigurator(
                minimumSize: CGSize(width: 640, height: 560),
                preferredSize: CGSize(width: 760, height: 660)
            )
            .allowsHitTesting(false)
        )
        .onChange(of: viewModel.bufferText) { _ in
            viewModel.userEditedBuffer()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TypeClipboard")
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
            Text(viewModel.previewDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
            metricsRow
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 12) {
            Label("\(viewModel.characterCount) \(viewModel.characterCount == 1 ? "character" : "characters")", systemImage: "character.cursor.ibeam")
            Label("\(viewModel.lineCount) \(viewModel.lineCount == 1 ? "line" : "lines")", systemImage: "text.justify")
            if let updated = viewModel.lastUpdatedAt {
                Label("Updated \(Self.relativeFormatter.localizedString(for: updated, relativeTo: Date()))", systemImage: "clock.arrow.circlepath")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var bufferSection: some View {
        GroupBox {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.bufferText)
                    .font(.system(.body, design: .monospaced))
                    .padding(6)
                    .background(Color.clear)
                    .focused($bufferFocused)
                    .frame(minHeight: 180, maxHeight: 240)
                if viewModel.bufferText.isEmpty {
                    Text("Captured text will appear here…")
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                        .padding(.leading, 12)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        } label: {
            Label("Typing Buffer", systemImage: "square.and.pencil")
                .font(.title3)
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    viewModel.captureClipboard()
                } label: {
                    Label("Capture Clipboard", systemImage: "doc.on.clipboard")
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])

                Button(role: .destructive) {
                    viewModel.clearBuffer()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(viewModel.bufferText.isEmpty)

                Spacer()

                Button {
                    viewModel.typeBuffer()
                } label: {
                    Label(viewModel.isTyping ? "Typing…" : "Type Now", systemImage: viewModel.isTyping ? "hourglass.circle.fill" : "keyboard")
                        .font(.headline)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.typingButtonDisabled)
            }

            Divider()

            settingsGrid
        }
    }

    private var settingsGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 16) {
            GridRow {
                Label("Countdown", systemImage: "timer")
                    .foregroundStyle(.primary)
                Stepper(value: $viewModel.countdownSeconds, in: viewModel.countdownRange) {
                    Text(viewModel.countdownDescription)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GridRow {
                Label("Per-character delay", systemImage: "speedometer")
                VStack(alignment: .leading, spacing: 6) {
                    Slider(value: $viewModel.perCharacterDelay, in: viewModel.characterDelayRange)
                    Text("Current: \(viewModel.delayDescription)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            GridRow {
                Label("Automation", systemImage: "bolt.fill")
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $viewModel.autoCapture) {
                        Text("Update buffer when the clipboard changes")
                    }
                    Toggle(isOn: $viewModel.appendReturn) {
                        Text("Press Return after typing")
                    }
                }
            }
        }
        .gridColumnAlignment(.leading)
    }

    private var statusSection: some View {
        Group {
            if let status = viewModel.statusMessage {
                StatusBanner(message: status)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.statusMessage?.id)
    }

    private var accessibilitySection: some View {
        Group {
            if !viewModel.isAccessibilityTrusted {
                GroupBox {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.orange)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enable Accessibility")
                                .font(.headline)
                            Text("macOS requires accessibility permission so TypeClipboard can simulate keystrokes. Select “Open Settings”, enable TypeClipboard, then return here and press Refresh.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                Button("Open Settings") {
                                    viewModel.requestAccessibilityAccess()
                                }
                                Button("Refresh Status") {
                                    viewModel.refreshAccessibilityStatus()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct StatusBanner: View {
    let message: ClipboardViewModel.StatusMessage

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: iconName(for: message.style))
                .font(.title3)
            Text(message.text)
                .font(.callout)
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(backgroundColor(for: message.style))
        .foregroundStyle(foregroundColor(for: message.style))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func iconName(for style: ClipboardViewModel.StatusMessage.Style) -> String {
        switch style {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.circle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    private func backgroundColor(for style: ClipboardViewModel.StatusMessage.Style) -> Color {
        switch style {
        case .info:
            return Color.blue.opacity(0.12)
        case .success:
            return Color.green.opacity(0.12)
        case .warning:
            return Color.orange.opacity(0.14)
        case .error:
            return Color.red.opacity(0.12)
        }
    }

    private func foregroundColor(for style: ClipboardViewModel.StatusMessage.Style) -> Color {
        switch style {
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
