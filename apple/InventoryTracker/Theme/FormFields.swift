import SwiftUI

struct FormSheet<Content: View>: View {
    let title: String
    var saveTitle = "Save"
    var canSave = true
    var showsCancel = true
    var macHeight: CGFloat = 600
    var errorMessage: String?
    let onSave: () -> Void
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.text)
                Spacer()
                RowIconButton(systemImage: "xmark", label: "Close") { dismiss() }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) { content }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.red)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }

            Divider().overlay(Theme.border)

            HStack(spacing: 8) {
                Spacer()
                if showsCancel {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.themedSecondary)
                        .keyboardShortcut(.cancelAction)
                }
                Button(saveTitle, action: onSave)
                    .buttonStyle(.themedPrimary)
                    .disabled(!canSave)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Theme.surface)
        #if os(macOS)
        .frame(width: 480, height: macHeight)
        #endif
    }
}

struct FieldLabel: View {
    let title: String
    var isRequired = false

    var body: some View {
        HStack(spacing: 3) {
            Text(title).sectionLabel(tracking: 0.3)
            if isRequired {
                Text("*")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.red)
            }
        }
    }
}

struct LabeledField<Content: View>: View {
    let title: String
    var isRequired = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(title: title, isRequired: isRequired)
            content.accessibilityIdentifier(title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FieldRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) { content }
    }
}

private struct FieldBox: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .font(.system(size: 14))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 12)
            .frame(minHeight: 38)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .strokeBorder(isFocused ? Theme.primary : Theme.border)
            )
    }
}

enum FieldKeyboard {
    case text, number, decimal, phone, email
}

struct ThemedTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: FieldKeyboard = .text
    var focusRequest = 0
    var onFocus: () -> Void = {}
    @FocusState private var isFocused: Bool

    init(
        _ placeholder: String = "",
        text: Binding<String>,
        keyboard: FieldKeyboard = .text,
        focusRequest: Int = 0,
        onFocus: @escaping () -> Void = {}
    ) {
        self.placeholder = placeholder
        self._text = text
        self.keyboard = keyboard
        self.focusRequest = focusRequest
        self.onFocus = onFocus
    }

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.textTertiary))
            .textFieldStyle(.plain)
            .focused($isFocused)
            .modifier(FieldBox(isFocused: isFocused))
            .onChange(of: focusRequest) { isFocused = true }
            .onChange(of: isFocused) { if isFocused { onFocus() } }
            #if os(iOS)
            .keyboardType(iosKeyboard)
            .textInputAutocapitalization(keyboard == .email ? .never : .sentences)
            .autocorrectionDisabled(keyboard == .email)
            #endif
    }

    #if os(iOS)
    private var iosKeyboard: UIKeyboardType {
        switch keyboard {
        case .text: .default
        case .number: .numberPad
        case .decimal: .decimalPad
        case .phone: .phonePad
        case .email: .emailAddress
        }
    }
    #endif
}

struct ThemedSecureField: View {
    let placeholder: String
    @Binding var text: String
    var onFocus: () -> Void = {}
    @FocusState private var isFocused: Bool

    var body: some View {
        SecureField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.textTertiary))
            .textFieldStyle(.plain)
            .focused($isFocused)
            .textContentType(.password)
            .modifier(FieldBox(isFocused: isFocused))
            .onChange(of: isFocused) { if isFocused { onFocus() } }
    }
}

struct ThemedTextArea: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.textTertiary), axis: .vertical)
            .textFieldStyle(.plain)
            .lineLimit(3...6)
            .focused($isFocused)
            .padding(.vertical, 9)
            .modifier(FieldBox(isFocused: isFocused))
    }
}

struct ThemedPicker<Value: Hashable, Options: View>: View {
    @Binding var selection: Value
    @ViewBuilder let options: Options

    var body: some View {
        Picker("", selection: $selection) { options }
            .labelsHidden()
            .pickerStyle(.menu)
            .buttonStyle(.borderless)
            .tint(Theme.text)
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
            .padding(.horizontal, 6)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(Theme.border))
    }
}

struct DayField: View {
    @Binding var day: String

    private var date: Binding<Date> {
        Binding(
            get: { Day.localDate(from: day) ?? Date() },
            set: { day = Day.string(from: $0) }
        )
    }

    var body: some View {
        DatePicker("", selection: date, displayedComponents: .date)
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(Theme.primary)
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
    }
}

struct OptionalDayField: View {
    @Binding var day: String?

    var body: some View {
        HStack(spacing: 8) {
            if let current = day {
                DayField(day: Binding(get: { current }, set: { day = $0 }))
                RowIconButton(systemImage: "xmark.circle.fill", label: "Clear date") { day = nil }
            } else {
                Button("Add date") { day = Day.today }
                    .buttonStyle(.themedSecondary)
                    .frame(minHeight: 38)
            }
        }
    }
}

struct CheckboxField: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 17))
                    .foregroundStyle(isOn ? Theme.primary : Theme.textTertiary)
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.text)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
