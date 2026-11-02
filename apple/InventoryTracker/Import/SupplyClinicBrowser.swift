import Foundation
import Observation
import WebKit

enum SupplyClinicFailure: LocalizedError {
    case signInRequired
    case signInFormMissing
    case invalidCredentials
    case noResponse
    case challenge
    case unreadablePage

    var errorDescription: String? {
        switch self {
        case .signInRequired: "Please sign in to SupplyClinic."
        case .signInFormMissing: "Couldn't load the SupplyClinic sign-in page. Please try again later."
        case .invalidCredentials: "Sign in failed. Please double-check your SupplyClinic email and password."
        case .noResponse: "SupplyClinic didn't respond. Please try again."
        case .challenge: "Complete the check on SupplyClinic's page, then try again."
        case .unreadablePage: "Couldn't read your order history. Please try again."
        }
    }
}

enum SupplyClinicPage {
    case loading, signIn, challenge, ready, unreachable
}

/// Talks to SupplyClinic through a real web view, kept out of sight unless the site demands a
/// bot check. The default data store keeps the session between imports. Passwords are only
/// typed into the site's form.
@Observable
final class SupplyClinicBrowser: NSObject, WKNavigationDelegate {
    static let ordersURL = URL(string: "https://www.supplyclinic.com/checkout/orders")!
    private static let signInURL = URL(string: "https://www.supplyclinic.com/users/sign_in")!
    private static let maxOrderPages = 50
    private static let signInPolls = 80

    @ObservationIgnored let webView: WKWebView
    private(set) var page = SupplyClinicPage.loading
    private(set) var pagesRead = 0
    @ObservationIgnored private var pendingLoad: CheckedContinuation<Void, Error>?
    @ObservationIgnored private var finishedLoads = 0

    override init() {
        let configuration = WKWebViewConfiguration()
        #if DEBUG
        if ProcessInfo.processInfo.environment["INVENTORY_PRIVATE_WEB"] != nil {
            configuration.websiteDataStore = .nonPersistent()
        }
        #endif
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
    }

    func start() {
        page = .loading
        webView.load(URLRequest(url: Self.ordersURL))
    }

    func signIn(email: String, password: String) async throws {
        try await waitForLoad { webView.load(URLRequest(url: Self.signInURL)) }
        let markup = try await currentMarkup()
        if SupplyClinicText.isChallengePage(markup) {
            page = .challenge
            throw SupplyClinicFailure.challenge
        }
        guard SupplyClinicText.isSignInPage(url: webView.url?.absoluteString ?? "", markup: markup) else { return }

        let loadsBeforeSubmit = finishedLoads
        try await submitCredentials(email: email, password: password)
        try await waitForSubmissionToSettle(loadsBeforeSubmit: loadsBeforeSubmit)
        try await confirmSession()
    }

    func signOut() async {
        let store = webView.configuration.websiteDataStore
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await store.dataRecords(ofTypes: types)
        await store.removeData(ofTypes: types, for: records.filter { $0.displayName.contains("supplyclinic") })
        start()
    }

    func submitCredentials(email: String, password: String) async throws {
        let submitted = try await webView.callAsyncJavaScript(
            Self.signInScript,
            arguments: ["email": email, "password": password],
            contentWorld: .defaultClient
        )
        guard submitted as? Bool == true else { throw SupplyClinicFailure.signInFormMissing }
    }

    private func waitForSubmissionToSettle(loadsBeforeSubmit: Int) async throws {
        for _ in 0..<Self.signInPolls {
            try await Task.sleep(for: .milliseconds(250))
            if webView.isLoading { continue }
            let leftSignIn = !(webView.url?.absoluteString.contains("/users/sign_in") ?? true)
            let wasReset = try await submittedFormWasReset()
            if finishedLoads != loadsBeforeSubmit || leftSignIn || wasReset { return }
        }
        throw SupplyClinicFailure.noResponse
    }

    /// The site changes pages with Turbo, so the page showing after a submit proves nothing.
    /// Only the orders page shows whether the session is real.
    private func confirmSession() async throws {
        try await waitForLoad { webView.load(URLRequest(url: Self.ordersURL)) }
        let markup = try await currentMarkup()
        if SupplyClinicText.isChallengePage(markup) {
            page = .challenge
            throw SupplyClinicFailure.challenge
        }
        if SupplyClinicText.isSignInPage(url: webView.url?.absoluteString ?? "", markup: markup) {
            page = .signIn
            throw SupplyClinicFailure.invalidCredentials
        }
        page = .ready
    }

    func submittedFormWasReset() async throws -> Bool {
        try await webView.evaluateJavaScript(Self.submittedFormResetScript) as? Bool ?? false
    }

    func loadHTML(_ html: String) async throws {
        try await waitForLoad { webView.loadHTMLString(html, baseURL: nil) }
    }

    func collectOrders() async throws -> [OrderLine] {
        var lines: [OrderLine] = []
        pagesRead = 0
        for pageNumber in 1...Self.maxOrderPages {
            try await waitForLoad { webView.load(URLRequest(url: Self.url(forPage: pageNumber))) }
            try await failIfBlocked(isFirstPage: pageNumber == 1)
            let pageLines = try await extractLines()
            if pageLines.isEmpty { break }
            lines += pageLines
            pagesRead = pageNumber
        }
        return lines
    }

    func extractLines() async throws -> [OrderLine] {
        guard let json = try await webView.evaluateJavaScript(Self.extractionScript) as? String else {
            throw SupplyClinicFailure.unreadablePage
        }
        return try JSONDecoder().decode([RawOrderLine].self, from: Data(json.utf8)).map(OrderLine.init(raw:))
    }

    private static func url(forPage page: Int) -> URL {
        guard page > 1 else { return ordersURL }
        return ordersURL.appending(queryItems: [URLQueryItem(name: "page", value: "\(page)")])
    }

    private func waitForLoad(_ start: () -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            pendingLoad = continuation
            start()
        }
    }

    private func failIfBlocked(isFirstPage: Bool) async throws {
        let markup = try await currentMarkup()
        if SupplyClinicText.isChallengePage(markup) {
            page = .challenge
            throw SupplyClinicFailure.challenge
        }
        if isFirstPage, SupplyClinicText.isSignInPage(url: webView.url?.absoluteString ?? "", markup: markup) {
            page = .signIn
            throw SupplyClinicFailure.signInRequired
        }
    }

    private func currentMarkup() async throws -> String {
        try await webView.evaluateJavaScript("document.documentElement.outerHTML") as? String ?? ""
    }

    private func refreshPage() async {
        guard let markup = try? await currentMarkup() else { return }
        if SupplyClinicText.isChallengePage(markup) {
            page = .challenge
        } else if SupplyClinicText.isSignInPage(url: webView.url?.absoluteString ?? "", markup: markup) {
            page = .signIn
        } else {
            page = .ready
        }
    }

    private func finishLoad(with error: Error?) {
        guard let continuation = pendingLoad else { return }
        pendingLoad = nil
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        page = .loading
    }

    /// The site's widgets can hold back `didFinish` for a long time, and the address alone
    /// already shows that the sign-in page is up.
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if pendingLoad == nil, webView.url?.absoluteString.contains("/users/sign_in") == true {
            page = .signIn
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishedLoads += 1
        finishLoad(with: nil)
        Task { await refreshPage() }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleFailure(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleFailure(error)
    }

    private func handleFailure(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        if pendingLoad == nil { page = .unreachable }
        finishLoad(with: error)
    }

    private static let signInScript = """
    const form = document.querySelector('form[action="/users/sign_in"]')
      ?? document.querySelector('input[name="user[password]"]')?.form;
    if (!form) return false;
    const fill = (name, value) => {
      const field = form.querySelector(`input[name="${name}"]`);
      if (!field) return false;
      field.value = value;
      field.dispatchEvent(new Event("input", { bubbles: true }));
      field.dispatchEvent(new Event("change", { bubbles: true }));
      return true;
    };
    if (!fill("user[email]", email) || !fill("user[password]", password)) return false;
    const remember = form.querySelector('input[type="checkbox"][name="user[remember_me]"]');
    if (remember) remember.checked = true;
    form.dataset.inventorySubmitted = "true";
    setTimeout(() => form.requestSubmit(), 0);
    return true;
    """

    private static let submittedFormResetScript = """
    (() => {
      const form = document.querySelector("form[data-inventory-submitted]");
      if (!form) return true;
      return form.querySelector('input[name="user[password]"]')?.value === "";
    })()
    """

    private static let extractionScript = """
    (() => {
      const text = (root, selector) => {
        const element = root.querySelector(selector);
        if (!element) return "";
        const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT);
        const parts = [];
        while (walker.nextNode()) {
          const value = walker.currentNode.textContent.trim();
          if (value) parts.push(value);
        }
        return parts.join(" ");
      };
      const lines = [];
      for (const order of document.querySelectorAll("div.order")) {
        const date = text(order, ".order-date");
        for (const suborder of order.querySelectorAll(".suborder")) {
          const vendor = text(suborder, ".suborder-vendor");
          const suborderNumber = text(suborder, ".suborder-number");
          for (const line of suborder.querySelectorAll(".historical-suborder-item")) {
            lines.push({
              date,
              vendor,
              suborderNumber,
              name: text(line, ".suborder-item-name"),
              manuCode: text(line, ".suborder-item-manu"),
              quantity: text(line, ".suborder-item-quantity"),
              unitPrice: text(line, ".suborder-item-unit-price"),
              status: text(line, ".suborder-item-status"),
            });
          }
        }
      }
      return JSON.stringify(lines);
    })()
    """
}
