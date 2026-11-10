import SwiftUI

/// The large page title with an optional button on the right.
struct PageHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.display(38, bold: true, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.text(13))
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
    }
}

extension PageHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle, trailing: { EmptyView() })
    }
}

/// The round blue + button.
struct CircleIconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .background(Theme.accent, in: Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
    }
}

/// "Add exercise", "Add set".
struct OutlineButton: View {
    let title: String
    var systemImage: String? = "plus"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .bold))
                }
                Text(title)
                    .font(AppFont.text(15, weight: .semibold))
            }
            .foregroundStyle(Theme.link)
            .frame(maxWidth: .infinity, minHeight: 44)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }
}

/// "Finish workout", "Start".
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.display(22, bold: true))
                .tracking(0.4)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.borderless)
    }
}

/// The back button shown under the navigation bar on detail screens.
struct BackButton: View {
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(AppFont.text(15, weight: .semibold))
            }
            .foregroundStyle(Theme.link)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Back to \(title)")
    }
}

/// Small uppercase caption above a field or column.
struct FieldLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(AppFont.text(11, weight: .semibold))
            .tracking(0.9)
            .textCase(.uppercase)
            .foregroundStyle(Theme.muted)
    }
}

/// Expand and collapse chevron, 44 pt target.
struct ChevronButton: View {
    let isExpanded: Bool
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(isExpanded ? "Collapse \(name)" : "Expand \(name)")
    }
}

/// The boxed look of the reps and weight fields.
struct NumberFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppFont.display(22))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

/// The boxed look of single-line and multi-line text fields.
struct TextBoxStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppFont.text(15))
            .foregroundStyle(Theme.ink)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

/// Whole number from 1 to 999. An empty or zero entry keeps the last good value.
struct RepsField: View {
    @Binding var value: Int
    let label: String
    @State private var text: String
    @FocusState private var focused: Bool

    init(value: Binding<Int>, label: String) {
        _value = value
        self.label = label
        _text = State(initialValue: String(value.wrappedValue))
    }

    var body: some View {
        TextField("Reps", text: $text)
            .keyboardType(.numberPad)
            .focused($focused)
            .modifier(NumberFieldStyle())
            .accessibilityLabel(label)
            .onChange(of: text) { _, new in
                let digits = String(new.filter { $0.isASCII && $0.isNumber }.prefix(3))
                if digits != new {
                    text = digits
                    return
                }
                if let number = Int(digits), number >= 1, number != value {
                    value = number
                }
            }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { text = String(value) }
            }
            .onChange(of: value) { _, new in
                if !focused { text = String(new) }
            }
    }
}

/// Optional decimal weight. Empty stays empty; 0 is a real value.
struct WeightField: View {
    @Binding var value: Double?
    let label: String
    @State private var text: String
    @FocusState private var focused: Bool

    init(value: Binding<Double?>, label: String) {
        _value = value
        self.label = label
        _text = State(initialValue: WeightFormat.string(value.wrappedValue))
    }

    var body: some View {
        TextField("Weight", text: $text)
            .keyboardType(.decimalPad)
            .focused($focused)
            .modifier(NumberFieldStyle())
            .accessibilityLabel(label)
            .onChange(of: text) { _, new in
                let clean = WeightFormat.sanitize(new)
                if clean != new {
                    text = clean
                    return
                }
                let parsed = WeightFormat.parse(clean)
                if parsed != value {
                    value = parsed
                }
            }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { text = WeightFormat.string(value) }
            }
            .onChange(of: value) { _, new in
                if !focused { text = WeightFormat.string(new) }
            }
    }
}

/// A "Done" button above number pads, which have no return key.
struct KeyboardDoneToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    dismissKeyboard()
                }
                .font(.body.weight(.semibold))
            }
        }
    }
}

/// Short centred message for empty pages.
struct EmptyPrompt: View {
    let title: String
    var message: String?

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(AppFont.display(24))
                .foregroundStyle(Theme.ink)
            if let message {
                Text(message)
                    .font(AppFont.text(15))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
    }
}
