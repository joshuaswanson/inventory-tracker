import Foundation

/// Everything that differs between supplier sites: where to go, how to recognize the sign-in
/// page, and the scripts that fill the sign-in form and read order lines.
nonisolated struct Supplier: Identifiable, Hashable {
    let id: String
    let name: String
    let cookieDomain: String
    let ordersURL: URL
    let signInURL: URL
    let signInPath: String
    let passwordFieldMarkup: String
    let signInScript: String
    let submittedFormResetScript: String
    let extractionScript: String
    var maxOrderPages = 50
    /// Placeholders: `{page0}` is the zero-based page, `{start}` and `{today}` are ISO days.
    var ordersPageTemplate: String?
    /// Set when the list only names orders and each order's lines are on its own page.
    var orderLinksScript: String?
    /// Set when the site has its own order data service. The script runs on the orders page with
    /// `knownOrders` and returns `{ ordersFound, lines }`, or `{ signedOut: true }`.
    var collectScript: String?

    static let all = [supplyClinic, benco, elevate]
    static let historyDays = 3 * 365

    static func withID(_ id: String) -> Supplier? {
        all.first { $0.id == id }
    }

    func isSignInPage(url: String, markup: String) -> Bool {
        url.contains(signInPath) || markup.contains(passwordFieldMarkup)
    }

    func ordersURL(page: Int, today: String = Day.today) -> URL {
        if let ordersPageTemplate {
            let address = ordersPageTemplate
                .replacingOccurrences(of: "{page0}", with: "\(page - 1)")
                .replacingOccurrences(of: "{start}", with: Day.offset(today, by: -Self.historyDays))
                .replacingOccurrences(of: "{today}", with: today)
            return URL(string: address) ?? ordersURL
        }
        guard page > 1 else { return ordersURL }
        return ordersURL.appending(queryItems: [URLQueryItem(name: "page", value: "\(page)")])
    }
}

nonisolated extension Supplier {
    static let supplyClinic = Supplier(
        id: "supplyclinic",
        name: "SupplyClinic",
        cookieDomain: "supplyclinic",
        ordersURL: URL(string: "https://www.supplyclinic.com/checkout/orders")!,
        signInURL: URL(string: "https://www.supplyclinic.com/users/sign_in")!,
        signInPath: "/users/sign_in",
        passwordFieldMarkup: "name=\"user[password]\"",
        signInScript: #"""
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
"""#,
        submittedFormResetScript: #"""
    (() => {
      const form = document.querySelector("form[data-inventory-submitted]");
      if (!form) return true;
      return form.querySelector('input[name="user[password]"]')?.value === "";
    })()
"""#,
        extractionScript: #"""
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
"""#
    )
}

nonisolated extension Supplier {
    static let benco = Supplier(
        id: "benco",
        name: "Benco Dental",
        cookieDomain: "benco",
        ordersURL: URL(string: "https://shop.benco.com/PurchaseHistory/NewIndex")!,
        signInURL: URL(string: "https://shop.benco.com/PurchaseHistory/NewIndex")!,
        signInPath: "identity.benco.com",
        passwordFieldMarkup: "id=\"login-form\"",
        signInScript: #"""
        const waitFor = async (selector) => {
          for (let attempt = 0; attempt < 40; attempt++) {
            const element = document.querySelector(selector);
            if (element) return element;
            await new Promise((resolve) => setTimeout(resolve, 250));
          }
          return null;
        };
        const form = await waitFor("#login-form");
        if (!form) return false;
        const fill = (selector, value) => {
          const field = form.querySelector(selector);
          if (!field) return false;
          field.value = value;
          field.dispatchEvent(new Event("input", { bubbles: true }));
          field.dispatchEvent(new Event("change", { bubbles: true }));
          return true;
        };
        if (!fill("#username", email) || !fill("#password", password)) return false;
        const remember = form.querySelector("#rememberMe");
        if (remember && !remember.checked) remember.click();
        form.dataset.inventorySubmitted = "true";
        setTimeout(() => form.requestSubmit(), 0);
        return true;
        """#,
        submittedFormResetScript: #"""
        (() => {
          const form = document.querySelector("form[data-inventory-submitted]");
          if (!form) return true;
          if (form.querySelector("#password")?.value === "") return true;
          return [...document.querySelectorAll(".alert, .error, .validation-summary-errors, [class*='error']")]
            .some((element) => element.offsetParent !== null && element.textContent.trim() !== "");
        })()
        """#,
        extractionScript: #"""
        (() => {
          const heading = document.body.innerText.match(/Ordered on ([A-Za-z]+ \d{1,2}, \d{4})\s*\|\s*Order #\s*(\w+)/);
          if (!heading) return JSON.stringify([]);
          const ordered = new Date(heading[1]);
          const pad = (number) => String(number).padStart(2, "0");
          const date = `${pad(ordered.getMonth() + 1)}/${pad(ordered.getDate())}/${ordered.getFullYear()}`;
          const lines = [];
          for (const details of document.querySelectorAll(".product-detail-area .product-details")) {
            const value = (label) => {
              const row = [...details.querySelectorAll("p")].find((p) => p.textContent.trim().startsWith(label));
              return row ? row.textContent.replace(label, "").trim() : "";
            };
            lines.push({
              date,
              vendor: "Benco Dental",
              suborderNumber: heading[2],
              name: (details.querySelector("strong a, strong")?.textContent ?? "").trim(),
              manuCode: value("Product #:"),
              quantity: value("Quantity:"),
              unitPrice: value("Net Price:"),
              status: "",
            });
          }
          return JSON.stringify(lines);
        })()
        """#,
        maxOrderPages: 60,
        ordersPageTemplate: "https://shop.benco.com/PurchaseHistory/NewIndex?DateRangeOption=CustomRange&OrderStatus=all&PageNumber={page0}&StartDate={start}&EndDate={today}",
        orderLinksScript: #"""
        (() => {
          const links = [];
          for (const order of document.querySelectorAll(".order-container")) {
            const title = order.querySelector("h3.panel-title.pull-left")?.textContent ?? "";
            const number = title.match(/Order #\s*(\w+)/);
            const link = order.querySelector('a[href*="NewOrderDetail"]');
            if (!number || !link) continue;
            links.push({ id: number[1], url: link.href, isPurchase: /Merchandise/.test(title) });
          }
          return JSON.stringify(links);
        })()
        """#
    )
}

nonisolated extension Supplier {
    static let elevate = Supplier(
        id: "elevate",
        name: "Elevate Oral Care",
        cookieDomain: "elevateoralcare",
        ordersURL: URL(string: "https://www.elevateoralcare.com/sca-dev-2023-1-0/my_account.ssp")!,
        signInURL: URL(string: "https://www.elevateoralcare.com/sca-dev-2023-1-0/my_account.ssp")!,
        signInPath: "is=login",
        passwordFieldMarkup: "login-register-login-form",
        signInScript: #"""
        const waitFor = async (selector) => {
          for (let attempt = 0; attempt < 60; attempt++) {
            const element = document.querySelector(selector);
            if (element) return element;
            await new Promise((resolve) => setTimeout(resolve, 250));
          }
          return null;
        };
        const passwordField = await waitFor('form input[type="password"]');
        const form = passwordField?.form;
        const emailField = form?.querySelector('input[name="email"], input[type="email"]');
        if (!form || !emailField) return false;
        for (const [field, value] of [[emailField, email], [passwordField, password]]) {
          field.value = value;
          field.dispatchEvent(new Event("input", { bubbles: true }));
          field.dispatchEvent(new Event("change", { bubbles: true }));
        }
        form.dataset.inventorySubmitted = "true";
        setTimeout(() => (form.querySelector('[type="submit"]') ?? form).click?.() ?? form.requestSubmit(), 0);
        return true;
        """#,
        submittedFormResetScript: #"""
        (() => {
          const form = document.querySelector("form[data-inventory-submitted]");
          if (!form) return true;
          if (form.querySelector('input[type="password"]')?.value === "") return true;
          return [...document.querySelectorAll(".global-views-message-error, [class*='error-message']")]
            .some((element) => element.offsetParent !== null && element.textContent.trim() !== "");
        })()
        """#,
        extractionScript: "",
        collectScript: #"""
        const base = location.pathname.replace(/my_account\.ssp.*/, "");
        const pageSize = 20;
        let signedOut = false;
        const get = async (query) => {
          const response = await fetch(`${base}services/OrderHistory.Service.ss?${query}`, {
            credentials: "include",
            headers: { "X-SC-Touchpoint": "customercenter" },
          });
          if (response.status === 401 || response.status === 403) signedOut = true;
          if (!response.ok) throw new Error(`Order service answered ${response.status}`);
          return response.json();
        };
        const lines = [];
        let ordersFound = 0;
        try {
          for (let page = 1; page <= 25; page++) {
            const list = await get(`page=${page}&results_per_page=${pageSize}`);
            const records = list.records ?? [];
            ordersFound += records.length;
            for (const record of records) {
              if (knownOrders.includes(record.tranid)) continue;
              const order = await get(`internalid=${record.internalid}&recordtype=${record.recordtype}`);
              const [month, day, year] = String(order.trandate).split("/");
              for (const line of order.lines ?? []) {
                const item = line.item ?? {};
                const number = String(item.displayname ?? "").match(/^(\S+) - /);
                lines.push({
                  date: `${month.padStart(2, "0")}/${day.padStart(2, "0")}/${year}`,
                  vendor: "Elevate Oral Care",
                  suborderNumber: String(order.tranid),
                  name: item.storedisplayname2 || item.displayname || item.itemid || "",
                  manuCode: number ? number[1] : String(item.itemid ?? ""),
                  quantity: String(line.quantity ?? ""),
                  unitPrice: line.rate_formatted ?? "",
                  status: order.status?.name ?? "",
                });
              }
            }
            if (records.length === 0 || page * pageSize >= Number(list.totalRecordsFound ?? 0)) break;
          }
        } catch (error) {
          if (signedOut) return JSON.stringify({ signedOut: true, ordersFound: 0, lines: [] });
          throw error;
        }
        return JSON.stringify({ ordersFound, lines });
        """#
    )
}

nonisolated enum SupplierSettings {
    private static let addedKey = "suppliersAdded"
    private static let legacySupplyClinicEmailKey = "supplyClinicEmail"

    static func added(in defaults: UserDefaults = .standard) -> [Supplier] {
        let ids = defaults.stringArray(forKey: addedKey) ?? [Supplier.supplyClinic.id]
        return ids.compactMap(Supplier.withID)
    }

    static func setAdded(_ suppliers: [Supplier], in defaults: UserDefaults = .standard) {
        defaults.set(suppliers.map(\.id), forKey: addedKey)
    }

    static func email(for supplier: Supplier, in defaults: UserDefaults = .standard) -> String {
        if let email = defaults.string(forKey: "supplierEmail.\(supplier.id)") { return email }
        return supplier == .supplyClinic ? defaults.string(forKey: legacySupplyClinicEmailKey) ?? "" : ""
    }

    static func setEmail(_ email: String, for supplier: Supplier, in defaults: UserDefaults = .standard) {
        defaults.set(email, forKey: "supplierEmail.\(supplier.id)")
    }

    static func lastImport(for supplier: Supplier, in defaults: UserDefaults = .standard) -> Date? {
        defaults.object(forKey: "supplierLastImport.\(supplier.id)") as? Date
    }

    static func setLastImport(_ date: Date, for supplier: Supplier, in defaults: UserDefaults = .standard) {
        defaults.set(date, forKey: "supplierLastImport.\(supplier.id)")
    }
}
