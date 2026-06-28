// ── State ────────────────────────────────────────────────

let state = {
  view: "dashboard",
  detailId: null,
  items: [],
  vendors: [],
  purchases: [],
  usage: [],
  dashboard: null,
  search: "",
  sort: { key: null, dir: "asc" },
  filter: "all",
  detailFrom: null,
  modalSaveHandler: null,
};

const UNITS = [
  { value: "each", label: "Each", abbr: "ea" },
  { value: "box", label: "Box", abbr: "bx" },
  { value: "case", label: "Case", abbr: "cs" },
  { value: "pack", label: "Pack", abbr: "pk" },
  { value: "bottle", label: "Bottle", abbr: "btl" },
  { value: "bag", label: "Bag", abbr: "bag" },
  { value: "roll", label: "Roll", abbr: "rl" },
  { value: "gallon", label: "Gallon", abbr: "gal" },
  { value: "liter", label: "Liter", abbr: "L" },
  { value: "pound", label: "Pound", abbr: "lb" },
  { value: "ounce", label: "Ounce", abbr: "oz" },
  { value: "gram", label: "Gram", abbr: "g" },
  { value: "kilogram", label: "Kilogram", abbr: "kg" },
  { value: "dozen", label: "Dozen", abbr: "dz" },
  { value: "pair", label: "Pair", abbr: "pr" },
  { value: "set", label: "Set", abbr: "set" },
];

function unitAbbr(val) {
  return UNITS.find((u) => u.value === val)?.abbr || val;
}

// ── API ─────────────────────────────────────────────────

const api = {
  async get(path) {
    const r = await fetch(`/api/${path}`);
    return r.json();
  },
  async post(path, data) {
    const r = await fetch(`/api/${path}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data),
    });
    return r.json();
  },
  async put(path, data) {
    const r = await fetch(`/api/${path}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data),
    });
    return r.json();
  },
  async del(path) {
    await fetch(`/api/${path}`, { method: "DELETE" });
  },
};

// ── Utils ───────────────────────────────────────────────

function $(sel, ctx = document) {
  return ctx.querySelector(sel);
}

function $$(sel, ctx = document) {
  return [...ctx.querySelectorAll(sel)];
}

function currency(n) {
  if (n == null) return "-";
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(n);
}

function fmtDate(d) {
  if (!d) return "-";
  const dt = new Date(d + "T00:00:00");
  return dt.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

function shortDate(d) {
  if (!d) return "-";
  const dt = new Date(d + "T00:00:00");
  return dt.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

function todayISO() {
  return new Date().toISOString().split("T")[0];
}

function html(strings, ...vals) {
  return strings.reduce((out, str, i) => out + str + (vals[i] ?? ""), "");
}

function stockBadge(item) {
  if (item.currentInventory <= 0)
    return `<span class="badge badge-red">Out of Stock</span>`;
  if (item.needsReorder)
    return `<span class="badge badge-amber">Low Stock</span>`;
  return `<span class="badge badge-green">In Stock</span>`;
}

function stockBar(item) {
  const max = Math.max(item.reorderLevel * 3, item.currentInventory, 1);
  const pct = Math.min(100, Math.round((item.currentInventory / max) * 100));
  let color = "var(--green)";
  if (item.currentInventory <= 0) color = "var(--red)";
  else if (item.needsReorder) color = "var(--amber)";
  return html`
    <div class="stock-bar-container">
      <span>${item.currentInventory} ${unitAbbr(item.unit)}</span>
      <div class="stock-bar">
        <div
          class="stock-bar-fill"
          style="width:${pct}%;background:${color}"
        ></div>
      </div>
    </div>
  `;
}

function expirationBadge(item) {
  if (!item.isPerishable || item.daysUntilExpiration == null) return "";
  const d = item.daysUntilExpiration;
  if (d <= 0) return `<span class="badge badge-red">Expired</span>`;
  if (d <= 7) return `<span class="badge badge-red">${d}d left</span>`;
  if (d <= 30) return `<span class="badge badge-amber">${d}d left</span>`;
  return `<span class="badge badge-green">${d}d left</span>`;
}

const ICON_EDIT = `<svg viewBox="0 0 20 20" fill="currentColor" width="16" height="16"><path d="M13.586 3.586a2 2 0 112.828 2.828l-.793.793-2.828-2.828.793-.793zM11.379 5.793L3 14.172V17h2.828l8.38-8.379-2.83-2.828z"/></svg>`;
const ICON_TRASH = `<svg viewBox="0 0 20 20" fill="currentColor" width="16" height="16"><path fill-rule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd"/></svg>`;


// ── Phone formatting ────────────────────────────────────

function formatPhone(phone) {
  if (!phone) return "";
  const digits = phone.replace(/\D/g, "");
  if (digits.length === 10) {
    return `(${digits.slice(0, 3)}) ${digits.slice(3, 6)}-${digits.slice(6)}`;
  }
  if (digits.length === 11 && digits[0] === "1") {
    return `+1 (${digits.slice(1, 4)}) ${digits.slice(4, 7)}-${digits.slice(7)}`;
  }
  return phone;
}

function stripPhone(phone) {
  return phone.replace(/\D/g, "");
}


export {
  state,
  UNITS,
  unitAbbr,
  api,
  $,
  $$,
  currency,
  fmtDate,
  shortDate,
  todayISO,
  html,
  stockBadge,
  stockBar,
  expirationBadge,
  ICON_EDIT,
  ICON_TRASH,
  formatPhone,
  stripPhone,
};
