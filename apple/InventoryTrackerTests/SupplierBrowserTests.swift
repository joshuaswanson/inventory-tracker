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

    @Test func elevateReadsNewOrdersFromItsDataServiceAndSkipsKnownOnes() async throws {
        let page = """
        <html><body><script>
        window.requests = [];
        window.fetch = async (address) => {
          window.requests.push(address);
          const body = address.includes("internalid=")
            ? { tranid: "SO2", trandate: "2/5/2026", status: { name: "Billed" }, lines: [
                { quantity: 2, rate_formatted: "$1,230.00", item: { itemid: "raw id", displayname: "635000100 - Arrest Blue", storedisplayname2: "Advantage Arrest 8ml" } },
                { quantity: 1, rate_formatted: "$0.00", item: { itemid: "SAMPLE" } } ] }
            : { totalRecordsFound: 2, records: [
                { internalid: "11", recordtype: "salesorder", tranid: "SO1" },
                { internalid: "22", recordtype: "salesorder", tranid: "SO2" } ] };
          return { ok: true, status: 200, json: async () => body };
        };
        </script></body></html>
        """
        let browser = SupplierBrowser(supplier: .elevate)
        try await browser.loadHTML(page)
        let lines = try await browser.collectFromService(knownOrders: ["SO1"])

        #expect(browser.ordersFound == 2)
        #expect(lines.count == 2)
        let first = try #require(lines.first)
        #expect(first.date == "2026-02-05")
        #expect(first.vendor == "Elevate Oral Care")
        #expect(first.suborderNumber == "SO2")
        #expect(first.name == "Advantage Arrest 8ml")
        #expect(first.manuCode == "635000100")
        #expect(first.quantity == 2)
        #expect(first.unitPrice == 1230)
        #expect(lines[1].manuCode == "SAMPLE")
        let requests = try await browser.webView.evaluateJavaScript("window.requests.length") as? Int
        #expect(requests == 2)
    }

    @Test func elevateReportsAnExpiredSession() async throws {
        let page = "<html><body><script>window.fetch = async () => ({ ok: false, status: 401, json: async () => ({}) });</script></body></html>"
        let browser = SupplierBrowser(supplier: .elevate)
        try await browser.loadHTML(page)
        await #expect(throws: ImportFailure.self) {
            try await browser.collectFromService(knownOrders: [])
        }
        #expect(browser.page == .signIn)
    }

    @Test func bigCommerceStoreReadsOrdersAcrossPagesAndSkipsKnownOnes() async throws {
        let page = """
        <html><body><script>
        const row = (id, status, placed) => `<li class="account-listItem"><h6 class="account-orderStatus-label">${status}</h6>
          <h5 class="account-product-title"><a href="/account.php?action=view_order&order_id=${id}">Order #${id}</a></h5>
          <div class="account-product-detail"><h6>Order Placed</h6><span>${placed}</span></div>
          <div class="account-product-detail"><h6>Last Update</h6><span>1st Jan 2020</span></div></li>`;
        const pages = {
          "action=order_status": `<ul>${row(501, "Shipped", "7th Jun 2026")}${row(400, "Shipped", "1st May 2026")}</ul>
            <li class="pagination-item pagination-item--next"><a href="/account.php?action=order_status&page=2">Next</a></li>`,
          "page=2": `<ul>${row(300, "Refunded", "22nd Dec 2025")}</ul>`,
          "order_id=501": `<li class="account-listItem"><span class="account-product-price">$27.95</span>
            <h5 class="account-product-title">2 × CSR Wraps, 20' x 20' Blue</h5></li>
            <li class="account-listItem"><span class="account-product-price">$1,114.95</span>
            <h5 class="account-product-title">1 × Curing Light</h5></li>`,
          "order_id=300": `<li class="account-listItem"><span class="account-product-price">$5.00</span>
            <h5 class="account-product-title">3 × Refunded Thing</h5></li>`,
        };
        window.requests = [];
        window.fetch = async (address) => {
          window.requests.push(address);
          const key = Object.keys(pages).reverse().find((candidate) => address.includes(candidate));
          return { ok: true, status: 200, text: async () => pages[key] };
        };
        </script></body></html>
        """
        let browser = SupplierBrowser(supplier: .dentalMarket)
        try await browser.loadHTML(page, baseURL: URL(string: "https://store.example/"))
        let lines = try await browser.collectFromService(knownOrders: ["400"])

        #expect(browser.ordersFound == 3)
        #expect(lines.count == 3)
        let first = try #require(lines.first)
        #expect(first.date == "2026-06-07")
        #expect(first.vendor == "The Dental Market")
        #expect(first.suborderNumber == "501")
        #expect(first.name == "CSR Wraps, 20' x 20' Blue")
        #expect(first.quantity == 2)
        #expect(first.unitPrice == 27.95)
        #expect(first.isImportable)
        #expect(lines[1].unitPrice == 1114.95)
        #expect(lines[2].date == "2025-12-22")
        #expect(!lines[2].isImportable)
    }

    @Test func bigCommerceStoreReportsAnExpiredSession() async throws {
        let page = """
        <html><body><script>
        window.fetch = async () => ({ ok: true, status: 200, text: async () => '<form><input name="login_pass" type="password"></form>' });
        </script></body></html>
        """
        let browser = SupplierBrowser(supplier: .dentalMarket)
        try await browser.loadHTML(page)
        await #expect(throws: ImportFailure.self) {
            try await browser.collectFromService(knownOrders: [])
        }
    }

    @Test func kettenbachReadsOrdersFromItsOrderPage() async throws {
        let page = """
        <html><body><table class="table"><tr class="expand-row"><td><div id="exp-KB100" class="expand-panel"><article class="order card">
          <div>Order KB100 Placed 29 SEP 2026 • 1 Carton(s) Shipped on 09-30-26 $231.50</div>
          <div class="items">
            <div class="item"><div class="meta"><strong>Visalys CemCore Normal pack</strong><small>Qty 1 • SKU 13571 • Price $1,167.50 • Line $1,167.50</small></div></div>
            <div class="item"><div class="meta"><strong>Panasil Tray Soft</strong><small>Qty 2 • SKU 11141 • Price $64.00 • Line $128.00</small></div></div>
          </div></article></div></td></tr>
          <tr class="expand-row"><td><div id="exp-KB099" class="expand-panel"><article class="order card">
          <div>Order KB099 Placed 3 JAN 2026</div>
          <div class="items"><div class="item"><div class="meta"><strong>Old Thing</strong><small>Qty 1 • SKU 1 • Price $1.00 • Line $1.00</small></div></div></div>
          </article></div></td></tr></table></body></html>
        """
        let browser = SupplierBrowser(supplier: .kettenbach)
        try await browser.loadHTML(page)
        let lines = try await browser.collectFromService(knownOrders: ["KB099"])
        #expect(browser.ordersFound == 2)
        #expect(lines.count == 2)
        let first = try #require(lines.first)
        #expect(first.date == "2026-09-29")
        #expect(first.suborderNumber == "KB100")
        #expect(first.manuCode == "13571")
        #expect(first.quantity == 1)
        #expect(first.unitPrice == 1167.5)
        #expect(lines[1].quantity == 2)
        #expect(lines[1].unitPrice == 64)
    }

    @Test func kettenbachSignedOutPageAsksForSignIn() async throws {
        let browser = SupplierBrowser(supplier: .kettenbach)
        try await browser.loadHTML("<html><body><a class='sign-in-button-a'>Sign In</a>Loading orders…</body></html>")
        await #expect(throws: ImportFailure.self) {
            try await browser.collectFromService(knownOrders: [])
        }
        #expect(Supplier.kettenbach.isSignInPage(url: "https://www.kettenbachusa.com/orders.aspx", markup: "<a class='sign-in-button-a'>"))
    }

    @Test func net32ReadsEachVendorsLinesAndStopsAtKnownOrders() async throws {
        let page = """
        <html><body><script>
        const orderCard = (id, placed, status) => `<div class="ordersList_orderCard__x"><a href="/account/orders/details/${id}">Order # ${id}</a>
          Placed On ${placed} Status ${status} (1) Shipped To 1 Main St Total (1 Items) $9.00</div>`;
        const lineItem = (name, price, quantity) => `<div class="ordersList_lineItem__y"><div class="ordersList_itemName__z">${name}</div>
          <div class="ordersList_itemMeta__z"><span class="ordersList_itemPrice__z">${price}/ea</span><span class="ordersList_itemQty__z">Qty: ${quantity}</span></div></div>`;
        const pages = {
          "pageNumber=1": orderCard(900, "09/11/2026", "Delivered") + orderCard(800, "08/19/2026", "Delivered"),
          "pageNumber=2": orderCard(700, "07/01/2026", "Delivered"),
          "details/900": `<div class="orderDetail_vendorSection__a"><span class="ordersList_fulfilledByName__b">Fulfilled by <strong>Carolina Dental</strong></span>${lineItem("N95 Mask", "$53.70", 1)}</div>
            <div class="orderDetail_vendorSection__a"><span class="ordersList_fulfilledByName__b">Fulfilled by <strong>PA Dental</strong></span>${lineItem("Arti-Check .0016\\"", "$1,017.30", 5)}</div>`,
        };
        window.requests = [];
        window.fetch = async (address) => {
          window.requests.push(address);
          const key = Object.keys(pages).find((candidate) => address.includes(candidate));
          return { ok: true, status: 200, url: address, text: async () => pages[key] ?? "" };
        };
        </script></body></html>
        """
        let browser = SupplierBrowser(supplier: .net32)
        try await browser.loadHTML(page, baseURL: URL(string: "https://store.example/"))
        let lines = try await browser.collectFromService(knownOrders: ["800", "700"])

        #expect(lines.count == 2)
        let first = try #require(lines.first)
        #expect(first.date == "2026-09-11")
        #expect(first.vendor == "Carolina Dental")
        #expect(first.suborderNumber == "900")
        #expect(first.name == "N95 Mask")
        #expect(first.quantity == 1)
        #expect(first.unitPrice == 53.7)
        #expect(first.status == "Delivered")
        #expect(lines[1].vendor == "PA Dental")
        #expect(lines[1].quantity == 5)
        #expect(lines[1].unitPrice == 1017.3)
        #expect(browser.ordersFound == 3)
    }

    @Test func tdscReadsEachOrderAndTurnsLineTotalsIntoUnitPrices() async throws {
        let page = """
        <html><body><script>
        const pages = {
          "orders?page=0": '<a href="/my-account/order/2002">Order Details</a><a href="/my-account/order/2002">x</a><a href="/my-account/order/1001">Order Details</a>',
          "orders?page=1": '<a href="/my-account/order/2002">Order Details</a>',
          "order/2002": `<div><span class="item-label">Order Number</span><span>2002</span></div>
            <div><span class="item-label">Date Placed</span><span>Oct 9, 2026, 9:47 AM</span></div>
            <b>Status:</b> Completed    <div class="order-confirmation__order-info">
            <div class="order-details__row-full"><div class="order-confirmation__order-details">
              <a>Lidocaine HCl 2% and Epinephrine</a><div class="order-details__mfr-container">MFR #: 12345</div>
              <div class="price-line details"><div>$1,229.20</div><div class="order-confirmation__order-quantity">
              <div class="order-details__item-qty-container"><span class="order-details__item-qty">Qty: 2</span></div></div></div>
              <a class="returnPolicy">Read the Return Policy</a></div></div></div>`,
        };
        window.fetch = async (address) => {
          const key = Object.keys(pages).find((candidate) => address.includes(candidate));
          return { ok: true, status: 200, url: address, text: async () => pages[key] ?? "" };
        };
        </script></body></html>
        """
        let browser = SupplierBrowser(supplier: .tdsc)
        try await browser.loadHTML(page, baseURL: URL(string: "https://store.example/"))
        let lines = try await browser.collectFromService(knownOrders: ["1001"])
        #expect(browser.ordersFound == 2)
        #expect(lines.count == 1)
        let first = try #require(lines.first)
        #expect(first.date == "2026-10-09")
        #expect(first.suborderNumber == "2002")
        #expect(first.name == "Lidocaine HCl 2% and Epinephrine")
        #expect(first.manuCode == "12345")
        #expect(first.quantity == 2)
        #expect(first.unitPrice == 614.6)
        #expect(first.status == "Completed")
    }

    @Test func frontierFollowsTheOrdersLinkAndSkipsMarketingInserts() async throws {
        let page = """
        <html><body><a href="/us/en/my-account/orders/abc123">Go to My Orders</a><script>
        const order = (number, placed, items) => `<div class="your-order"><div class="order-box-header"><div class="row">
          <div>Order placed <span class="d-block font-weight-bold">${placed}</span></div>
          <div>Order <span class="d-block font-weight-bold">${number}</span></div>
          <div>Status <span class="d-block font-weight-bold">Completed</span></div></div></div>${items}</div>`;
        const item = (name, code, quantity, price) => `<div class="pro-details"><a class="text-info">${name}</a>
          <small class="product-brand">Code: ${code}</small><div>Qty: ${quantity}</div>
          <div class="product-price"><del>$99.99</del><span class="special">${price}</span></div></div>`;
        window.fetch = async (address) => ({ ok: true, status: 200, url: address, text: async () =>
          order("FW200", "Aug 12, 2026", item("Cook-Waite Lidocaine", "102-1234AB", 2, "$1,042.99") + item("Frontier Marketing - August Flyer", "", 1, "$0.00"))
          + order("FW100", "Jul 1, 2026", item("Old Thing", "1", 1, "$1.00")) });
        </script></body></html>
        """
        let browser = SupplierBrowser(supplier: .frontier)
        try await browser.loadHTML(page, baseURL: URL(string: "https://store.example/"))
        let lines = try await browser.collectFromService(knownOrders: ["FW100"])
        #expect(browser.ordersFound == 2)
        #expect(lines.count == 1)
        let first = try #require(lines.first)
        #expect(first.date == "2026-08-12")
        #expect(first.suborderNumber == "FW200")
        #expect(first.name == "Cook-Waite Lidocaine")
        #expect(first.manuCode == "102-1234AB")
        #expect(first.quantity == 2)
        #expect(first.unitPrice == 1042.99)
    }

    @Test func frontierWithoutAnOrdersLinkAsksForSignIn() async throws {
        let browser = SupplierBrowser(supplier: .frontier)
        try await browser.loadHTML("<html><body><a>LOGIN</a></body></html>")
        await #expect(throws: ImportFailure.self) {
            try await browser.collectFromService(knownOrders: [])
        }
    }
}
