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
    /// Set when the orders page looks the same signed out, apart from missing this text.
    var signedInMarkup: String?
    /// Set when the site has its own order data service. The script runs on the orders page with
    /// `knownOrders` and returns `{ ordersFound, lines }`, or `{ signedOut: true }`.
    var collectScript: String?

    static let all = [supplyClinic, benco, elevate, dentalMarket, kettenbach, net32, tdsc, frontier]
    static let historyDays = 3 * 365

    static func withID(_ id: String) -> Supplier? {
        all.first { $0.id == id }
    }

    func isSignInPage(url: String, markup: String) -> Bool {
        url.contains(signInPath) || markup.contains(passwordFieldMarkup)
            || signedInMarkup.map { !markup.contains($0) } ?? false
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
        extractionScript: "",
        collectScript: #"""
        const parse = async (address) => {
          const response = await fetch(address, { credentials: "include" });
          return { document: new DOMParser().parseFromString(await response.text(), "text/html"), address: response.url ?? "" };
        };
        const isSignIn = (page) => /identity\.benco\.com/.test(page.address) || page.document.querySelector("#login-form");
        const day = (date) => date.toISOString().slice(0, 10);
        const today = new Date();
        const start = new Date(today.getTime() - \#(historyDays) * 86400000);
        const pad = (number) => String(number).padStart(2, "0");
        const readOrder = (document) => {
          const heading = document.body.textContent.replace(/\s+/g, " ").match(/Ordered on ([A-Za-z]+ \d{1,2}, \d{4})\s*\|\s*Order #\s*(\w+)/);
          if (!heading) return [];
          const ordered = new Date(heading[1]);
          const date = `${pad(ordered.getMonth() + 1)}/${pad(ordered.getDate())}/${ordered.getFullYear()}`;
          return [...document.querySelectorAll(".product-detail-area .product-details")].map((details) => {
            const value = (label) => {
              const row = [...details.querySelectorAll("p")].find((p) => p.textContent.trim().startsWith(label));
              return row ? row.textContent.replace(label, "").trim() : "";
            };
            return {
              date,
              vendor: "Benco Dental",
              suborderNumber: heading[2],
              name: (details.querySelector("strong a, strong")?.textContent ?? "").replace(/\s+/g, " ").trim(),
              manuCode: value("Product #:"),
              quantity: value("Quantity:"),
              unitPrice: value("Net Price:"),
              status: "",
            };
          });
        };
        const lines = [];
        const seen = new Set();
        for (let page = 1; page <= 80; page++) {
          const list = await parse(`${location.origin}/PurchaseHistory/NewIndex?DateRangeOption=CustomRange&OrderStatus=all&PageNumber=${page}&StartDate=${day(start)}&EndDate=${day(today)}`);
          if (isSignIn(list)) return JSON.stringify({ signedOut: true, ordersFound: 0, lines: [] });
          const orders = [...list.document.querySelectorAll(".order-container")].flatMap((order) => {
            const title = order.querySelector("h3.panel-title.pull-left")?.textContent ?? "";
            const number = (title.match(/Order #\s*(\w+)/) ?? [])[1];
            if (!number || seen.has(number)) return [];
            seen.add(number);
            return [{ number, isPurchase: /Merchandise/.test(title) }];
          });
          if (orders.length === 0) break;
          const unseen = orders.filter((order) => !knownOrders.includes(order.number));
          const purchases = unseen.filter((order) => order.isPurchase);
          const readWithRetry = async (order) => {
            let orderLines = [];
            for (let attempt = 0; attempt < 2 && orderLines.length === 0; attempt++) {
              orderLines = readOrder((await parse(`${location.origin}/PurchaseHistory/NewOrderDetail/${order.number}`)).document);
            }
            return orderLines;
          };
          for (let index = 0; index < purchases.length; index += 4) {
            const batch = await Promise.all(purchases.slice(index, index + 4).map(readWithRetry));
            lines.push(...batch.flat());
          }
          if (unseen.length === 0) break;
        }
        return JSON.stringify({ ordersFound: seen.size, lines });
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
        signInScript: signInScript(email: "#login-email", password: "#login-password"),
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

nonisolated extension Supplier {
    static let dentalMarket = bigCommerce(id: "dentalmarket", name: "The Dental Market", host: "thedentalmarket.net")

    /// Stores built on BigCommerce share the same account pages.
    static func bigCommerce(id: String, name: String, host: String) -> Supplier {
        Supplier(
            id: id,
            name: name,
            cookieDomain: host,
            ordersURL: URL(string: "https://\(host)/account.php?action=order_status")!,
            signInURL: URL(string: "https://\(host)/login.php")!,
            signInPath: "/login.php",
            passwordFieldMarkup: "name=\"login_pass\"",
            signInScript: #"""
            const passwordField = document.querySelector('input[name="login_pass"]');
            const form = passwordField?.form;
            const emailField = form?.querySelector('input[name="login_email"]');
            if (!form || !emailField) return false;
            for (const [field, value] of [[emailField, email], [passwordField, password]]) {
              field.value = value;
              field.dispatchEvent(new Event("input", { bubbles: true }));
              field.dispatchEvent(new Event("change", { bubbles: true }));
            }
            form.dataset.inventorySubmitted = "true";
            setTimeout(() => form.requestSubmit(), 0);
            return true;
            """#,
            submittedFormResetScript: #"""
            (() => {
              const form = document.querySelector("form[data-inventory-submitted]");
              if (!form) return true;
              return form.querySelector('input[name="login_pass"]')?.value === "";
            })()
            """#,
            extractionScript: "",
            collectScript: bigCommerceCollectScript.replacingOccurrences(of: "{vendor}", with: name)
        )
    }

    private static let bigCommerceCollectScript = #"""
    const parse = async (address) => {
      const response = await fetch(address, { credentials: "include" });
      return new DOMParser().parseFromString(await response.text(), "text/html");
    };
    const absolute = (link) => new URL(link.getAttribute("href"), location.origin);
    const months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
    const toDate = (text) => {
      const parts = text.match(/(\d{1,2})\D*\s+([A-Za-z]{3})[a-z]*\s+(\d{4})/);
      if (!parts) return "";
      const month = months.indexOf(parts[2].toLowerCase()) + 1;
      return `${String(month).padStart(2, "0")}/${parts[1].padStart(2, "0")}/${parts[3]}`;
    };
    const lines = [];
    let ordersFound = 0;
    let address = `${location.origin}/account.php?action=order_status`;
    for (let page = 0; page < 25 && address; page++) {
      const list = await parse(address);
      if (list.querySelector('input[name="login_pass"]')) {
        return JSON.stringify({ signedOut: true, ordersFound: 0, lines: [] });
      }
      for (const row of list.querySelectorAll(".account-listItem")) {
        const link = row.querySelector('a[href*="order_id"]');
        if (!link) continue;
        const orderNumber = absolute(link).searchParams.get("order_id");
        ordersFound += 1;
        if (knownOrders.includes(orderNumber)) continue;
        const placed = [...row.querySelectorAll(".account-product-detail")].find((detail) => /Order Placed/i.test(detail.textContent));
        const order = await parse(absolute(link).href);
        for (const item of order.querySelectorAll(".account-listItem")) {
          const title = (item.querySelector(".account-product-title")?.textContent ?? "").replace(/\s+/g, " ").trim();
          const counted = title.match(/^(\d+)\s*[×x]\s*(.+)$/);
          lines.push({
            date: toDate(placed?.querySelector("span")?.textContent ?? ""),
            vendor: "{vendor}",
            suborderNumber: orderNumber,
            name: counted ? counted[2] : title,
            manuCode: "",
            quantity: counted ? counted[1] : "1",
            unitPrice: (item.querySelector(".account-product-price")?.textContent ?? "").trim(),
            status: (row.querySelector(".account-orderStatus-label")?.textContent ?? "").trim(),
          });
        }
      }
      const next = list.querySelector(".pagination-item--next a");
      address = next ? absolute(next).href : null;
    }
    return JSON.stringify({ ordersFound, lines });
    """#
}

nonisolated extension Supplier {
    /// Fills a sign-in form in a way that sites built with React also notice, then submits it.
    /// `{email}` and `{password}` are the field selectors.
    private static let fillAndSubmitScript = #"""
    const waitFor = async (selector) => {
      for (let attempt = 0; attempt < 60; attempt++) {
        const element = document.querySelector(selector);
        if (element) return element;
        await new Promise((resolve) => setTimeout(resolve, 250));
      }
      return null;
    };
    const passwordField = await waitFor("{password}");
    const form = passwordField?.form;
    const emailField = form?.querySelector("{email}");
    if (!form || !emailField) return false;
    const setValue = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set;
    for (const [field, value] of [[emailField, email], [passwordField, password]]) {
      setValue.call(field, value);
      field.dispatchEvent(new Event("input", { bubbles: true }));
      field.dispatchEvent(new Event("change", { bubbles: true }));
    }
    const remember = form.querySelector("input[type='checkbox'][name*='remember' i], input[type='checkbox'][id*='remember' i]");
    if (remember && !remember.checked) remember.click();
    form.dataset.inventorySubmitted = "true";
    if (form.querySelector(".cf-turnstile, [name='cf-turnstile-response']")) {
      const passed = () => Boolean(form.querySelector("[name='cf-turnstile-response']")?.value);
      for (let attempt = 0; attempt < 24 && !passed(); attempt++) {
        await new Promise((resolve) => setTimeout(resolve, 250));
      }
      if (!passed()) return "check";
    }
    setTimeout(() => {
      const button = form.querySelector('[type="submit"]');
      if (button) button.click(); else form.requestSubmit();
    }, 0);
    return true;
    """#

    /// Hides everything on the page except the site's own check box and moves it to the top left corner.
    static let showOnlyHumanCheckScript = #"""
    (() => {
      const widget = document.querySelector("form[data-inventory-submitted] .cf-turnstile");
      if (!widget) return false;
      const style = document.createElement("style");
      style.textContent = `
        html, body { background: #fff !important; overflow: hidden !important; }
        body { visibility: hidden !important; }
        .cf-turnstile, .cf-turnstile * { visibility: visible !important; }
        form[data-inventory-submitted] .cf-turnstile {
          position: fixed !important; top: 0 !important; left: 0 !important; margin: 0 !important;
          z-index: 2147483647 !important; background: #fff !important;
        }`;
      document.head.appendChild(style);
      const box = widget.getBoundingClientRect();
      const isInCorner = Math.abs(box.top) < 2 && Math.abs(box.left) < 2 && box.height > 0;
      if (!isInCorner) style.remove();
      return isInCorner;
    })()
    """#

    /// Submits the filled-in form once the person has passed the site's own check.
    static let humanCheckScript = #"""
    (() => {
      const form = document.querySelector("form[data-inventory-submitted]");
      if (!form) return "gone";
      if (!form.querySelector("[name='cf-turnstile-response']")?.value) return "waiting";
      const button = form.querySelector('[type="submit"]');
      if (button) button.click(); else form.requestSubmit();
      return "submitted";
    })()
    """#

    private static func signInScript(email: String, password: String) -> String {
        fillAndSubmitScript
            .replacingOccurrences(of: "{email}", with: email)
            .replacingOccurrences(of: "{password}", with: password)
    }

    private static let passwordClearedScript = #"""
    (() => {
      const form = document.querySelector("form[data-inventory-submitted]");
      if (!form) return true;
      return form.querySelector('input[type="password"]')?.value === "";
    })()
    """#

    static let kettenbach = Supplier(
        id: "kettenbach",
        name: "Kettenbach",
        cookieDomain: "kettenbachusa",
        ordersURL: URL(string: "https://www.kettenbachusa.com/orders.aspx")!,
        signInURL: URL(string: "https://www.kettenbachusa.com/signin.aspx")!,
        signInPath: "/signin",
        passwordFieldMarkup: "sign-in-button-a",
        signInScript: signInScript(email: "#inputUsername", password: "#inputPassword"),
        submittedFormResetScript: passwordClearedScript,
        extractionScript: "",
        collectScript: #"""
        if (document.querySelector(".sign-in-button-a")) {
          return JSON.stringify({ signedOut: true, ordersFound: 0, lines: [] });
        }
        for (let attempt = 0; attempt < 40; attempt++) {
          if (document.querySelector("article.order") || !/Loading orders/i.test(document.body.textContent)) break;
          await new Promise((resolve) => setTimeout(resolve, 250));
        }
        const months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
        const lines = [];
        const orders = [...document.querySelectorAll("article.order")];
        for (const order of orders) {
          const text = order.textContent.replace(/\s+/g, " ");
          const placed = text.match(/Placed (\d{1,2}) ([A-Za-z]{3})[a-z]* (\d{4})/);
          const panel = order.closest("[id^='exp-']");
          const orderNumber = panel ? panel.id.replace(/^exp-/, "") : (text.match(/Order (\S+)/) ?? [])[1] ?? "";
          if (knownOrders.includes(orderNumber)) continue;
          const date = placed
            ? `${String(months.indexOf(placed[2].toLowerCase()) + 1).padStart(2, "0")}/${placed[1].padStart(2, "0")}/${placed[3]}`
            : "";
          for (const item of order.querySelectorAll(".items .item .meta")) {
            const meta = item.querySelector("small")?.textContent ?? "";
            lines.push({
              date,
              vendor: "Kettenbach",
              suborderNumber: orderNumber,
              name: (item.querySelector("strong")?.textContent ?? "").trim(),
              manuCode: ((meta.match(/SKU\s+([^•]+)/) ?? [])[1] ?? "").trim(),
              quantity: (meta.match(/Qty\s+(\d+)/) ?? [])[1] ?? "",
              unitPrice: (meta.match(/Price\s+(\$[\d,.]+)/) ?? [])[1] ?? "",
              status: "",
            });
          }
        }
        return JSON.stringify({ ordersFound: orders.length, lines });
        """#
    )

    static let tdsc = Supplier(
        id: "tdsc",
        name: "TDSC",
        cookieDomain: "tdsc",
        ordersURL: URL(string: "https://www.tdsc.com/my-account/orders")!,
        signInURL: URL(string: "https://www.tdsc.com/signin")!,
        signInPath: "/signin",
        passwordFieldMarkup: "id=\"j_password\"",
        signInScript: signInScript(email: "#j_username", password: "#j_password"),
        submittedFormResetScript: passwordClearedScript,
        extractionScript: "",
        collectScript: #"""
        const parse = async (address) => {
          const response = await fetch(address, { credentials: "include" });
          return { document: new DOMParser().parseFromString(await response.text(), "text/html"), address: response.url ?? "" };
        };
        const months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
        const toDate = (text) => {
          const parts = text.match(/([A-Za-z]{3})[a-z]* (\d{1,2}), (\d{4})/);
          if (!parts) return "";
          return `${String(months.indexOf(parts[1].toLowerCase()) + 1).padStart(2, "0")}/${parts[2].padStart(2, "0")}/${parts[3]}`;
        };
        const labelled = (root, label) => {
          const element = [...root.querySelectorAll(".item-label")].find((candidate) => candidate.textContent.trim() === label);
          const value = element?.nextElementSibling ?? element?.parentElement?.nextElementSibling;
          return (value?.textContent ?? "").replace(/\s+/g, " ").trim();
        };
        const lines = [];
        let ordersFound = 0;
        const seen = new Set();
        for (let page = 0; page < 40; page++) {
          const list = await parse(`${location.origin}/my-account/orders?page=${page}`);
          if (/\/signin/.test(list.address) || list.document.querySelector("#j_password")) {
            return JSON.stringify({ signedOut: true, ordersFound: 0, lines: [] });
          }
          const orderNumbers = [...new Set([...list.document.querySelectorAll("a")]
            .map((link) => (link.getAttribute("href") ?? "").match(/^\/my-account\/order\/(\d+)$/))
            .filter(Boolean)
            .map((match) => match[1]))]
            .filter((number) => !seen.has(number));
          if (orderNumbers.length === 0) break;
          let unseen = 0;
          for (const orderNumber of orderNumbers) {
            seen.add(orderNumber);
            ordersFound += 1;
            if (knownOrders.includes(orderNumber)) continue;
            unseen += 1;
            const order = (await parse(`${location.origin}/my-account/order/${orderNumber}`)).document;
            const date = toDate(labelled(order, "Date Placed"));
            const status = (order.body.textContent.match(/Status:\s*([A-Za-z ]+?)\s{2,}/) ?? [])[1] ?? "";
            for (const quantityLabel of order.querySelectorAll(".order-details__item-qty")) {
              let item = quantityLabel;
              for (let step = 0; step < 6 && item && !item.querySelector(".order-details__mfr-container"); step++) item = item.parentElement;
              if (!item) continue;
              const quantity = Number(quantityLabel.textContent.replace(/\D/g, ""));
              const total = [...item.querySelectorAll("div, span")]
                .map((element) => element.children.length === 0 ? element.textContent.trim() : "")
                .find((text) => /^\$[\d,]+\.\d\d$/.test(text));
              const amount = total ? Number(total.replace(/[$,]/g, "")) : NaN;
              const name = [...item.querySelectorAll("a")]
                .find((link) => !link.classList.contains("returnPolicy") && !link.className.includes("track") && link.textContent.trim());
              lines.push({
                date,
                vendor: "TDSC",
                suborderNumber: orderNumber,
                name: (name?.textContent ?? "").replace(/\s+/g, " ").trim(),
                manuCode: (item.querySelector(".order-details__mfr-container")?.textContent ?? "").replace(/MFR #:/, "").trim(),
                quantity: String(quantity || ""),
                unitPrice: quantity > 0 && !Number.isNaN(amount) ? `$${(amount / quantity).toFixed(2)}` : "",
                status,
              });
            }
          }
          if (unseen === 0) break;
        }
        return JSON.stringify({ ordersFound, lines });
        """#
    )

    static let frontier = Supplier(
        id: "frontier",
        name: "Frontier Dental",
        cookieDomain: "frontierdental",
        ordersURL: URL(string: "https://www.frontierdental.com/us/en/home")!,
        signInURL: URL(string: "https://www.frontierdental.com/us/en/login")!,
        signInPath: "/login",
        passwordFieldMarkup: "type=\"password\"",
        signInScript: signInScript(email: "#email", password: "#password"),
        submittedFormResetScript: passwordClearedScript,
        extractionScript: "",
        signedInMarkup: "/my-account/orders/",
        collectScript: #"""
        const ordersLink = document.querySelector('a[href*="/my-account/orders/"]');
        if (!ordersLink) {
          return JSON.stringify({ signedOut: true, ordersFound: 0, lines: [] });
        }
        const response = await fetch(ordersLink.href, { credentials: "include" });
        const page = new DOMParser().parseFromString(await response.text(), "text/html");
        const months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
        const toDate = (text) => {
          const parts = text.match(/([A-Za-z]{3})[a-z]* (\d{1,2}), (\d{4})/);
          if (!parts) return "";
          return `${String(months.indexOf(parts[1].toLowerCase()) + 1).padStart(2, "0")}/${parts[2].padStart(2, "0")}/${parts[3]}`;
        };
        const lines = [];
        const orders = [...page.querySelectorAll(".your-order")];
        for (const order of orders) {
          const cells = [...order.querySelectorAll(".order-box-header .row > div")].map((cell) => cell.textContent.replace(/\s+/g, " ").trim());
          const value = (label) => (cells.find((cell) => cell.toLowerCase().startsWith(label)) ?? "").slice(label.length).trim();
          const orderNumber = (cells.map((cell) => cell.match(/^Order\s+(?!placed|by)(\S+)/i)).find(Boolean) ?? [])[1] ?? "";
          if (!orderNumber || knownOrders.includes(orderNumber)) continue;
          const date = toDate(value("order placed"));
          const status = value("status");
          for (const details of order.querySelectorAll(".pro-details")) {
            const name = (details.querySelector("a.text-info")?.textContent ?? "").replace(/\s+/g, " ").trim();
            if (!name || /^Frontier Marketing/i.test(name)) continue;
            const price = details.querySelector(".product-price .special") ?? details.querySelector(".product-price");
            lines.push({
              date,
              vendor: "Frontier Dental",
              suborderNumber: orderNumber,
              name,
              manuCode: ((details.querySelector(".product-brand")?.textContent ?? "").match(/Code:\s*(\S+)/) ?? [])[1] ?? "",
              quantity: (details.textContent.match(/Qty:\s*(\d+)/) ?? [])[1] ?? "",
              unitPrice: (price?.textContent ?? "").trim(),
              status,
            });
          }
        }
        return JSON.stringify({ ordersFound: orders.length, lines });
        """#
    )

    static let net32 = Supplier(
        id: "net32",
        name: "Net32",
        cookieDomain: "net32",
        ordersURL: URL(string: "https://www.net32.com/account/orders")!,
        signInURL: URL(string: "https://www.net32.com/login")!,
        signInPath: "/login",
        passwordFieldMarkup: "login_form__",
        signInScript: signInScript(email: "#email-address", password: "#password"),
        submittedFormResetScript: passwordClearedScript,
        extractionScript: "",
        collectScript: #"""
        const parse = async (address) => {
          const response = await fetch(address, { credentials: "include" });
          return { document: new DOMParser().parseFromString(await response.text(), "text/html"), address: response.url ?? "" };
        };
        const text = (root, part) => (root.querySelector(`[class*="${part}"]`)?.textContent ?? "").replace(/\s+/g, " ").trim();
        const lines = [];
        let ordersFound = 0;
        for (let page = 1; page <= 40; page++) {
          const list = await parse(`${location.origin}/account/orders?pageNumber=${page}`);
          if (/\/login/.test(list.address) || list.document.querySelector('[class*="login_form"]')) {
            return JSON.stringify({ signedOut: true, ordersFound: 0, lines: [] });
          }
          const cards = [...list.document.querySelectorAll('[class*="ordersList_orderCard"]')];
          if (cards.length === 0) break;
          let unseen = 0;
          for (const card of cards) {
            const link = card.querySelector('a[href*="/account/orders/details/"]');
            if (!link) continue;
            const address = new URL(link.getAttribute("href"), location.origin);
            const orderNumber = address.pathname.split("/").pop();
            ordersFound += 1;
            if (knownOrders.includes(orderNumber)) continue;
            unseen += 1;
            const summary = card.textContent.replace(/\s+/g, " ");
            const placed = (summary.match(/Placed On\s*(\d{2}\/\d{2}\/\d{4})/) ?? [])[1] ?? "";
            const status = (summary.match(/Status\s*([A-Za-z ]+?)\s*(\(|Shipped To)/) ?? [])[1] ?? "";
            const order = await parse(address.href);
            for (const section of order.document.querySelectorAll('[class*="orderDetail_vendorSection"]')) {
              const vendor = (section.querySelector('[class*="ordersList_fulfilledByName"] strong')?.textContent ?? "").trim();
              for (const item of section.querySelectorAll('[class*="ordersList_lineItem"]')) {
                lines.push({
                  date: placed,
                  vendor,
                  suborderNumber: orderNumber,
                  name: text(item, "ordersList_itemName"),
                  manuCode: "",
                  quantity: text(item, "ordersList_itemQty"),
                  unitPrice: text(item, "ordersList_itemPrice"),
                  status,
                });
              }
            }
          }
          if (unseen === 0) break;
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
