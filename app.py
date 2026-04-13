from flask import Flask, jsonify, request, render_template
import json
import os
import uuid
from datetime import datetime, date

app = Flask(__name__)
DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")


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


def main():
    os.makedirs(DATA_DIR, exist_ok=True)
    app.run(debug=True, port=5050)


if __name__ == "__main__":
    main()
