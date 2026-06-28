from flask import Flask, jsonify, request, render_template
import json
import os
import re
import gzip
import subprocess
import uuid
import threading
import time
import http.cookiejar
import urllib.parse
import urllib.request
import urllib.error
from datetime import datetime, date
from bs4 import BeautifulSoup

REPO_DIR = os.path.dirname(os.path.abspath(__file__))

app = Flask(__name__)
DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")

# ── Heartbeat / auto-shutdown ────────────────────────────

last_heartbeat = time.time()
HEARTBEAT_TIMEOUT = 15


def watchdog():
    while True:
        time.sleep(5)
        if time.time() - last_heartbeat > HEARTBEAT_TIMEOUT:
            os._exit(0)


@app.route("/api/heartbeat", methods=["POST"])
def heartbeat():
    global last_heartbeat
    last_heartbeat = time.time()
    return "", 204


# ── Update check / git pull ──────────────────────────────

def git(*args, timeout=10):
    return subprocess.run(["git", "-C", REPO_DIR, *args], capture_output=True, text=True, timeout=timeout)


@app.route("/api/check-update")
def check_update():
    try:
        fetch = git("fetch", "--quiet", timeout=15)
        if fetch.returncode != 0:
            return jsonify({"updateAvailable": False})
        local = git("rev-parse", "HEAD").stdout.strip()
        remote = git("rev-parse", "@{u}").stdout.strip()
        if not local or not remote or local == remote:
            return jsonify({"updateAvailable": False})
        log = git("log", "--oneline", f"{local}..{remote}").stdout.strip()
        commits = [line for line in log.split("\n") if line]
        return jsonify({"updateAvailable": True, "commitCount": len(commits), "commits": commits[:5]})
    except Exception:
        return jsonify({"updateAvailable": False})


@app.route("/api/update", methods=["POST"])
def do_update():
    try:
        result = git("pull", "--ff-only", timeout=30)
        if result.returncode != 0:
            return jsonify({"success": False, "error": result.stderr.strip()}), 500
        return jsonify({"success": True})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ── Storage helpers ──────────────────────────────────────────

def load(filename):
    path = os.path.join(DATA_DIR, filename)
    if not os.path.exists(path):
        return []
    with open(path) as f:
        return json.load(f)


def save(filename, data):
    os.makedirs(DATA_DIR, exist_ok=True)
    with open(os.path.join(DATA_DIR, filename), "w") as f:
        json.dump(data, f, indent=2, default=str)


def find(collection, id):
    return next((x for x in collection if x["id"] == id), None)


# ── Pages ────────────────────────────────────────────────────

@app.route("/")
def index():
    return render_template("index.html")


# ── Items API ────────────────────────────────────────────────

def enrich_item(item):
    purchases = [p for p in load("purchases.json") if p["itemId"] == item["id"]]
    usage = [u for u in load("usage.json") if u["itemId"] == item["id"]]
    vendors = load("vendors.json")

    total_purchased = sum(p["quantity"] for p in purchases)
    total_used = sum(u["quantity"] for u in usage)
    item["currentInventory"] = total_purchased - total_used
    item["needsReorder"] = item["currentInventory"] <= item["reorderLevel"]

    if purchases:
        prices = [p["pricePerUnit"] for p in purchases]
        item["lowestPrice"] = min(prices)
        item["averagePrice"] = round(sum(prices) / len(prices), 2)
        best = min(purchases, key=lambda p: p["pricePerUnit"])
        v = find(vendors, best.get("vendorId", ""))
        item["bestPriceVendor"] = v["name"] if v else None
    else:
        item["lowestPrice"] = None
        item["averagePrice"] = None
        item["bestPriceVendor"] = None

    if len(usage) >= 2:
        sorted_u = sorted(usage, key=lambda u: u["date"])
        d0 = date.fromisoformat(sorted_u[0]["date"])
        d1 = date.fromisoformat(sorted_u[-1]["date"])
        days = (d1 - d0).days
        if days > 0:
            rate = total_used / days
            item["usageRatePerDay"] = round(rate, 2)
            excess = item["currentInventory"] - item["reorderLevel"]
            item["daysUntilReorder"] = max(0, int(excess / rate)) if rate > 0 else None
        else:
            item["usageRatePerDay"] = 0
            item["daysUntilReorder"] = None
    else:
        item["usageRatePerDay"] = 0
        item["daysUntilReorder"] = None

    if item.get("isPerishable"):
        expiring = [p for p in purchases if p.get("expirationDate")]
        today = date.today().isoformat()
        future = [p for p in expiring if p["expirationDate"] >= today]
        if future:
            nxt = min(future, key=lambda p: p["expirationDate"])
            exp = date.fromisoformat(nxt["expirationDate"])
            item["nextExpiration"] = nxt["expirationDate"]
            item["daysUntilExpiration"] = (exp - date.today()).days
        else:
            item["nextExpiration"] = None
            item["daysUntilExpiration"] = None

    item["recentPurchases"] = sorted(purchases, key=lambda p: p["date"], reverse=True)[:5]
    item["recentUsage"] = sorted(usage, key=lambda u: u["date"], reverse=True)[:5]

    for p in item["recentPurchases"]:
        v = find(vendors, p.get("vendorId", ""))
        p["vendorName"] = v["name"] if v else ""

    return item


@app.route("/api/items", methods=["GET"])
def get_items():
    return jsonify([enrich_item(i) for i in load("items.json")])


@app.route("/api/items/<id>", methods=["GET"])
def get_item(id):
    item = find(load("items.json"), id)
    if not item:
        return jsonify({"error": "Not found"}), 404
    return jsonify(enrich_item(item))


@app.route("/api/items", methods=["POST"])
def create_item():
    d = request.json
    items = load("items.json")
    item = {
        "id": str(uuid.uuid4()),
        "name": d["name"],
        "unit": d.get("unit", "each"),
        "reorderLevel": int(d.get("reorderLevel", 10)),
        "isPerishable": bool(d.get("isPerishable", False)),
        "storageLocation": d.get("storageLocation", ""),
        "notes": d.get("notes", ""),
        "createdAt": datetime.now().isoformat(),
    }
    items.append(item)
    save("items.json", items)
    return jsonify(item), 201


@app.route("/api/items/<id>", methods=["PUT"])
def update_item(id):
    items = load("items.json")
    item = find(items, id)
    if not item:
        return jsonify({"error": "Not found"}), 404
    d = request.json
    for key in ["name", "unit", "reorderLevel", "isPerishable", "storageLocation", "notes"]:
        if key in d:
            item[key] = d[key]
    if "reorderLevel" in d:
        item["reorderLevel"] = int(d["reorderLevel"])
    if "isPerishable" in d:
        item["isPerishable"] = bool(d["isPerishable"])
    save("items.json", items)
    return jsonify(item)


@app.route("/api/items/<id>", methods=["DELETE"])
def delete_item(id):
    items = load("items.json")
    items = [i for i in items if i["id"] != id]
    save("items.json", items)
    purchases = load("purchases.json")
    purchases = [p for p in purchases if p["itemId"] != id]
    save("purchases.json", purchases)
    usage = load("usage.json")
    usage = [u for u in usage if u["itemId"] != id]
    save("usage.json", usage)
    return "", 204


# ── Vendors API ──────────────────────────────────────────────

def enrich_vendor(vendor):
    purchases = [p for p in load("purchases.json") if p.get("vendorId") == vendor["id"]]
    items = load("items.json")
    vendor["totalPurchases"] = len(purchases)
    vendor["totalSpent"] = round(sum(p["quantity"] * p["pricePerUnit"] for p in purchases), 2)
    recent = sorted(purchases, key=lambda p: p["date"], reverse=True)[:5]
    for p in recent:
        itm = find(items, p["itemId"])
        p["itemName"] = itm["name"] if itm else "Unknown"
    vendor["recentPurchases"] = recent
    return vendor


@app.route("/api/vendors", methods=["GET"])
def get_vendors():
    return jsonify([enrich_vendor(v) for v in load("vendors.json")])


@app.route("/api/vendors", methods=["POST"])
def create_vendor():
    d = request.json
    vendors = load("vendors.json")
    vendor = {
        "id": str(uuid.uuid4()),
        "name": d["name"],
        "contactName": d.get("contactName", ""),
        "phone": d.get("phone", ""),
        "email": d.get("email", ""),
        "address": d.get("address", ""),
        "notes": d.get("notes", ""),
        "createdAt": datetime.now().isoformat(),
    }
    vendors.append(vendor)
    save("vendors.json", vendors)
    return jsonify(vendor), 201


@app.route("/api/vendors/<id>", methods=["PUT"])
def update_vendor(id):
    vendors = load("vendors.json")
    vendor = find(vendors, id)
    if not vendor:
        return jsonify({"error": "Not found"}), 404
    d = request.json
    for key in ["name", "contactName", "phone", "email", "address", "notes"]:
        if key in d:
            vendor[key] = d[key]
    save("vendors.json", vendors)
    return jsonify(vendor)


@app.route("/api/vendors/<id>", methods=["DELETE"])
def delete_vendor(id):
    vendors = load("vendors.json")
    vendors = [v for v in vendors if v["id"] != id]
    save("vendors.json", vendors)
    purchases = load("purchases.json")
    for p in purchases:
        if p.get("vendorId") == id:
            p["vendorId"] = None
    save("purchases.json", purchases)
    return "", 204


# ── Purchases API ────────────────────────────────────────────

def enrich_purchase(p):
    items = load("items.json")
    vendors = load("vendors.json")
    itm = find(items, p["itemId"])
    v = find(vendors, p.get("vendorId", ""))
    p["itemName"] = itm["name"] if itm else "Unknown"
    p["itemUnit"] = itm["unit"] if itm else "each"
    p["vendorName"] = v["name"] if v else ""
    p["totalCost"] = round(p["quantity"] * p["pricePerUnit"], 2)
    return p


@app.route("/api/purchases", methods=["GET"])
def get_purchases():
    return jsonify([enrich_purchase(p) for p in load("purchases.json")])


@app.route("/api/purchases", methods=["POST"])
def create_purchase():
    d = request.json
    purchases = load("purchases.json")
    purchase = {
        "id": str(uuid.uuid4()),
        "date": d["date"],
        "itemId": d["itemId"],
        "vendorId": d.get("vendorId"),
        "quantity": int(d["quantity"]),
        "pricePerUnit": float(d["pricePerUnit"]),
        "lotNumber": d.get("lotNumber", ""),
        "expirationDate": d.get("expirationDate"),
        "notes": d.get("notes", ""),
    }
    purchases.append(purchase)
    save("purchases.json", purchases)
    return jsonify(purchase), 201


@app.route("/api/purchases/<id>", methods=["PUT"])
def update_purchase(id):
    purchases = load("purchases.json")
    p = find(purchases, id)
    if not p:
        return jsonify({"error": "Not found"}), 404
    d = request.json
    for key in ["date", "itemId", "vendorId", "quantity", "pricePerUnit", "lotNumber", "expirationDate", "notes"]:
        if key in d:
            p[key] = d[key]
    if "quantity" in d:
        p["quantity"] = int(d["quantity"])
    if "pricePerUnit" in d:
        p["pricePerUnit"] = float(d["pricePerUnit"])
    save("purchases.json", purchases)
    return jsonify(p)


@app.route("/api/purchases/<id>", methods=["DELETE"])
def delete_purchase(id):
    purchases = load("purchases.json")
    purchases = [p for p in purchases if p["id"] != id]
    save("purchases.json", purchases)
    return "", 204


# ── Usage API ────────────────────────────────────────────────

def enrich_usage(u):
    items = load("items.json")
    itm = find(items, u["itemId"])
    u["itemName"] = itm["name"] if itm else "Unknown"
    u["itemUnit"] = itm["unit"] if itm else "each"
    return u


@app.route("/api/usage", methods=["GET"])
def get_usage():
    return jsonify([enrich_usage(u) for u in load("usage.json")])


@app.route("/api/usage", methods=["POST"])
def create_usage():
    d = request.json
    records = load("usage.json")
    record = {
        "id": str(uuid.uuid4()),
        "date": d["date"],
        "itemId": d["itemId"],
        "quantity": int(d["quantity"]),
        "notes": d.get("notes", ""),
        "isEstimate": bool(d.get("isEstimate", False)),
    }
    records.append(record)
    save("usage.json", records)
    return jsonify(record), 201


@app.route("/api/usage/<id>", methods=["PUT"])
def update_usage(id):
    records = load("usage.json")
    u = find(records, id)
    if not u:
        return jsonify({"error": "Not found"}), 404
    d = request.json
    for key in ["date", "itemId", "quantity", "notes", "isEstimate"]:
        if key in d:
            u[key] = d[key]
    if "quantity" in d:
        u["quantity"] = int(d["quantity"])
    if "isEstimate" in d:
        u["isEstimate"] = bool(d["isEstimate"])
    save("usage.json", records)
    return jsonify(u)


@app.route("/api/usage/<id>", methods=["DELETE"])
def delete_usage(id):
    records = load("usage.json")
    records = [u for u in records if u["id"] != id]
    save("usage.json", records)
    return "", 204


# ── Dashboard API ────────────────────────────────────────────

@app.route("/api/dashboard")
def dashboard():
    items = [enrich_item(i) for i in load("items.json")]
    vendors = load("vendors.json")
    purchases = load("purchases.json")

    low_stock = [i for i in items if i["needsReorder"]]
    expiring = [i for i in items if i.get("daysUntilExpiration") is not None and i["daysUntilExpiration"] <= 30]

    total_value = 0
    for i in items:
        if i["averagePrice"] and i["currentInventory"] > 0:
            total_value += i["averagePrice"] * i["currentInventory"]

    return jsonify({
        "totalItems": len(items),
        "totalVendors": len(vendors),
        "lowStockCount": len(low_stock),
        "expiringCount": len(expiring),
        "totalValue": round(total_value, 2),
        "lowStockItems": low_stock,
        "expiringItems": expiring,
        "recentPurchases": sorted(purchases, key=lambda p: p["date"], reverse=True)[:8],
    })


# ── SupplyClinic import ──────────────────────────────────────

SC_HOST = "https://www.supplyclinic.com"
SC_SIGNIN = f"{SC_HOST}/users/sign_in"
SC_ORDERS = f"{SC_HOST}/checkout/orders"
SC_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.5 Safari/605.1.15",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Accept-Encoding": "gzip",
}


def _sc_read(resp):
    raw = resp.read()
    if resp.headers.get("Content-Encoding") == "gzip":
        raw = gzip.decompress(raw)
    return raw.decode("utf-8", "replace")


def _sc_get(opener, url):
    req = urllib.request.Request(url, headers=SC_HEADERS)
    return opener.open(req, timeout=30)


def _sc_is_blocked(body):
    markers = ["challenge-platform", "Just a moment", "cf-challenge", "Attention Required"]
    return any(m in body for m in markers)


def _sc_login(opener, email, password):
    """Log into SupplyClinic. Returns (ok, error_message)."""
    try:
        body = _sc_read(_sc_get(opener, SC_SIGNIN))
    except urllib.error.URLError:
        return False, "Couldn't reach SupplyClinic. Check your internet connection and try again."
    if _sc_is_blocked(body):
        return False, "SupplyClinic is temporarily blocking automated sign-in. Please try again in a few minutes."
    soup = BeautifulSoup(body, "html.parser")
    form = soup.find("form", attrs={"action": "/users/sign_in"})
    token_el = form.find("input", attrs={"name": "authenticity_token"}) if form else None
    token = token_el.get("value") if token_el else None
    if not token:
        return False, "Couldn't load the SupplyClinic sign-in page. Please try again later."
    data = urllib.parse.urlencode({
        "authenticity_token": token,
        "user[email]": email,
        "user[password]": password,
        "user[remember_me]": "1",
        "commit": "Sign in",
    }).encode()
    req = urllib.request.Request(
        SC_SIGNIN, data=data,
        headers={**SC_HEADERS, "Content-Type": "application/x-www-form-urlencoded", "Referer": SC_SIGNIN},
    )
    try:
        resp = opener.open(req, timeout=30)
    except urllib.error.URLError:
        return False, "Couldn't reach SupplyClinic. Check your internet connection and try again."
    result = _sc_read(resp)
    if "/users/sign_in" in resp.geturl() or 'name="user[password]"' in result:
        return False, "Sign in failed. Please double-check your SupplyClinic email and password."
    return True, None


def _sc_clean(text, *labels):
    t = (text or "").strip()
    for lab in labels:
        t = t.replace(lab, "")
    return t.strip()


def _sc_date(text):
    m = re.search(r"(\d{2})/(\d{2})/(\d{4})", text or "")
    return f"{m.group(3)}-{m.group(1)}-{m.group(2)}" if m else None


def _sc_money(text):
    m = re.search(r"\$([\d,]+\.\d{2})", text or "")
    return float(m.group(1).replace(",", "")) if m else None


def _sc_qty(text):
    m = re.search(r"(\d+)", text or "")
    return int(m.group(1)) if m else None


def _sc_unit(name):
    n = (name or "").lower()
    if re.search(r"/\s*(cs|case)\b", n) or "case" in n:
        return "case"
    if re.search(r"/\s*bx\b", n) or "box" in n:
        return "box"
    if "/pk" in n or "pkg" in n or "pack" in n:
        return "pack"
    if "bottle" in n:
        return "bottle"
    if "bag" in n:
        return "bag"
    if "roll" in n:
        return "roll"
    return "each"


def _sc_parse(body):
    soup = BeautifulSoup(body, "html.parser")
    lines = []
    for order in soup.select("div.order"):
        date_el = order.select_one(".order-date")
        date_iso = _sc_date(date_el.get_text(" ", strip=True) if date_el else "")
        for sub in order.select(".suborder"):
            vendor_el = sub.select_one(".suborder-vendor")
            vendor = _sc_clean(vendor_el.get_text(" ", strip=True) if vendor_el else "", "Items from")
            num_el = sub.select_one(".suborder-number")
            sub_number = _sc_clean(num_el.get_text(" ", strip=True) if num_el else "", "#")
            for it in sub.select(".historical-suborder-item"):
                def field(cls):
                    e = it.select_one("." + cls)
                    return e.get_text(" ", strip=True) if e else ""
                lines.append({
                    "date": date_iso,
                    "vendor": vendor,
                    "suborderNumber": sub_number,
                    "name": field("suborder-item-name"),
                    "manuCode": _sc_clean(field("suborder-item-manu"), "Manu Code:"),
                    "quantity": _sc_qty(field("suborder-item-quantity")),
                    "unitPrice": _sc_money(field("suborder-item-unit-price")),
                    "status": _sc_clean(field("suborder-item-status"), "Status:"),
                })
    return lines


SC_SESSION_FILE = os.path.join(DATA_DIR, ".sc_session.json")


def _sc_cookie_string(jar):
    return "; ".join(f"{c.name}={c.value}" for c in jar)


def _sc_save_session(cookie, email):
    try:
        os.makedirs(DATA_DIR, exist_ok=True)
        with open(SC_SESSION_FILE, "w") as f:
            json.dump({"cookie": cookie, "email": email, "savedAt": date.today().isoformat()}, f)
        os.chmod(SC_SESSION_FILE, 0o600)
    except OSError:
        pass


def _sc_load_session():
    try:
        with open(SC_SESSION_FILE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def _sc_clear_session():
    try:
        os.remove(SC_SESSION_FILE)
    except OSError:
        pass


def _sc_fetch_orders(cookie):
    """Fetch all order lines using a stored cookie. Returns (lines, authenticated)."""
    headers = {**SC_HEADERS, "Cookie": cookie}
    lines = []
    page = 1
    while page <= 50:
        url = SC_ORDERS if page == 1 else f"{SC_ORDERS}?page={page}"
        req = urllib.request.Request(url, headers=headers)
        resp = urllib.request.urlopen(req, timeout=30)
        body = _sc_read(resp)
        if page == 1 and ("/users/sign_in" in resp.geturl() or 'name="user[password]"' in body):
            return [], False
        page_lines = _sc_parse(body)
        if not page_lines:
            break
        lines.extend(page_lines)
        page += 1
    return lines, True


@app.route("/api/import/supplyclinic/status")
def import_supplyclinic_status():
    sess = _sc_load_session()
    return jsonify({
        "remembered": bool(sess and sess.get("cookie")),
        "email": (sess or {}).get("email", ""),
    })


@app.route("/api/import/supplyclinic", methods=["POST"])
def import_supplyclinic():
    d = request.json or {}
    email = (d.get("email") or "").strip()
    password = d.get("password") or ""

    if email and password:
        jar = http.cookiejar.CookieJar()
        opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
        ok, err = _sc_login(opener, email, password)
        if not ok:
            return jsonify({"error": err}), 401
        cookie = _sc_cookie_string(jar)
        _sc_save_session(cookie, email)
    else:
        sess = _sc_load_session()
        if not sess or not sess.get("cookie"):
            return jsonify({"error": "Please sign in to SupplyClinic.", "needLogin": True}), 401
        cookie = sess["cookie"]

    try:
        lines, authenticated = _sc_fetch_orders(cookie)
    except Exception:
        return jsonify({"error": "Couldn't read your order history. Please try again."}), 502

    if not authenticated:
        _sc_clear_session()
        return jsonify({
            "error": "Your saved SupplyClinic session expired. Please sign in again.",
            "needLogin": True,
        }), 401

    items = load("items.json")
    vendors = load("vendors.json")
    purchases = load("purchases.json")
    items_by_name = {i["name"].lower(): i for i in items}
    vendors_by_name = {v["name"].lower(): v for v in vendors}
    existing_sources = {p.get("sourceId") for p in purchases if p.get("sourceId")}

    today = date.today().isoformat()
    imported = 0
    duplicates = 0
    skipped = 0
    new_items = 0
    new_vendors = 0

    for ln in lines:
        status = (ln.get("status") or "").lower()
        if "cancel" in status or "return" in status:
            skipped += 1
            continue
        if not ln.get("name") or not ln.get("quantity") or ln.get("unitPrice") is None:
            skipped += 1
            continue

        source_id = f"supplyclinic:{ln['suborderNumber']}:{ln['manuCode'] or ln['name']}"
        if source_id in existing_sources:
            duplicates += 1
            continue

        vendor = vendors_by_name.get(ln["vendor"].lower())
        if not vendor and ln["vendor"]:
            vendor = {
                "id": str(uuid.uuid4()),
                "name": ln["vendor"],
                "contactName": "",
                "phone": "",
                "email": "",
                "address": "",
                "notes": "Imported from SupplyClinic",
                "createdAt": today,
            }
            vendors.append(vendor)
            vendors_by_name[ln["vendor"].lower()] = vendor
            new_vendors += 1

        item = items_by_name.get(ln["name"].lower())
        if not item:
            item = {
                "id": str(uuid.uuid4()),
                "name": ln["name"],
                "unit": _sc_unit(ln["name"]),
                "reorderLevel": 2,
                "isPerishable": False,
                "storageLocation": "",
                "notes": "Imported from SupplyClinic",
                "createdAt": today,
            }
            items.append(item)
            items_by_name[ln["name"].lower()] = item
            new_items += 1

        purchases.append({
            "id": str(uuid.uuid4()),
            "date": ln["date"],
            "itemId": item["id"],
            "vendorId": vendor["id"] if vendor else None,
            "quantity": ln["quantity"],
            "pricePerUnit": ln["unitPrice"],
            "lotNumber": ln["manuCode"],
            "expirationDate": None,
            "notes": f"SupplyClinic order {ln['suborderNumber']}",
            "sourceId": source_id,
        })
        existing_sources.add(source_id)
        imported += 1

    save("items.json", items)
    save("vendors.json", vendors)
    save("purchases.json", purchases)

    return jsonify({
        "imported": imported,
        "duplicates": duplicates,
        "skipped": skipped,
        "newItems": new_items,
        "newVendors": new_vendors,
    })


def main():
    os.makedirs(DATA_DIR, exist_ok=True)
    t = threading.Thread(target=watchdog, daemon=True)
    t.start()
    app.run(debug=True, port=5050)


if __name__ == "__main__":
    main()
