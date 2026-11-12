import SwiftUI

struct FormSheet<Content: View>: View {
    let title: String
    var saveTitle = "Save"
    var canSave = true
    var showsCancel = true
    var macWidth: CGFloat = 480
    var macHeight: CGFloat = 600
    var fitsContentOnMac = false
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

            fields

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
        .frame(width: macWidth, height: fitsContentOnMac ? nil : macHeight)
        #endif
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
    }

    @ViewBuilder
    private var fields: some View {
        #if os(macOS)
        if fitsContentOnMac {
            form.fixedSize(horizontal: false, vertical: true)
        } else {
            ScrollView { form }
        }
        #else
        ScrollView { form }
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

extension EnvironmentValues {
    /// True while a suggestion panel hangs off the bottom edge of the field.
    @Entry var fieldHasAttachedPanel = false
    @Entry var checkForUpdates: (() -> Void)?
}

private struct FieldBox: ViewModifier {
    let isFocused: Bool
    @Environment(\.fieldHasAttachedPanel) private var hasAttachedPanel

    private var shape: UnevenRoundedRectangle {
        let bottom = hasAttachedPanel ? 0 : Theme.radiusSmall
        return UnevenRoundedRectangle(
            topLeadingRadius: Theme.radiusSmall, bottomLeadingRadius: bottom,
            bottomTrailingRadius: bottom, topTrailingRadius: Theme.radiusSmall
        )
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: 14))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 12)
            .frame(minHeight: 38)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: shape)
            .overlay(shape.strokeBorder(isFocused ? Theme.primary : Theme.border))
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

nonisolated enum ItemSearch {
    /// Every typed word has to appear in the name. Names that start with the text come first,
    /// then names with a word that starts with it.
    static func matches(_ query: String, in names: [(id: String, name: String)]) -> [String] {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return names.map(\.id) }
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
        func rank(_ name: String) -> Int {
            let name = name.lowercased()
            if name.hasPrefix(lowered) { return 0 }
            let nameWords = name.split { !$0.isLetter && !$0.isNumber }
            if nameWords.contains(where: { $0.hasPrefix(words[0]) }) { return 1 }
            return 2
        }
        return names
            .filter { entry in words.allSatisfy { entry.name.lowercased().contains($0) } }
            .sorted { (rank($0.name), $0.name.lowercased()) < (rank($1.name), $1.name.lowercased()) }
            .map(\.id)
    }
}

/// A text field that suggests matching items as you type. The list hangs below the field on top
/// of whatever comes next, so the form under it stays put. Give the field a higher `zIndex` than
/// the fields after it so the list is drawn over them.
struct ItemSearchField: View {
    private static let visibleRows = 7
    private static let rowHeight: CGFloat = 36

    let items: [Item]
    @Binding var itemID: String
    var detail: (Item) -> String = { _ in "" }

    @State private var query = ""
    @State private var isOpen = false
    @State private var highlighted = 0
    @FocusState private var isFocused: Bool

    private var selectedName: String {
        items.first { $0.id == itemID }?.name ?? ""
    }

    private var matches: [Item] {
        let search = query == selectedName ? "" : query
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        return ItemSearch.matches(search, in: items.map { (id: $0.id, name: $0.name) }).compactMap { byID[$0] }
    }

    var body: some View {
        let matches = matches
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
            TextField("", text: $query, prompt: Text("Type to find an item").foregroundStyle(Theme.textTertiary))
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit { if matches.indices.contains(highlighted) { pick(matches[highlighted]) } }
                .onKeyPress(.downArrow) { move(1, count: matches.count) }
                .onKeyPress(.upArrow) { move(-1, count: matches.count) }
                .onKeyPress(.escape) {
                    close()
                    return .handled
                }
                .accessibilityIdentifier("Item search")
            Button {
                if isOpen { close() } else { open() }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isOpen ? "Hide items" : "Show all items")
        }
        .modifier(FieldBox(isFocused: isFocused || isOpen))
        .environment(\.fieldHasAttachedPanel, isOpen)
        .overlay(alignment: .bottom) {
            if isOpen {
                panel(matches).alignmentGuide(.bottom) { $0[.top] }
            }
        }
        .onAppear { query = selectedName }
        .onChange(of: itemID) { if !isFocused { query = selectedName } }
        .onChange(of: query) {
            guard isFocused, query != selectedName else { return }
            highlighted = 0
            isOpen = true
        }
        .onChange(of: isFocused) {
            if isFocused {
                open()
            } else {
                Task {
                    try? await Task.sleep(for: .milliseconds(150))
                    if !isFocused { close() }
                }
            }
        }
    }

    private func panel(_ matches: [Item]) -> some View {
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: Theme.radiusSmall, bottomTrailingRadius: Theme.radiusSmall)
        return Group {
            if matches.isEmpty {
                Text("No items match \"\(query)\".")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .frame(height: Self.rowHeight)
            } else {
                ScrollViewReader { scroller in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(matches.enumerated()), id: \.element.id) { index, item in
                                row(item, isHighlighted: index == highlighted).id(item.id)
                            }
                        }
                    }
                    .frame(height: Self.rowHeight * CGFloat(min(matches.count, Self.visibleRows)))
                    .onChange(of: highlighted) {
                        if matches.indices.contains(highlighted) { scroller.scrollTo(matches[highlighted].id) }
                    }
                }
            }
        }
        .background(Theme.surface, in: shape)
        .overlay(shape.strokeBorder(Theme.primary))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 5)
        .padding(.top, -1)
    }

    private func row(_ item: Item, isHighlighted: Bool) -> some View {
        let extra = detail(item)
        return Button { pick(item) } label: {
            HStack(spacing: 8) {
                Text(item.name)
                    .font(.system(size: 13, weight: item.id == itemID ? .semibold : .regular))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !extra.isEmpty {
                    Text(extra)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .monospacedDigit()
                }
                if item.id == itemID {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.primary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: Self.rowHeight)
            .background(isHighlighted ? Theme.primaryBackground : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(extra.isEmpty ? item.name : "\(item.name) (\(extra))")
    }

    private func open() {
        highlighted = max(0, matches.firstIndex { $0.id == itemID } ?? 0)
        isOpen = true
    }

    private func close() {
        isOpen = false
        query = selectedName
    }

    private func move(_ step: Int, count: Int) -> KeyPress.Result {
        guard count > 0 else { return .ignored }
        if !isOpen { open() }
        highlighted = min(max(0, highlighted + step), count - 1)
        return .handled
    }

    private func pick(_ item: Item) {
        itemID = item.id
        query = item.name
        isOpen = false
        isFocused = false
    }
}
