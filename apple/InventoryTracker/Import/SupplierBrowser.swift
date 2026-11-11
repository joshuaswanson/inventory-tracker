import Foundation
import Observation
import WebKit

enum ImportFailure: LocalizedError {
    case signInRequired
    case signInFormMissing
    case invalidCredentials
    case noResponse
    case challenge
    case unreadablePage

    var errorDescription: String? {
        switch self {
        case .signInRequired: "Please sign in first."
        case .signInFormMissing: "Couldn't load the sign-in page. Please try again later."
        case .invalidCredentials: "Sign in failed. Please double-check your email and password."
        case .noResponse: "The site didn't respond. Please try again."
        case .challenge: "Complete the check on the site's page, then try again."
        case .unreadablePage: "Couldn't read your order history. Please try again."
        }
    }
}

enum SupplierPage {
    case loading, signIn, challenge, ready, unreachable
}

/// Talks to a supplier's site through a real web view, kept out of sight unless the site demands a
/// bot check. The default data store keeps the session between imports. Passwords are only
/// typed into the site's form.
@Observable
final class SupplierBrowser: NSObject, WKNavigationDelegate {
    private static let signInPolls = 80
    private static let detailPolls = 12

    @ObservationIgnored let supplier: Supplier

    @ObservationIgnored let webView: WKWebView
    private(set) var page = SupplierPage.loading
    private(set) var pagesRead = 0
    private(set) var ordersFound = 0
    @ObservationIgnored private var pendingLoad: CheckedContinuation<Void, Error>?
    @ObservationIgnored private var finishedLoads = 0

    init(supplier: Supplier) {
        self.supplier = supplier
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
        webView.load(URLRequest(url: supplier.ordersURL))
    }

    func signIn(email: String, password: String) async throws {
        try await waitForLoad { webView.load(URLRequest(url: supplier.signInURL)) }
        let markup = try await currentMarkup()
        if OrderText.isChallengePage(markup) {
            page = .challenge
            throw ImportFailure.challenge
        }
        guard supplier.isSignInPage(url: webView.url?.absoluteString ?? "", markup: markup) else { return }

        let loadsBeforeSubmit = finishedLoads
        try await submitCredentials(email: email, password: password)
        try await waitForSubmissionToSettle(loadsBeforeSubmit: loadsBeforeSubmit)
        try await confirmSession()
    }

    func signOut() async {
        let store = webView.configuration.websiteDataStore
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await store.dataRecords(ofTypes: types)
        await store.removeData(ofTypes: types, for: records.filter { $0.displayName.contains(supplier.cookieDomain) })
        start()
    }

    func submitCredentials(email: String, password: String) async throws {
        let submitted = try await webView.callAsyncJavaScript(
            supplier.signInScript,
            arguments: ["email": email, "password": password],
            contentWorld: .defaultClient
        )
        guard submitted as? Bool == true else { throw ImportFailure.signInFormMissing }
    }

    private func waitForSubmissionToSettle(loadsBeforeSubmit: Int) async throws {
        for _ in 0..<Self.signInPolls {
            try await Task.sleep(for: .milliseconds(250))
            if webView.isLoading { continue }
            let leftSignIn = !(webView.url?.absoluteString.contains(supplier.signInPath) ?? true)
            let wasReset = try await submittedFormWasReset()
            if finishedLoads != loadsBeforeSubmit || leftSignIn || wasReset { return }
        }
        throw ImportFailure.noResponse
    }

    /// The site changes pages with Turbo, so the page showing after a submit proves nothing.
    /// Only the orders page shows whether the session is real.
    private func confirmSession() async throws {
        try await waitForLoad { webView.load(URLRequest(url: supplier.ordersURL)) }
        let markup = try await currentMarkup()
        if OrderText.isChallengePage(markup) {
            page = .challenge
            throw ImportFailure.challenge
        }
        if supplier.isSignInPage(url: webView.url?.absoluteString ?? "", markup: markup) {
            page = .signIn
            throw ImportFailure.invalidCredentials
        }
        page = .ready
    }

    func submittedFormWasReset() async throws -> Bool {
        try await webView.evaluateJavaScript(supplier.submittedFormResetScript) as? Bool ?? false
    }

    func loadHTML(_ html: String, baseURL: URL? = nil) async throws {
        try await waitForLoad { webView.loadHTMLString(html, baseURL: baseURL) }
    }

    func collectOrders(knownOrders: Set<String> = []) async throws -> [OrderLine] {
        ordersFound = 0
        if supplier.collectScript != nil {
            try await waitForLoad { webView.load(URLRequest(url: supplier.ordersURL)) }
            try await failIfBlocked(isFirstPage: true)
            return try await collectFromService(knownOrders: knownOrders)
        }
        if let linksScript = supplier.orderLinksScript {
            return try await collectOrdersOneByOne(linksScript: linksScript, knownOrders: knownOrders)
        }
        var lines: [OrderLine] = []
        pagesRead = 0
        for pageNumber in 1...supplier.maxOrderPages {
            try await waitForLoad { webView.load(URLRequest(url: supplier.ordersURL(page: pageNumber))) }
            try await failIfBlocked(isFirstPage: pageNumber == 1)
            let pageLines = try await extractLines()
            if pageLines.isEmpty { break }
            lines += pageLines
            pagesRead = pageNumber
        }
        return lines
    }

    func collectFromService(knownOrders: Set<String>) async throws -> [OrderLine] {
        guard let script = supplier.collectScript,
              let json = try await webView.callAsyncJavaScript(script, arguments: ["knownOrders": Array(knownOrders)], contentWorld: .page) as? String else {
            throw ImportFailure.unreadablePage
        }
        let collected = try JSONDecoder().decode(CollectedOrders.self, from: Data(json.utf8))
        if collected.signedOut == true {
            page = .signIn
            throw ImportFailure.signInRequired
        }
        ordersFound = collected.ordersFound
        pagesRead = collected.ordersFound
        return collected.lines.map(OrderLine.init(raw:))
    }

    /// The list is newest first, so a page where every order is already known ends the search.
    private func collectOrdersOneByOne(linksScript: String, knownOrders: Set<String>) async throws -> [OrderLine] {
        var newOrders: [OrderLink] = []
        pagesRead = 0
        for pageNumber in 1...supplier.maxOrderPages {
            try await waitForLoad { webView.load(URLRequest(url: supplier.ordersURL(page: pageNumber))) }
            try await failIfBlocked(isFirstPage: pageNumber == 1)
            let links = try await orderLinks(linksScript)
            if links.isEmpty { break }
            pagesRead = pageNumber
            ordersFound += links.count
            let unseen = links.filter { !knownOrders.contains($0.id) }
            newOrders += unseen.filter(\.isPurchase)
            if unseen.isEmpty { break }
        }

        var lines: [OrderLine] = []
        for order in newOrders {
            guard let url = URL(string: order.url) else { continue }
            try await waitForLoad { webView.load(URLRequest(url: url)) }
            lines += try await extractLinesWhenReady()
            pagesRead += 1
        }
        return lines
    }

    func orderLinks(_ script: String) async throws -> [OrderLink] {
        guard let json = try await webView.evaluateJavaScript(script) as? String else {
            throw ImportFailure.unreadablePage
        }
        return try JSONDecoder().decode([OrderLink].self, from: Data(json.utf8))
    }

    /// Some sites hop through a redirect or fill the page in after it loads.
    private func extractLinesWhenReady() async throws -> [OrderLine] {
        for _ in 0..<Self.detailPolls {
            if let lines = try? await extractLines(), !lines.isEmpty { return lines }
            try await Task.sleep(for: .milliseconds(500))
        }
        return []
    }

    func extractLines() async throws -> [OrderLine] {
        guard let json = try await webView.evaluateJavaScript(supplier.extractionScript) as? String else {
            throw ImportFailure.unreadablePage
        }
        return try JSONDecoder().decode([RawOrderLine].self, from: Data(json.utf8)).map(OrderLine.init(raw:))
    }

    private func waitForLoad(_ start: () -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            pendingLoad = continuation
            start()
        }
    }

    private func failIfBlocked(isFirstPage: Bool) async throws {
        let markup = try await currentMarkup()
        if OrderText.isChallengePage(markup) {
            page = .challenge
            throw ImportFailure.challenge
        }
        if isFirstPage, supplier.isSignInPage(url: webView.url?.absoluteString ?? "", markup: markup) {
            page = .signIn
            throw ImportFailure.signInRequired
        }
    }

    private func currentMarkup() async throws -> String {
        try await webView.evaluateJavaScript("document.documentElement.outerHTML") as? String ?? ""
    }

    private func refreshPage() async {
        guard let markup = try? await currentMarkup() else { return }
        if OrderText.isChallengePage(markup) {
            page = .challenge
        } else if supplier.isSignInPage(url: webView.url?.absoluteString ?? "", markup: markup) {
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
        if pendingLoad == nil, webView.url?.absoluteString.contains(supplier.signInPath) == true {
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
}
