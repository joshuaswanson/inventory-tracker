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

    static let all = [supplyClinic]

    static func withID(_ id: String) -> Supplier? {
        all.first { $0.id == id }
    }

    func isSignInPage(url: String, markup: String) -> Bool {
        url.contains(signInPath) || markup.contains(passwordFieldMarkup)
    }

    func ordersURL(page: Int) -> URL {
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
