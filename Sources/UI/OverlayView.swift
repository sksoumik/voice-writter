import SwiftUI

/// The floating pill shown while dictating: a status dot, the live text, and a
/// small microphone level meter.
struct OverlayView: View {
    @ObservedObject var controller: DictationController

    var body: some View {
        HStack(spacing: 14) {
            statusIndicator

            VStack(alignment: .leading, spacing: 2) {
                Text(controller.state.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(displayText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if controller.state == .listening {
                MicMeter(level: controller.micLevel)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(width: 460, height: 84, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.15), value: controller.micLevel)
    }

    private var displayText: String {
        if controller.partialText.isEmpty {
            switch controller.state {
            case .listening: return "Speak now..."
            case .correcting: return "Polishing your words..."
            default: return controller.state.label
            }
        }
        return controller.partialText
    }

    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
            .shadow(color: statusColor.opacity(0.7), radius: controller.state == .listening ? 6 : 0)
    }

    private var statusColor: Color {
        switch controller.state {
        case .listening: return .red
        case .transcribing, .correcting: return .orange
        case .inserting: return .green
        case .error: return .yellow
        default: return .gray
        }
    }
}

/// A small bar style microphone level meter.
private struct MicMeter: View {
    var level: Float

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(barColor(index))
                    .frame(width: 4, height: barHeight(index))
            }
        }
        .frame(height: 28)
    }

    private func isLit(_ index: Int) -> Bool {
        // Map 0...1 level to 0...5 lit bars.
        Int(level * 5) > index
    }

    private func barHeight(_ index: Int) -> CGFloat {
        let base: CGFloat = 8
        let step: CGFloat = 4
        return base + step * CGFloat(index)
    }

    private func barColor(_ index: Int) -> Color {
        isLit(index) ? .accentColor : .secondary.opacity(0.25)
    }
}
