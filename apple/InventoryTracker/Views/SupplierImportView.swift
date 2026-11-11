import SwiftData
import SwiftUI
import WebKit

#if os(macOS)
private struct WebContainer: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ view: WKWebView, context: Context) {}
}
#else
private struct WebContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ view: WKWebView, context: Context) {}
}
#endif

private struct SavedLoginSuggestion: View {
    let supplierName: String
    let email: String
    let onUse: () -> Void
    let onRemove: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onUse) {
                HStack(spacing: 10) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.primary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(email)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Text("Saved \(supplierName) login")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Use saved login \(email)")
            RowIconButton(systemImage: "xmark", label: "Remove saved login", action: onRemove)
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, 6)
        .background(isHovering ? Theme.primaryBackground : Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusSmall))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(Theme.border))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        .onHover { isHovering = $0 }
    }
}

struct SupplierImportView: View {
    private enum Field {
        case email, password
    }

    private static let formHeight: CGFloat = 520
    private static let verificationHeaderHeight: CGFloat = 76
    #if os(macOS)
    private static let ownerCheck = "Touch ID or your Mac password"
    #else
    private static let ownerCheck = "Face ID or your passcode"
    #endif

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(Router.self) private var router
    @State private var savedEmail: String
    @Query private var allItems: [Item]
    @State private var browser: SupplierBrowser
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var isSigningIn = false
    @State private var summary: OrderImportSummary?
    @State private var errorMessage: String?
    @State private var errorPage: SupplierPage?
    @State private var isReviewing = false
    @State private var warning: String?
    @State private var perishableIDs: Set<String> = []
    @State private var expirations: [String: String] = [:]
    @State private var savedLoginEmail: String?
    @State private var savesLogin = true
    @State private var activeField = Field.email
    @State private var emailFocusRequest = 0
    private let supplier: Supplier
    private let loginStore: SavedLoginStore

    init(supplier: Supplier) {
        self.supplier = supplier
        loginStore = SavedLoginStore(supplierID: supplier.id)
        _browser = State(initialValue: SupplierBrowser(supplier: supplier))
        _savedEmail = State(initialValue: SupplierSettings.email(for: supplier))
    }

    private var page: SupplierPage { isSigningIn ? .signIn : browser.page }

    private var visibleError: String? { errorPage == page ? errorMessage : nil }

    private var needsVerification: Bool { browser.page == .challenge && summary == nil }

    private var canSubmit: Bool {
        switch page {
        case .signIn: !isWorking && !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
        case .ready: !isWorking
        case .unreachable: true
        case .loading, .challenge: false
        }
    }

    private var submitTitle: String {
        if isWorking {
            return page == .signIn ? "Signing in..." : "Importing..."
        }
        switch page {
        case .signIn: return "Sign in & Import"
        case .unreachable: return "Try Again"
        default: return "Import"
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            WebContainer(webView: browser.webView)
                .padding(.top, Self.verificationHeaderHeight)
                .opacity(needsVerification ? 1 : 0)
                .allowsHitTesting(needsVerification)

            if needsVerification {
                verificationHeader
            } else {
                content
            }
        }
        .background(Theme.surface)
        .task {
            email = savedEmail
            savedLoginEmail = loginStore.savedEmail()
            browser.start()
        }
        .onChange(of: page) {
            if page == .signIn { emailFocusRequest += 1 }
        }
        #if os(macOS)
        .frame(width: needsVerification ? 860 : 480, height: needsVerification ? 680 : Self.formHeight)
        #endif
    }

    private var verificationHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Import from \(supplier.name)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("\(supplier.name) wants to confirm you're a person. Complete the check below.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            RowIconButton(systemImage: "xmark", label: "Close") { dismiss() }
        }
        .padding(.horizontal, 24)
        .frame(height: Self.verificationHeaderHeight)
        .background(Theme.surface)
    }

    @ViewBuilder
    private var content: some View {
        if let summary, isReviewing {
            FormSheet(title: "New Items", saveTitle: "Continue", showsCancel: false, macHeight: Self.formHeight, onSave: finishReview) {
                review(newItems(in: summary))
            }
        } else if let summary {
            FormSheet(title: "Import from \(supplier.name)", saveTitle: "Done", showsCancel: false, macHeight: Self.formHeight, onSave: { router.sheet = .importOrders }) {
                result(summary)
            }
        } else {
            FormSheet(
                title: "Import from \(supplier.name)",
                saveTitle: submitTitle,
                canSave: canSubmit,
                macHeight: Self.formHeight,
                errorMessage: visibleError,
                onSave: submit
            ) {
                switch page {
                case .signIn:
                    signInFields
                case .ready:
                    signedIn
                case .unreachable:
                    intro("Couldn't reach \(supplier.name). Check your internet connection and try again.")
                case .loading, .challenge:
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        intro("Connecting to \(supplier.name)...")
                    }
                }
            }
        }
    }

    private func intro(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var signInFields: some View {
        intro("Sign in with your \(supplier.name) account to import your order history as purchases. Only new orders are added, so it's safe to run anytime.")
        LabeledField(title: "\(supplier.name) Email", isRequired: true) {
            ThemedTextField("you@example.com", text: $email, keyboard: .email, focusRequest: emailFocusRequest) {
                activeField = .email
            }
            .textContentType(.username)
            suggestion(under: .email)
        }
        LabeledField(title: "Password", isRequired: true) {
            ThemedSecureField(placeholder: "Your \(supplier.name) password", text: $password) {
                activeField = .password
            }
            suggestion(under: .password)
        }
        CheckboxField(title: "Save this login on this device", isOn: $savesLogin)
        Text(savesLogin
            ? "Saved only on this device after you sign in. \(Self.ownerCheck) is needed to use it."
            : "Your password is only used to sign in to \(supplier.name). It is not saved.")
            .font(.system(size: 12))
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func suggestion(under field: Field) -> some View {
        if activeField == field, password.isEmpty, let savedLoginEmail {
            SavedLoginSuggestion(supplierName: supplier.name, email: savedLoginEmail, onUse: useSavedLogin, onRemove: removeSavedLogin)
        }
    }

    private func useSavedLogin() {
        Task {
            guard await SavedLoginStore.confirmOwner() else { return }
            do {
                guard let savedPassword = try loginStore.password() else { return }
                email = loginStore.savedEmail() ?? email
                password = savedPassword
            } catch {
                errorMessage = error.localizedDescription
                errorPage = page
            }
        }
    }

    private func removeSavedLogin() {
        loginStore.delete()
        savedLoginEmail = nil
    }

    @ViewBuilder
    private var signedIn: some View {
        intro(isWorking
            ? "Reading your order history, \(browser.pagesRead) pages so far..."
            : "Signed in to \(supplier.name)\(savedEmail.isEmpty ? "" : " as \(savedEmail)"). Press Import to bring in any new orders.")
        Button("Use a different account") {
            errorMessage = nil
            Task { await browser.signOut() }
        }
        .buttonStyle(.plain)
        .font(.system(size: 13))
        .foregroundStyle(Theme.primary)
        .underline()
        .disabled(isWorking)
    }

    private func newItems(in summary: OrderImportSummary) -> [Item] {
        allItems.filter { summary.newItemIDs.contains($0.id) }
            .sorted { orderedText($0.name, $1.name, ascending: true) }
    }

    @ViewBuilder
    private func review(_ items: [Item]) -> some View {
        intro("Tick any of these new items that expire. You can add the date printed on the box, or skip it.")
        ForEach(items) { item in
            VStack(alignment: .leading, spacing: 8) {
                CheckboxField(title: item.name, isOn: Binding(
                    get: { perishableIDs.contains(item.id) },
                    set: { isOn in
                        if isOn { perishableIDs.insert(item.id) } else { perishableIDs.remove(item.id) }
                    }
                ))
                if perishableIDs.contains(item.id) {
                    HStack(spacing: 8) {
                        Text("Expires")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                        OptionalDayField(day: Binding(get: { expirations[item.id] }, set: { expirations[item.id] = $0 }))
                    }
                    .padding(.leading, 26)
                }
            }
        }
    }

    private func finishReview() {
        for item in allItems where perishableIDs.contains(item.id) {
            item.isPerishable = true
            guard let expiration = expirations[item.id] else { continue }
            for purchase in item.purchases ?? [] where purchase.expirationDate == nil {
                purchase.expirationDate = expiration
            }
        }
        try? modelContext.save()
        isReviewing = false
    }

    private func result(_ summary: OrderImportSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let warning {
                Label("Something looks wrong", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                Text(warning)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Import complete")
                    .font(.system(size: 16, weight: .semibold))
            }
            resultLine(count: summary.imported, noun: "new purchase", suffix: "added")
            resultLine(count: summary.newItems, noun: "new item", suffix: "created")
            resultLine(count: summary.newVendors, noun: "new vendor", suffix: "created")
            Text("\(summary.duplicates) already imported (skipped)")
            if summary.skipped > 0 {
                Text("\(summary.skipped) cancelled, returned, or incomplete (skipped)")
            }
        }
        .font(.system(size: 14))
        .foregroundStyle(Theme.text)
    }

    private func resultLine(count: Int, noun: String, suffix: String) -> some View {
        Text("\(Text("\(count)").fontWeight(.semibold)) \(noun)\(count == 1 ? "" : "s") \(suffix)")
    }

    private func submit() {
        if page == .unreachable {
            errorMessage = nil
            browser.start()
            return
        }
        isWorking = true
        errorMessage = nil
        isSigningIn = page == .signIn
        let enteredEmail = email.trimmingCharacters(in: .whitespaces)
        let enteredPassword = password
        let needsSignIn = isSigningIn
        Task {
            defer { isWorking = false }
            do {
                if needsSignIn {
                    try await browser.signIn(email: enteredEmail, password: enteredPassword)
                    savedEmail = enteredEmail
                    SupplierSettings.setEmail(enteredEmail, for: supplier)
                    if savesLogin {
                        try? loginStore.save(email: enteredEmail, password: enteredPassword)
                        savedLoginEmail = enteredEmail
                    }
                    password = ""
                    isSigningIn = false
                }
                let knownOrders = ImportWarning.knownOrders(from: supplier, in: modelContext)
                let lines = try await browser.collectOrders(knownOrders: knownOrders)
                let previouslyImported = ImportWarning.previouslyImported(from: supplier, in: modelContext)
                let imported = try OrderMerge.merge(lines, from: supplier, into: modelContext)
                let foundNothingNew = lines.isEmpty && supplier.orderLinksScript != nil && browser.pagesRead > 0
                warning = foundNothingNew ? nil : ImportWarning.message(linesRead: lines.count, summary: imported, previouslyImported: previouslyImported, supplierName: supplier.name)
                if warning == nil {
                    SupplierSettings.setLastImport(Date(), for: supplier)
                }
                isReviewing = !imported.newItemIDs.isEmpty
                summary = imported
            } catch {
                isSigningIn = false
                if needsSignIn { password = "" }
                errorMessage = error.localizedDescription
                errorPage = browser.page
            }
        }
    }
}
