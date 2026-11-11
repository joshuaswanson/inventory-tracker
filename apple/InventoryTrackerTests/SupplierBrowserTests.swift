import Foundation
import Testing
@testable import InventoryTracker

private let orderPage = """
<html><body>
<div class="order">
  <div class="order-date">Ordered on <b>03/14/2026</b></div>
  <div class="suborder">
    <div class="suborder-vendor"><span>Items from</span> <span>Acme Dental</span></div>
    <div class="suborder-number">#S-100</div>
    <div class="historical-suborder-item">
      <div class="suborder-item-name">CSR Wrap 20" x 20" &amp; Tape</div>
      <div class="suborder-item-manu"><span>Manu Code:</span><span>GZ-22</span></div>
      <div class="suborder-item-quantity">Qty: 3</div>
      <div class="suborder-item-unit-price">$1,204.50</div>
      <div class="suborder-item-status"><span>Status:</span> Delivered</div>
    </div>
  </div>
  <div class="suborder">
    <div class="suborder-vendor">Items from Benco</div>
    <div class="suborder-number">#S-101</div>
    <div class="historical-suborder-item">
      <div class="suborder-item-name">Gloves</div>
      <div class="suborder-item-quantity">Qty: 1</div>
      <div class="suborder-item-unit-price">$9.00</div>
    </div>
  </div>
</div>
</body></html>
"""

@Suite struct SupplierBrowserTests {
    @Test func scriptReadsOrderLinesFromARealWebView() async throws {
        let browser = SupplierBrowser(supplier: .supplyClinic)
        try await browser.loadHTML(orderPage)
        let lines = try await browser.extractLines()

        #expect(lines.count == 2)
        let first = try #require(lines.first)
        #expect(first.date == "2026-03-14")
        #expect(first.vendor == "Acme Dental")
        #expect(first.suborderNumber == "S-100")
        #expect(first.name == "CSR Wrap 20\" x 20\" & Tape")
        #expect(first.manuCode == "GZ-22")
        #expect(first.quantity == 3)
        #expect(first.unitPrice == 1204.5)
        #expect(first.status == "Delivered")
        #expect(lines[1].vendor == "Benco")
        #expect(lines[1].manuCode == "")
    }

    @Test func credentialsReachTheSignInFormExactly() async throws {
        let page = """
        <html><body>
        <form action="/users/sign_in" method="post"
              onsubmit="event.preventDefault(); document.title = JSON.stringify({
                email: this.elements['user[email]'].value,
                password: this.elements['user[password]'].value,
                remember: this.querySelector('input[type=checkbox]').checked
              })">
          <input type="hidden" name="user[remember_me]" value="0">
          <input type="email" name="user[email]">
          <input type="password" name="user[password]">
          <input type="checkbox" name="user[remember_me]" value="1">
          <button type="submit">Sign in</button>
        </form>
        </body></html>
        """
        let browser = SupplierBrowser(supplier: .supplyClinic)
        try await browser.loadHTML(page)

        let password = #"p"a'ss\word`${1}<b>"#
        try await browser.submitCredentials(email: "dr.lee+office@example.com", password: password)

        var captured = ""
        for _ in 0..<40 where captured.isEmpty {
            try await Task.sleep(for: .milliseconds(50))
            captured = try await browser.webView.evaluateJavaScript("document.title") as? String ?? ""
        }
        let fields = try #require(JSONSerialization.jsonObject(with: Data(captured.utf8)) as? [String: Any])
        #expect(fields["email"] as? String == "dr.lee+office@example.com")
        #expect(fields["password"] as? String == password)
        #expect(fields["remember"] as? Bool == true)
    }

    @Test func submittedFormOnlyCountsAsResetWhenThePasswordIsCleared() async throws {
        let page = """
        <html><body>
        <form action="/users/sign_in" onsubmit="event.preventDefault()">
          <input name="user[email]">
          <input type="password" name="user[password]">
        </form>
        </body></html>
        """
        let browser = SupplierBrowser(supplier: .supplyClinic)
        try await browser.loadHTML(page)
        try await browser.submitCredentials(email: "a@example.com", password: "secret")
        try await Task.sleep(for: .milliseconds(100))
        #expect(try await browser.submittedFormWasReset() == false)

        _ = try await browser.webView.evaluateJavaScript(#"document.querySelector('input[type="password"]').value = ""; 1"#)
        #expect(try await browser.submittedFormWasReset() == true)
    }

    @Test func pageWithoutASignInFormIsReported() async throws {
        let browser = SupplierBrowser(supplier: .supplyClinic)
        try await browser.loadHTML("<html><body>Maintenance</body></html>")
        await #expect(throws: ImportFailure.self) {
            try await browser.submitCredentials(email: "a@example.com", password: "b")
        }
    }

    @Test func emptyPageHasNoLines() async throws {
        let browser = SupplierBrowser(supplier: .supplyClinic)
        try await browser.loadHTML("<html><body>No orders</body></html>")
        #expect(try await browser.extractLines().isEmpty)
    }

    @Test func bencoOrderListNamesPurchasesAndSkipsCredits() async throws {
        let page = """
        <html><body><div class="order-history">
          <div class="order-container"><h3 class="panel-title pull-left"><span>9/2/2026</span><span>-</span><span> Order #AA100 - Merchandise </span></h3>
            <h3 class="panel-title pull-right"><a href="https://example.com/PurchaseHistory/NewOrderDetail/AA100">View Details</a></h3></div>
          <div class="order-container"><h3 class="panel-title pull-left"><span>8/12/2026</span><span>-</span><span> Order #CR200 - Credit </span></h3>
            <h3 class="panel-title pull-right"><a href="https://example.com/PurchaseHistory/NewOrderDetail/CR200">View Details</a></h3></div>
        </div></body></html>
        """
        let browser = SupplierBrowser(supplier: .benco)
        try await browser.loadHTML(page)
        let links = try await browser.orderLinks(try #require(Supplier.benco.orderLinksScript))
        #expect(links == [
            OrderLink(id: "AA100", url: "https://example.com/PurchaseHistory/NewOrderDetail/AA100", isPurchase: true),
            OrderLink(id: "CR200", url: "https://example.com/PurchaseHistory/NewOrderDetail/CR200", isPurchase: false),
        ])
    }

    @Test func bencoOrderPageReadsEachLine() async throws {
        let page = """
        <html><body>
        <h2>Your Orders &gt; Order Details</h2>
        <div>Ordered on September 02, 2026 | Order # AA100 | Purchase Order # 123</div>
        <div class="row product-detail-area"><div class="col-sm-9 product-details">
          <strong><a>Universal Adhesive Vial Refill 5ml </a></strong>
          <p>Product #: 4394-863</p><p>Quantity: 1</p><p>Net Price: $1,185.47</p><p>Ext Price: $1,185.47</p></div></div>
        <div class="row product-detail-area"><div class="col-sm-9 product-details">
          <strong><a>C-Fold Towel White Case of 2376</a></strong>
          <p>Product #: 6492-128</p><p>Quantity: 0</p><p>Net Price: $30.90</p><p>Ext Price: $0.00</p></div></div>
        </body></html>
        """
        let browser = SupplierBrowser(supplier: .benco)
        try await browser.loadHTML(page)
        let lines = try await browser.extractLines()
        #expect(lines.count == 2)
        let first = try #require(lines.first)
        #expect(first.date == "2026-09-02")
        #expect(first.vendor == "Benco Dental")
        #expect(first.suborderNumber == "AA100")
        #expect(first.name == "Universal Adhesive Vial Refill 5ml")
        #expect(first.manuCode == "4394-863")
        #expect(first.quantity == 1)
        #expect(first.unitPrice == 1185.47)
        #expect(first.isImportable)
        #expect(first.sourceID(for: .benco) == "benco:AA100:4394-863")
        #expect(!lines[1].isImportable)
    }

    @Test func bencoListAddressCoversThreeYearsAndCountsPagesFromZero() {
        let address = Supplier.benco.ordersURL(page: 2, today: "2026-11-11").absoluteString
        #expect(address == "https://shop.benco.com/PurchaseHistory/NewIndex?DateRangeOption=CustomRange&OrderStatus=all&PageNumber=1&StartDate=2023-11-12&EndDate=2026-11-11")
    }
}
