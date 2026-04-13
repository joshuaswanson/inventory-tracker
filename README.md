# Inventory Tracker

A dental inventory tracking web app. Track supplies, vendors, purchases, and usage with automatic reorder alerts and expiration warnings.

## Features

- **Items** - Track inventory with units, reorder levels, and perishability
- **Vendors** - Store contact info and view purchase history per vendor
- **Purchases** - Record orders with pricing, lot numbers, and expiration dates
- **Usage** - Log consumption to calculate usage rates and predict reorder dates
- **Dashboard** - Overview of stock levels, low stock alerts, expiring items, and inventory value

## Getting Started

Requires Python 3.

**Option 1:** Double-click `start.command` to launch the app and open your browser.

**Option 2:** Run manually:

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python3 app.py
```

Then open http://localhost:5050.

To load sample data:

```bash
python3 seed.py
```

## Support

If you find this useful, [buy me a coffee](https://buymeacoffee.com/swanson).

<img src="assets/bmc_qr.png" alt="Buy Me a Coffee QR" width="200">
