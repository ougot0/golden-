import SwiftUI

/// Small uppercase label, in the spirit of the engraved markings on camera bodies.
struct InstrumentLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .tracking(1.1)
            .textCase(.uppercase)
            .foregroundStyle(Palette.inkSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A 1-pixel rule used instead of card backgrounds to separate content.
struct Hairline: View {
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(Palette.rule)
            .frame(height: 1 / displayScale)
            .accessibilityHidden(true)
    }
}

/// A section with a label and a rule above its content.
struct InstrumentSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Hairline()
            InstrumentLabel(title)
            content
        }
    }
}

/// Label/value row. Values use tabular digits so columns of times line up.
struct ValueRow: View {
    let label: String
    let value: String
    var detail: String? = nil
    var emphasized = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(emphasized ? .body.weight(.semibold) : .body)
                    .monospacedDigit()
                    .foregroundStyle(emphasized ? Palette.amberText : Palette.ink)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Explanatory message for empty or degraded states. Always offers an action when one exists.
struct StatusMessage: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(Palette.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.amber)
                    .foregroundStyle(Color(hex: 0x151717))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

extension View {
    /// Standard screen background.
    func instrumentBackground() -> some View {
        background(Palette.background.ignoresSafeArea())
    }
}
