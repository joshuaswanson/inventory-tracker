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
                        Text("Saved SupplyClinic login")
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

struct SupplyClinicImportView: View {
    private enum Field {
        case email, password
    }

    private static let formHeight: CGFloat = 560
    private static let verificationHeaderHeight: CGFloat = 76

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("supplyClinicEmail") private var savedEmail = ""
    @State private var browser = SupplyClinicBrowser()
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var isSigningIn = false
    @State private var summary: OrderImportSummary?
    @State private var errorMessage: String?
    @State private var errorPage: SupplyClinicPage?
    @State private var keychainHint: String?
    @State private var savedLoginEmail: String?
    @State private var savesLogin = true
    @State private var activeField = Field.email
    @State private var emailFocusRequest = 0
    private let loginStore = SavedLoginStore()

    private var page: SupplyClinicPage { isSigningIn ? .signIn : browser.page }

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
                Text("Import from SupplyClinic")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("SupplyClinic wants to confirm you're a person. Complete the check below.")
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
        if let summary {
            FormSheet(title: "Import from SupplyClinic", saveTitle: "Done", showsCancel: false, macHeight: Self.formHeight, onSave: { dismiss() }) {
                result(summary)
            }
        } else {
            FormSheet(
                title: "Import from SupplyClinic",
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
                    intro("Couldn't reach SupplyClinic. Check your internet connection and try again.")
                case .loading, .challenge:
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        intro("Connecting to SupplyClinic...")
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
        intro("Sign in with your SupplyClinic account to import your order history as purchases. Only new orders are added, so it's safe to run anytime.")
        LabeledField(title: "SupplyClinic Email", isRequired: true) {
            ThemedTextField("you@example.com", text: $email, keyboard: .email, focusRequest: emailFocusRequest) {
                activeField = .email
            }
            .textContentType(.username)
            suggestion(under: .email)
        }
        LabeledField(title: "Password", isRequired: true) {
            ThemedSecureField(placeholder: "Your SupplyClinic password", text: $password) {
                activeField = .password
            }
            suggestion(under: .password)
        }
        keychainOption
        CheckboxField(title: "Save this login on this device", isOn: $savesLogin)
        Text(savesLogin
            ? "Saved only in this device's Keychain after you sign in. Touch ID is required to use it."
            : "Your password is only used to sign in to SupplyClinic. It is not saved.")
            .font(.system(size: 12))
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func suggestion(under field: Field) -> some View {
        if activeField == field, password.isEmpty, let savedLoginEmail {
            SavedLoginSuggestion(email: savedLoginEmail, onUse: useSavedLogin, onRemove: removeSavedLogin)
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
    private var keychainOption: some View {
        #if os(macOS)
        Button("Use iCloud Keychain", systemImage: "key.fill", action: openPasswordPicker)
            .buttonStyle(.themedSecondary)
        if let keychainHint {
            Text(keychainHint)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
        #else
        Text("To use iCloud Keychain, tap the email field, then choose Passwords above the keyboard.")
            .font(.system(size: 12))
            .foregroundStyle(Theme.textSecondary)
        #endif
    }

    #if os(macOS)
    /// macOS has no public call for this picker, so this sends what Edit > AutoFill > Passwords sends.
    private func openPasswordPicker() {
        emailFocusRequest += 1
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            let opened = NSApp.sendAction(Selector(("_handleInsertFromPasswordsCommand:")), to: nil, from: nil)
            keychainHint = opened ? nil : "Click the email field, then choose Edit > AutoFill > Passwords."
        }
    }
    #endif

    @ViewBuilder
    private var signedIn: some View {
        intro(isWorking
            ? "Reading your order history, \(browser.pagesRead) pages so far..."
            : "Signed in to SupplyClinic\(savedEmail.isEmpty ? "" : " as \(savedEmail)"). Press Import to bring in any new orders.")
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

    private func result(_ summary: OrderImportSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Import complete")
                .font(.system(size: 16, weight: .semibold))
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
                    if savesLogin {
                        try? loginStore.save(email: enteredEmail, password: enteredPassword)
                        savedLoginEmail = enteredEmail
                    }
                    password = ""
                    isSigningIn = false
                }
                let lines = try await browser.collectOrders()
                summary = try SupplyClinicMerge.merge(lines, into: modelContext)
            } catch {
                isSigningIn = false
                if needsSignIn { password = "" }
                errorMessage = error.localizedDescription
                errorPage = browser.page
            }
        }
    }
}
