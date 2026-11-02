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

@Suite struct SupplyClinicExtractionTests {
    @Test func scriptReadsOrderLinesFromARealWebView() async throws {
        let browser = SupplyClinicBrowser()
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
        let browser = SupplyClinicBrowser()
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
        let browser = SupplyClinicBrowser()
        try await browser.loadHTML(page)
        try await browser.submitCredentials(email: "a@example.com", password: "secret")
        try await Task.sleep(for: .milliseconds(100))
        #expect(try await browser.submittedFormWasReset() == false)

        _ = try await browser.webView.evaluateJavaScript(#"document.querySelector('input[type="password"]').value = ""; 1"#)
        #expect(try await browser.submittedFormWasReset() == true)
    }

    @Test func pageWithoutASignInFormIsReported() async throws {
        let browser = SupplyClinicBrowser()
        try await browser.loadHTML("<html><body>Maintenance</body></html>")
        await #expect(throws: SupplyClinicFailure.self) {
            try await browser.submitCredentials(email: "a@example.com", password: "b")
        }
    }

    @Test func emptyPageHasNoLines() async throws {
        let browser = SupplyClinicBrowser()
        try await browser.loadHTML("<html><body>No orders</body></html>")
        #expect(try await browser.extractLines().isEmpty)
    }
}
