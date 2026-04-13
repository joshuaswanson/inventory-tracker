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
  sortField: "name",
  sortDir: "asc",
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

// ── Modal ───────────────────────────────────────────────

let modalSaveHandler = null;

function openModal(title, bodyHtml, onSave) {
  $("#modal-title").textContent = title;
  $("#modal-body").innerHTML = bodyHtml;
  modalSaveHandler = onSave;
  $("#modal-overlay").classList.remove("hidden");
  const first = $("#modal-body input, #modal-body select");
  if (first) setTimeout(() => first.focus(), 50);
}

function closeModal() {
  $("#modal-overlay").classList.add("hidden");
  modalSaveHandler = null;
}

$("#modal-close").onclick = closeModal;
$("#modal-cancel").onclick = closeModal;
$("#modal-save").onclick = () => {
  if (modalSaveHandler) modalSaveHandler();
};
$("#modal-overlay").onclick = (e) => {
  if (e.target === e.currentTarget) closeModal();
};

// ── Confirm Dialog ──────────────────────────────────────

function confirm(message) {
  return new Promise((resolve) => {
    $("#confirm-message").textContent = message;
    $("#confirm-overlay").classList.remove("hidden");
    $("#confirm-yes").onclick = () => {
      $("#confirm-overlay").classList.add("hidden");
      resolve(true);
    };
    $("#confirm-no").onclick = () => {
      $("#confirm-overlay").classList.add("hidden");
      resolve(false);
    };
  });
}

// ── Router ──────────────────────────────────────────────

function navigate(view, detailId = null, filter = "all") {
  state.view = view;
  state.detailId = detailId;
  state.search = "";
  state.sort = { key: null, dir: "asc" };
  state.filter = filter;
  state.sortField = "name";
  state.sortDir = "asc";

  const hash = detailId ? `${view}/${detailId}` : view;
  history.replaceState(null, "", `#${hash}`);

  $$(".nav-item").forEach((el) => {
    el.classList.toggle(
      "active",
      el.dataset.view === view ||
        el.dataset.view === view.replace("-detail", ""),
    );
  });

  render();
}

window.addEventListener("hashchange", () => {
  const hash = location.hash.slice(1) || "dashboard";
  const parts = hash.split("/");
  navigate(parts[0], parts[1] || null);
});

// ── Render ──────────────────────────────────────────────

async function render() {
  const main = $("#content");

  switch (state.view) {
    case "dashboard":
      await renderDashboard(main);
      break;
    case "items":
      await renderItems(main);
      break;
    case "item-detail":
      await renderItemDetail(main, state.detailId);
      break;
    case "vendors":
      await renderVendors(main);
      break;
    case "vendor-detail":
      await renderVendorDetail(main, state.detailId);
      break;
    case "purchases":
      await renderPurchases(main);
      break;
    case "usage":
      await renderUsage(main);
      break;
  }
}

// ── Dashboard ───────────────────────────────────────────

async function renderDashboard(el) {
  const data = await api.get("dashboard");
  const items = await api.get("items");
  const vendors = await api.get("vendors");

  el.innerHTML = html`
    <div class="view-header">
      <h2>Dashboard</h2>
    </div>

    <div class="stats-grid">
      <div class="stat-card clickable" data-nav="items">
        <div class="stat-icon blue">
          <svg viewBox="0 0 20 20" fill="currentColor" width="20" height="20">
            <path d="M4 3a2 2 0 100 4h12a2 2 0 100-4H4z" />
            <path
              fill-rule="evenodd"
              d="M3 8h14v7a2 2 0 01-2 2H5a2 2 0 01-2-2V8zm5 3a1 1 0 011-1h2a1 1 0 110 2H9a1 1 0 01-1-1z"
              clip-rule="evenodd"
            />
          </svg>
        </div>
        <span class="stat-label">Total Items</span>
        <span class="stat-value">${data.totalItems}</span>
      </div>
      <div class="stat-card clickable" data-nav="items" data-filter="low">
        <div class="stat-icon amber">
          <svg viewBox="0 0 20 20" fill="currentColor" width="20" height="20">
            <path
              fill-rule="evenodd"
              d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
              clip-rule="evenodd"
            />
          </svg>
        </div>
        <span class="stat-label">Low Stock</span>
        <span class="stat-value ${data.lowStockCount > 0 ? "text-amber" : ""}"
          >${data.lowStockCount}</span
        >
      </div>
      <div class="stat-card clickable" data-nav="items" data-filter="expiring">
        <div class="stat-icon red">
          <svg viewBox="0 0 20 20" fill="currentColor" width="20" height="20">
            <path
              fill-rule="evenodd"
              d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z"
              clip-rule="evenodd"
            />
          </svg>
        </div>
        <span class="stat-label">Expiring Soon</span>
        <span class="stat-value ${data.expiringCount > 0 ? "text-red" : ""}"
          >${data.expiringCount}</span
        >
      </div>
      <div class="stat-card clickable" data-nav="vendors">
        <div class="stat-icon purple">
          <svg viewBox="0 0 20 20" fill="currentColor" width="20" height="20">
            <path
              d="M4 4a2 2 0 012-2h8a2 2 0 012 2v12a1 1 0 01-1 1h-2a1 1 0 01-1-1v-2a1 1 0 00-1-1H9a1 1 0 00-1 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V4z"
            />
          </svg>
        </div>
        <span class="stat-label">Vendors</span>
        <span class="stat-value">${data.totalVendors}</span>
      </div>
      <div class="stat-card">
        <div class="stat-icon green">
          <svg viewBox="0 0 20 20" fill="currentColor" width="20" height="20">
            <path
              d="M8.433 7.418c.155-.103.346-.196.567-.267v1.698a2.305 2.305 0 01-.567-.267C8.07 8.34 8 8.114 8 8c0-.114.07-.34.433-.582zM11 12.849v-1.698c.22.071.412.164.567.267.364.243.433.468.433.582 0 .114-.07.34-.433.582a2.305 2.305 0 01-.567.267z"
            />
            <path
              fill-rule="evenodd"
              d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-13a1 1 0 10-2 0v.092a4.535 4.535 0 00-1.676.662C6.602 6.234 6 7.009 6 8c0 .99.602 1.765 1.324 2.246.48.32 1.054.545 1.676.662v1.941c-.391-.127-.68-.317-.843-.504a1 1 0 10-1.51 1.31c.562.649 1.413 1.076 2.353 1.253V15a1 1 0 102 0v-.092a4.535 4.535 0 001.676-.662C13.398 13.766 14 12.991 14 12c0-.99-.602-1.765-1.324-2.246A4.535 4.535 0 0011 9.092V7.151c.391.127.68.317.843.504a1 1 0 101.511-1.31c-.563-.649-1.413-1.076-2.354-1.253V5z"
              clip-rule="evenodd"
            />
          </svg>
        </div>
        <span class="stat-label">Inventory Value</span>
        <span class="stat-value text-sm text-green"
          >${currency(data.totalValue)}</span
        >
      </div>
    </div>

    <div class="dashboard-grid">
      <div class="detail-section">
        <h3>
          <svg viewBox="0 0 20 20" fill="var(--amber)" width="16" height="16">
            <path
              fill-rule="evenodd"
              d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
              clip-rule="evenodd"
            />
          </svg>
          Low Stock Alerts
        </h3>
        ${data.lowStockItems.length === 0
          ? '<p class="text-tertiary text-sm">All items are well-stocked.</p>'
          : `<ul class="alert-list">${data.lowStockItems
              .map(
                (i) => html`
                  <li
                    class="alert-item clickable"
                    data-nav="item-detail"
                    data-id="${i.id}"
                  >
                    <span class="alert-name">${i.name}</span>
                    <span class="alert-stock"
                      >${i.currentInventory} / ${i.reorderLevel}
                      ${unitAbbr(i.unit)}</span
                    >
                    ${stockBadge(i)}
                  </li>
                `,
              )
              .join("")}</ul>`}
      </div>

      <div class="detail-section">
        <h3>
          <svg viewBox="0 0 20 20" fill="var(--red)" width="16" height="16">
            <path
              fill-rule="evenodd"
              d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z"
              clip-rule="evenodd"
            />
          </svg>
          Expiring Soon
        </h3>
        ${data.expiringItems.length === 0
          ? '<p class="text-tertiary text-sm">Nothing expiring in the next 30 days.</p>'
          : `<ul class="alert-list">${data.expiringItems
              .map(
                (i) => html`
                  <li
                    class="alert-item clickable"
                    data-nav="item-detail"
                    data-id="${i.id}"
                  >
                    <span class="alert-name">${i.name}</span>
                    <span class="alert-stock"
                      >${shortDate(i.nextExpiration)}</span
                    >
                    ${expirationBadge(i)}
                  </li>
                `,
              )
              .join("")}</ul>`}
      </div>
    </div>
  `;

  // Clickable stat cards
  el.querySelectorAll(".stat-card.clickable").forEach((card) => {
    card.style.cursor = "pointer";
    card.addEventListener("click", () =>
      navigate(card.dataset.nav, null, card.dataset.filter || "all"),
    );
  });

  // Clickable alert items
  el.querySelectorAll(".alert-item.clickable").forEach((li) => {
    li.style.cursor = "pointer";
    li.addEventListener("click", () => navigate(li.dataset.nav, li.dataset.id));
  });
}

// ── Items List ──────────────────────────────────────────

async function renderItems(el) {
  state.items = await api.get("items");
  renderItemsInner(el);
}

function applyItemSort(items) {
  const key = state.sortField;
  const m = state.sortDir === "desc" ? -1 : 1;
  return [...items].sort((a, b) => {
    switch (key) {
      case "name":
        return a.name.localeCompare(b.name) * m;
      case "stock":
        return (a.currentInventory - b.currentInventory) * m;
      case "price":
        return ((a.averagePrice || 0) - (b.averagePrice || 0)) * m;
      case "added":
        return (a.createdAt || "").localeCompare(b.createdAt || "") * m;
      case "reorder":
        return (a.reorderLevel - b.reorderLevel) * m;
      default:
        return 0;
    }
  });
}

function renderItemsInner(el) {
  let items = state.items;

  if (state.search) {
    const q = state.search.toLowerCase();
    items = items.filter(
      (i) =>
        i.name.toLowerCase().includes(q) ||
        i.storageLocation.toLowerCase().includes(q),
    );
  }

  switch (state.filter) {
    case "low":
      items = items.filter((i) => i.needsReorder);
      break;
    case "out":
      items = items.filter((i) => i.currentInventory <= 0);
      break;
    case "expiring":
      items = items.filter(
        (i) => i.daysUntilExpiration != null && i.daysUntilExpiration <= 30,
      );
      break;
    case "perishable":
      items = items.filter((i) => i.isPerishable);
      break;
  }

  items = applyItemSort(items);

  const totalCount = state.items.length;
  const lowCount = state.items.filter((i) => i.needsReorder).length;
  const outCount = state.items.filter((i) => i.currentInventory <= 0).length;
  const expCount = state.items.filter(
    (i) => i.daysUntilExpiration != null && i.daysUntilExpiration <= 30,
  ).length;
  const perishCount = state.items.filter((i) => i.isPerishable).length;

  function fc(name, label, count) {
    const active = state.filter === name ? "active" : "";
    const badge = count > 0 ? ` (${count})` : "";
    return `<button class="filter-chip ${active}" data-filter="${name}">${label}${badge}</button>`;
  }

  el.innerHTML = html`
    <div class="view-header">
      <h2>Items</h2>
      <div class="view-header-actions">
        <input
          type="text"
          class="search-input"
          placeholder="Search items..."
          value="${state.search}"
        />
        <button class="btn btn-primary" id="add-item-btn">+ Add Item</button>
      </div>
    </div>
    <div class="toolbar">
      <div class="filter-chips">
        ${fc("all", "All", totalCount)} ${fc("low", "Low Stock", lowCount)}
        ${fc("out", "Out of Stock", outCount)}
        ${fc("expiring", "Expiring Soon", expCount)}
        ${fc("perishable", "Perishable", perishCount)}
      </div>
      <div class="sort-group">
        <select class="sort-select" id="items-sort-field">
          <option value="name" ${state.sortField === "name" ? "selected" : ""}>
            Name
          </option>
          <option
            value="stock"
            ${state.sortField === "stock" ? "selected" : ""}
          >
            Stock
          </option>
          <option
            value="price"
            ${state.sortField === "price" ? "selected" : ""}
          >
            Price
          </option>
          <option
            value="reorder"
            ${state.sortField === "reorder" ? "selected" : ""}
          >
            Reorder Level
          </option>
          <option
            value="added"
            ${state.sortField === "added" ? "selected" : ""}
          >
            Date Added
          </option>
        </select>
        <button
          class="sort-dir-btn"
          id="items-sort-dir"
          title="${state.sortDir === "asc" ? "Ascending" : "Descending"}"
        >
          ${state.sortDir === "asc"
            ? '<svg viewBox="0 0 20 20" fill="currentColor" width="16" height="16"><path fill-rule="evenodd" d="M5.293 7.707a1 1 0 010-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 01-1.414 1.414L11 5.414V17a1 1 0 11-2 0V5.414L6.707 7.707a1 1 0 01-1.414 0z" clip-rule="evenodd"/></svg>'
            : '<svg viewBox="0 0 20 20" fill="currentColor" width="16" height="16"><path fill-rule="evenodd" d="M14.707 12.293a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 111.414-1.414L9 14.586V3a1 1 0 012 0v11.586l2.293-2.293a1 1 0 011.414 0z" clip-rule="evenodd"/></svg>'}
        </button>
      </div>
    </div>
    ${items.length === 0
      ? html`
          <div class="empty-state">
            <h3>
              ${state.filter !== "all" || state.search
                ? "No matching items"
                : "No items yet"}
            </h3>
            <p>
              ${state.filter !== "all" || state.search
                ? "Try adjusting your filters or search."
                : "Add your first dental supply item to get started."}
            </p>
          </div>
        `
      : html`
          <div class="table-wrapper">
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Stock</th>
                  <th>Reorder At</th>
                  <th>Status</th>
                  <th>Location</th>
                  <th>Avg Price</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                ${items
                  .map(
                    (i) => html`
                      <tr class="clickable" data-id="${i.id}">
                        <td class="font-medium">${i.name}</td>
                        <td>${stockBar(i)}</td>
                        <td class="text-secondary">
                          ${i.reorderLevel} ${unitAbbr(i.unit)}
                        </td>
                        <td>${stockBadge(i)} ${expirationBadge(i)}</td>
                        <td class="text-secondary">
                          ${i.storageLocation || "-"}
                        </td>
                        <td>${currency(i.averagePrice)}</td>
                        <td class="text-right">
                          <button
                            class="btn-ghost btn-sm edit-item"
                            data-id="${i.id}"
                            title="Edit"
                          >
                            ${ICON_EDIT}
                          </button>
                          <button
                            class="btn-ghost btn-sm delete-item text-red"
                            data-id="${i.id}"
                            title="Delete"
                          >
                            ${ICON_TRASH}
                          </button>
                        </td>
                      </tr>
                    `,
                  )
                  .join("")}
              </tbody>
            </table>
          </div>
        `}
  `;

  bindSearch(el, () => renderItemsInner(el));

  el.querySelectorAll(".filter-chip").forEach((btn) => {
    btn.addEventListener("click", () => {
      state.filter = btn.dataset.filter;
      renderItemsInner(el);
    });
  });

  el.querySelector("#items-sort-field")?.addEventListener("change", (e) => {
    state.sortField = e.target.value;
    renderItemsInner(el);
  });
  el.querySelector("#items-sort-dir")?.addEventListener("click", () => {
    state.sortDir = state.sortDir === "asc" ? "desc" : "asc";
    renderItemsInner(el);
  });

  el.querySelector("#add-item-btn")?.addEventListener("click", () =>
    showItemForm(),
  );

  el.querySelectorAll("tr.clickable").forEach((tr) => {
    tr.addEventListener("click", (e) => {
      if (e.target.closest("button")) return;
      navigate("item-detail", tr.dataset.id);
    });
  });

  el.querySelectorAll(".edit-item").forEach((btn) => {
    btn.addEventListener("click", (e) => {
      e.stopPropagation();
      const item = state.items.find((i) => i.id === btn.dataset.id);
      showItemForm(item);
    });
  });

  el.querySelectorAll(".delete-item").forEach((btn) => {
    btn.addEventListener("click", async (e) => {
      e.stopPropagation();
      const item = state.items.find((i) => i.id === btn.dataset.id);
      if (
        await confirm(
          `Delete "${item.name}"? This will also remove its purchases and usage records.`,
        )
      ) {
        await api.del(`items/${item.id}`);
        await renderItems(el);
      }
    });
  });
}

// ── Item Detail ─────────────────────────────────────────

async function renderItemDetail(el, id) {
  const item = await api.get(`items/${id}`);
  if (!item || item.error) {
    navigate("items");
    return;
  }

  el.innerHTML = html`
    <div class="detail-header">
      <button class="back-btn" id="back-to-items">&larr; Items</button>
      <h2>${item.name}</h2>
      <div class="detail-actions">
        <button class="btn btn-secondary" id="edit-detail-item">Edit</button>
        <button class="btn btn-primary" id="add-purchase-from-detail">
          + Purchase
        </button>
        <button class="btn btn-primary" id="add-usage-from-detail">
          + Usage
        </button>
      </div>
    </div>

    <div class="stats-grid mb-24">
      <div class="stat-card">
        <span class="stat-label">Current Stock</span>
        <span
          class="stat-value ${item.needsReorder ? "text-amber" : "text-green"}"
          >${item.currentInventory}</span
        >
        <span class="stat-sub"
          >${unitAbbr(item.unit)} (reorder at ${item.reorderLevel})</span
        >
      </div>
      ${item.lowestPrice != null
        ? html`
            <div class="stat-card">
              <span class="stat-label">Best Price</span>
              <span class="stat-value text-green"
                >${currency(item.lowestPrice)}</span
              >
              <span class="stat-sub">${item.bestPriceVendor || ""}</span>
            </div>
          `
        : ""}
      ${item.averagePrice != null
        ? html`
            <div class="stat-card">
              <span class="stat-label">Avg Price</span>
              <span class="stat-value text-primary"
                >${currency(item.averagePrice)}</span
              >
              <span class="stat-sub">per ${unitAbbr(item.unit)}</span>
            </div>
          `
        : ""}
      ${item.usageRatePerDay > 0
        ? html`
            <div class="stat-card">
              <span class="stat-label">Usage Rate</span>
              <span class="stat-value text-purple"
                >${item.usageRatePerDay}/day</span
              >
              <span class="stat-sub"
                >${item.daysUntilReorder != null
                  ? item.daysUntilReorder + " days to reorder"
                  : ""}</span
              >
            </div>
          `
        : ""}
    </div>

    <div class="detail-grid">
      <div class="detail-section">
        <h3>Recent Purchases</h3>
        ${item.recentPurchases.length === 0
          ? '<p class="text-tertiary text-sm">No purchases recorded yet.</p>'
          : html`<table class="mini-table">
              <tbody>
                ${item.recentPurchases
                  .map(
                    (p) => html`
                      <tr>
                        <td>${shortDate(p.date)}</td>
                        <td class="text-secondary">${p.vendorName || "-"}</td>
                        <td class="text-right">
                          ${p.quantity} ${unitAbbr(item.unit)}
                        </td>
                        <td class="text-right font-medium">
                          ${currency(p.pricePerUnit)}
                        </td>
                      </tr>
                    `,
                  )
                  .join("")}
              </tbody>
            </table>`}
      </div>

      <div class="detail-section">
        <h3>Recent Usage</h3>
        ${item.recentUsage.length === 0
          ? '<p class="text-tertiary text-sm">No usage recorded yet.</p>'
          : html`<table class="mini-table">
              <tbody>
                ${item.recentUsage
                  .map(
                    (u) => html`
                      <tr>
                        <td>${shortDate(u.date)}</td>
                        <td class="text-right text-red">
                          -${u.quantity} ${unitAbbr(item.unit)}
                        </td>
                        <td class="text-secondary">
                          ${u.isEstimate ? "Est." : ""}
                        </td>
                      </tr>
                    `,
                  )
                  .join("")}
              </tbody>
            </table>`}
      </div>

      <div class="detail-section full-width">
        <h3>Details</h3>
        <div class="info-row">
          <span class="label">Unit</span
          ><span class="value"
            >${UNITS.find((u) => u.value === item.unit)?.label ||
            item.unit}</span
          >
        </div>
        <div class="info-row">
          <span class="label">Perishable</span
          ><span class="value">${item.isPerishable ? "Yes" : "No"}</span>
        </div>
        ${item.storageLocation
          ? html`<div class="info-row">
              <span class="label">Location</span
              ><span class="value">${item.storageLocation}</span>
            </div>`
          : ""}
        ${item.nextExpiration
          ? html`<div class="info-row">
              <span class="label">Next Expiration</span
              ><span class="value"
                >${fmtDate(item.nextExpiration)} ${expirationBadge(item)}</span
              >
            </div>`
          : ""}
        ${item.notes
          ? html`<div class="mt-8">
              <span class="label text-sm">Notes</span>
              <p class="notes-display mt-8">${item.notes}</p>
            </div>`
          : ""}
      </div>
    </div>
  `;

  $("#back-to-items").onclick = () => navigate("items");
  $("#edit-detail-item").onclick = () =>
    showItemForm(item, () => renderItemDetail(el, id));
  $("#add-purchase-from-detail").onclick = () => showPurchaseForm(null, id);
  $("#add-usage-from-detail").onclick = () => showUsageForm(null, id);
}

// ── Vendors List ────────────────────────────────────────

async function renderVendors(el) {
  state.vendors = await api.get("vendors");
  renderVendorsInner(el);
}

function applyVendorSort(vendors) {
  const key = state.sortField;
  const m = state.sortDir === "desc" ? -1 : 1;
  return [...vendors].sort((a, b) => {
    switch (key) {
      case "name":
        return a.name.localeCompare(b.name) * m;
      case "orders":
        return (a.totalPurchases - b.totalPurchases) * m;
      case "spent":
        return (a.totalSpent - b.totalSpent) * m;
      case "added":
        return (a.createdAt || "").localeCompare(b.createdAt || "") * m;
      default:
        return 0;
    }
  });
}

function renderVendorsInner(el) {
  let vendors = state.vendors;
  if (state.search) {
    const q = state.search.toLowerCase();
    vendors = vendors.filter(
      (v) =>
        v.name.toLowerCase().includes(q) ||
        v.contactName.toLowerCase().includes(q) ||
        v.email.toLowerCase().includes(q),
    );
  }

  switch (state.filter) {
    case "active":
      vendors = vendors.filter((v) => v.totalPurchases > 0);
      break;
    case "inactive":
      vendors = vendors.filter((v) => v.totalPurchases === 0);
      break;
    case "top":
      vendors = vendors.filter((v) => v.totalSpent > 0);
      break;
  }

  vendors = applyVendorSort(vendors);

  const totalCount = state.vendors.length;
  const activeCount = state.vendors.filter((v) => v.totalPurchases > 0).length;
  const inactiveCount = state.vendors.filter(
    (v) => v.totalPurchases === 0,
  ).length;

  function fc(name, label, count) {
    const active = state.filter === name ? "active" : "";
    const badge = count > 0 ? ` (${count})` : "";
    return `<button class="filter-chip ${active}" data-filter="${name}">${label}${badge}</button>`;
  }

  el.innerHTML = html`
    <div class="view-header">
      <h2>Vendors</h2>
      <div class="view-header-actions">
        <input
          type="text"
          class="search-input"
          placeholder="Search vendors..."
          value="${state.search}"
        />
        <button class="btn btn-primary" id="add-vendor-btn">
          + Add Vendor
        </button>
      </div>
    </div>
    <div class="toolbar">
      <div class="filter-chips">
        ${fc("all", "All", totalCount)} ${fc("active", "Active", activeCount)}
        ${fc("inactive", "No Orders", inactiveCount)}
      </div>
      <div class="sort-group">
        <select class="sort-select" id="vendors-sort-field">
          <option value="name" ${state.sortField === "name" ? "selected" : ""}>
            Name
          </option>
          <option
            value="orders"
            ${state.sortField === "orders" ? "selected" : ""}
          >
            Orders
          </option>
          <option
            value="spent"
            ${state.sortField === "spent" ? "selected" : ""}
          >
            Total Spent
          </option>
          <option
            value="added"
            ${state.sortField === "added" ? "selected" : ""}
          >
            Date Added
          </option>
        </select>
        <button
          class="sort-dir-btn"
          id="vendors-sort-dir"
          title="${state.sortDir === "asc" ? "Ascending" : "Descending"}"
        >
          ${state.sortDir === "asc"
            ? '<svg viewBox="0 0 20 20" fill="currentColor" width="16" height="16"><path fill-rule="evenodd" d="M5.293 7.707a1 1 0 010-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 01-1.414 1.414L11 5.414V17a1 1 0 11-2 0V5.414L6.707 7.707a1 1 0 01-1.414 0z" clip-rule="evenodd"/></svg>'
            : '<svg viewBox="0 0 20 20" fill="currentColor" width="16" height="16"><path fill-rule="evenodd" d="M14.707 12.293a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 111.414-1.414L9 14.586V3a1 1 0 012 0v11.586l2.293-2.293a1 1 0 011.414 0z" clip-rule="evenodd"/></svg>'}
        </button>
      </div>
    </div>
    ${vendors.length === 0
      ? html`
          <div class="empty-state">
            <h3>
              ${state.filter !== "all" || state.search
                ? "No matching vendors"
                : "No vendors yet"}
            </h3>
            <p>
              ${state.filter !== "all" || state.search
                ? "Try adjusting your filters or search."
                : "Add your dental suppliers to track purchases and spending."}
            </p>
          </div>
        `
      : html`
          <div class="table-wrapper">
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Contact</th>
                  <th>Phone</th>
                  <th>Email</th>
                  <th>Orders</th>
                  <th>Total Spent</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                ${vendors
                  .map(
                    (v) => html`
                      <tr class="clickable" data-id="${v.id}">
                        <td class="font-medium">${v.name}</td>
                        <td class="text-secondary">${v.contactName || "-"}</td>
                        <td class="text-secondary">
                          ${v.phone ? formatPhone(v.phone) : "-"}
                        </td>
                        <td class="text-secondary">${v.email || "-"}</td>
                        <td>${v.totalPurchases}</td>
                        <td class="text-green font-medium">
                          ${currency(v.totalSpent)}
                        </td>
                        <td class="text-right">
                          <button
                            class="btn-ghost btn-sm edit-vendor"
                            data-id="${v.id}"
                          >
                            ${ICON_EDIT}
                          </button>
                          <button
                            class="btn-ghost btn-sm delete-vendor text-red"
                            data-id="${v.id}"
                          >
                            ${ICON_TRASH}
                          </button>
                        </td>
                      </tr>
                    `,
                  )
                  .join("")}
              </tbody>
            </table>
          </div>
        `}
  `;

  bindSearch(el, () => renderVendorsInner(el));

  el.querySelectorAll(".filter-chip").forEach((btn) => {
    btn.addEventListener("click", () => {
      state.filter = btn.dataset.filter;
      renderVendorsInner(el);
    });
  });

  el.querySelector("#vendors-sort-field")?.addEventListener("change", (e) => {
    state.sortField = e.target.value;
    renderVendorsInner(el);
  });
  el.querySelector("#vendors-sort-dir")?.addEventListener("click", () => {
    state.sortDir = state.sortDir === "asc" ? "desc" : "asc";
    renderVendorsInner(el);
  });

  el.querySelector("#add-vendor-btn")?.addEventListener("click", () =>
    showVendorForm(),
  );

  el.querySelectorAll("tr.clickable").forEach((tr) => {
    tr.addEventListener("click", (e) => {
      if (e.target.closest("button")) return;
      navigate("vendor-detail", tr.dataset.id);
    });
  });

  el.querySelectorAll(".edit-vendor").forEach((btn) => {
    btn.addEventListener("click", (e) => {
      e.stopPropagation();
      showVendorForm(state.vendors.find((v) => v.id === btn.dataset.id));
    });
  });

  el.querySelectorAll(".delete-vendor").forEach((btn) => {
    btn.addEventListener("click", async (e) => {
      e.stopPropagation();
      const v = state.vendors.find((v) => v.id === btn.dataset.id);
      if (await confirm(`Delete vendor "${v.name}"?`)) {
        await api.del(`vendors/${v.id}`);
        await renderVendors(el);
      }
    });
  });
}

// ── Vendor Detail ───────────────────────────────────────

async function renderVendorDetail(el, id) {
  const vendors = await api.get("vendors");
  const vendor = vendors.find((v) => v.id === id);
  if (!vendor) {
    navigate("vendors");
    return;
  }

  el.innerHTML = html`
    <div class="detail-header">
      <button class="back-btn" id="back-to-vendors">&larr; Vendors</button>
      <h2>${vendor.name}</h2>
      <div class="detail-actions">
        <button class="btn btn-secondary" id="edit-detail-vendor">Edit</button>
      </div>
    </div>

    <div class="stats-grid mb-24">
      <div class="stat-card">
        <span class="stat-label">Total Orders</span>
        <span class="stat-value">${vendor.totalPurchases}</span>
      </div>
      <div class="stat-card">
        <span class="stat-label">Total Spent</span>
        <span class="stat-value text-green"
          >${currency(vendor.totalSpent)}</span
        >
      </div>
    </div>

    <div class="detail-grid">
      <div class="detail-section">
        <h3>Contact Info</h3>
        ${vendor.contactName
          ? html`<div class="info-row">
              <span class="label">Contact</span
              ><span class="value">${vendor.contactName}</span>
            </div>`
          : ""}
        ${vendor.phone
          ? html`<div class="info-row">
              <span class="label">Phone</span
              ><span class="value">${formatPhone(vendor.phone)}</span>
            </div>`
          : ""}
        ${vendor.email
          ? html`<div class="info-row">
              <span class="label">Email</span
              ><span class="value">${vendor.email}</span>
            </div>`
          : ""}
        ${vendor.address
          ? html`<div class="info-row">
              <span class="label">Address</span
              ><span class="value">${vendor.address}</span>
            </div>`
          : ""}
        ${!vendor.contactName &&
        !vendor.phone &&
        !vendor.email &&
        !vendor.address
          ? '<p class="text-tertiary text-sm">No contact info.</p>'
          : ""}
      </div>

      <div class="detail-section">
        <h3>Recent Purchases</h3>
        ${vendor.recentPurchases.length === 0
          ? '<p class="text-tertiary text-sm">No purchases from this vendor yet.</p>'
          : html`<table class="mini-table">
              <tbody>
                ${vendor.recentPurchases
                  .map(
                    (p) => html`
                      <tr>
                        <td>${shortDate(p.date)}</td>
                        <td>${p.itemName}</td>
                        <td class="text-right font-medium">
                          ${currency(p.pricePerUnit * p.quantity)}
                        </td>
                      </tr>
                    `,
                  )
                  .join("")}
              </tbody>
            </table>`}
      </div>

      ${vendor.notes
        ? html`
            <div class="detail-section full-width">
              <h3>Notes</h3>
              <p class="notes-display">${vendor.notes}</p>
            </div>
          `
        : ""}
    </div>
  `;

  $("#back-to-vendors").onclick = () => navigate("vendors");
  $("#edit-detail-vendor").onclick = () =>
    showVendorForm(vendor, () => renderVendorDetail(el, id));
}

// ── Purchases List ──────────────────────────────────────

async function renderPurchases(el) {
  state.purchases = await api.get("purchases");
  renderPurchasesInner(el);
}

function renderPurchasesInner(el) {
  let purchases = state.purchases;
  if (state.search) {
    const q = state.search.toLowerCase();
    purchases = purchases.filter(
      (p) =>
        (p.itemName || "").toLowerCase().includes(q) ||
        (p.vendorName || "").toLowerCase().includes(q),
    );
  }
  purchases = sortList(purchases);
  if (!state.sort.key) purchases.sort((a, b) => b.date.localeCompare(a.date));

  el.innerHTML = html`
    <div class="view-header">
      <h2>Purchases</h2>
      <div class="view-header-actions">
        <input
          type="text"
          class="search-input"
          placeholder="Search by item or vendor..."
          value="${state.search}"
        />
        <button class="btn btn-primary" id="add-purchase-btn">
          + Add Purchase
        </button>
      </div>
    </div>
    ${purchases.length === 0 && !state.search
      ? html`
          <div class="empty-state">
            <svg viewBox="0 0 20 20" fill="currentColor" width="48" height="48">
              <path
                d="M3 1a1 1 0 000 2h1.22l.305 1.222a.997.997 0 00.01.042l1.358 5.43-.893.892C3.74 11.846 4.632 14 6.414 14H15a1 1 0 000-2H6.414l1-1H14a1 1 0 00.894-.553l3-6A1 1 0 0017 3H6.28l-.31-1.243A1 1 0 005 1H3z"
              />
            </svg>
            <h3>No purchases recorded</h3>
            <p>Record your first supply order to start tracking costs.</p>
          </div>
        `
      : html`
          <div class="table-wrapper">
            <table>
              <thead>
                <tr>
                  <th data-sort="date">Date</th>
                  <th data-sort="itemName">Item</th>
                  <th data-sort="vendorName">Vendor</th>
                  <th data-sort="quantity">Qty</th>
                  <th data-sort="pricePerUnit">Price/Unit</th>
                  <th data-sort="totalCost">Total</th>
                  <th data-sort="lotNumber">Lot #</th>
                  <th data-sort="expirationDate">Expires</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                ${purchases
                  .map((p) => {
                    let expBadge = "";
                    if (p.expirationDate) {
                      const days = Math.ceil(
                        (new Date(p.expirationDate) - new Date()) / 86400000,
                      );
                      if (days <= 0)
                        expBadge = `<span class="badge badge-red">Expired</span>`;
                      else if (days <= 7)
                        expBadge = `<span class="badge badge-red">${days}d</span>`;
                      else if (days <= 30)
                        expBadge = `<span class="badge badge-amber">${days}d</span>`;
                      else
                        expBadge = `<span class="text-secondary">${shortDate(p.expirationDate)}</span>`;
                    }
                    return html`
                      <tr>
                        <td>${fmtDate(p.date)}</td>
                        <td class="font-medium">
                          <a class="item-link" data-id="${p.itemId}"
                            >${p.itemName}</a
                          >
                        </td>
                        <td>
                          ${p.vendorName
                            ? `<a class="vendor-link text-secondary" data-id="${p.vendorId}">${p.vendorName}</a>`
                            : '<span class="text-secondary">-</span>'}
                        </td>
                        <td>${p.quantity} ${unitAbbr(p.itemUnit)}</td>
                        <td>${currency(p.pricePerUnit)}</td>
                        <td class="font-medium">${currency(p.totalCost)}</td>
                        <td class="text-secondary">${p.lotNumber || "-"}</td>
                        <td>${expBadge || "-"}</td>
                        <td class="text-right">
                          <button
                            class="btn-ghost btn-sm edit-purchase"
                            data-id="${p.id}"
                          >
                            ${ICON_EDIT}
                          </button>
                          <button
                            class="btn-ghost btn-sm delete-purchase text-red"
                            data-id="${p.id}"
                          >
                            ${ICON_TRASH}
                          </button>
                        </td>
                      </tr>
                    `;
                  })
                  .join("")}
              </tbody>
            </table>
          </div>
        `}
  `;

  bindSearch(el, () => renderPurchasesInner(el));
  bindSort(el, () => renderPurchasesInner(el));

  el.querySelector("#add-purchase-btn")?.addEventListener("click", () =>
    showPurchaseForm(),
  );

  el.querySelectorAll(".edit-purchase").forEach((btn) => {
    btn.addEventListener("click", () => {
      showPurchaseForm(state.purchases.find((p) => p.id === btn.dataset.id));
    });
  });

  el.querySelectorAll(".delete-purchase").forEach((btn) => {
    btn.addEventListener("click", async () => {
      if (await confirm("Delete this purchase record?")) {
        await api.del(`purchases/${btn.dataset.id}`);
        await renderPurchases(el);
      }
    });
  });

  el.querySelectorAll(".item-link").forEach((a) => {
    a.addEventListener("click", (e) => {
      e.stopPropagation();
      navigate("item-detail", a.dataset.id);
    });
  });

  el.querySelectorAll(".vendor-link").forEach((a) => {
    a.addEventListener("click", (e) => {
      e.stopPropagation();
      navigate("vendor-detail", a.dataset.id);
    });
  });
}

// ── Usage List ──────────────────────────────────────────

async function renderUsage(el) {
  state.usage = await api.get("usage");
  renderUsageInner(el);
}

function renderUsageInner(el) {
  let usage = state.usage;
  if (state.search) {
    const q = state.search.toLowerCase();
    usage = usage.filter((u) => (u.itemName || "").toLowerCase().includes(q));
  }
  usage = sortList(usage);
  if (!state.sort.key) usage.sort((a, b) => b.date.localeCompare(a.date));

  el.innerHTML = html`
    <div class="view-header">
      <h2>Usage</h2>
      <div class="view-header-actions">
        <input
          type="text"
          class="search-input"
          placeholder="Search by item..."
          value="${state.search}"
        />
        <button class="btn btn-primary" id="add-usage-btn">
          + Record Usage
        </button>
      </div>
    </div>
    ${usage.length === 0 && !state.search
      ? html`
          <div class="empty-state">
            <svg viewBox="0 0 20 20" fill="currentColor" width="48" height="48">
              <path
                fill-rule="evenodd"
                d="M3 3a1 1 0 000 2v8a2 2 0 002 2h2.586l-1.293 1.293a1 1 0 101.414 1.414L10 15.414l2.293 2.293a1 1 0 001.414-1.414L12.414 15H15a2 2 0 002-2V5a1 1 0 100-2H3zm11 4a1 1 0 10-2 0v4a1 1 0 102 0V7zm-3 1a1 1 0 10-2 0v3a1 1 0 102 0V8zM8 9a1 1 0 00-2 0v2a1 1 0 102 0V9z"
                clip-rule="evenodd"
              />
            </svg>
            <h3>No usage recorded</h3>
            <p>
              Track consumption to see usage rates and predict reorder dates.
            </p>
          </div>
        `
      : html`
          <div class="table-wrapper">
            <table>
              <thead>
                <tr>
                  <th data-sort="date">Date</th>
                  <th data-sort="itemName">Item</th>
                  <th data-sort="quantity">Quantity</th>
                  <th>Est.</th>
                  <th data-sort="notes">Notes</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                ${usage
                  .map(
                    (u) => html`
                      <tr>
                        <td>${fmtDate(u.date)}</td>
                        <td class="font-medium">
                          <a class="item-link" data-id="${u.itemId}"
                            >${u.itemName}</a
                          >
                        </td>
                        <td class="text-red">
                          -${u.quantity} ${unitAbbr(u.itemUnit)}
                        </td>
                        <td>
                          ${u.isEstimate
                            ? '<span class="badge badge-blue">Est</span>'
                            : ""}
                        </td>
                        <td class="text-secondary">${u.notes || "-"}</td>
                        <td class="text-right">
                          <button
                            class="btn-ghost btn-sm edit-usage"
                            data-id="${u.id}"
                          >
                            ${ICON_EDIT}
                          </button>
                          <button
                            class="btn-ghost btn-sm delete-usage text-red"
                            data-id="${u.id}"
                          >
                            ${ICON_TRASH}
                          </button>
                        </td>
                      </tr>
                    `,
                  )
                  .join("")}
              </tbody>
            </table>
          </div>
        `}
  `;

  bindSearch(el, () => renderUsageInner(el));
  bindSort(el, () => renderUsageInner(el));

  el.querySelector("#add-usage-btn")?.addEventListener("click", () =>
    showUsageForm(),
  );

  el.querySelectorAll(".edit-usage").forEach((btn) => {
    btn.addEventListener("click", () => {
      showUsageForm(state.usage.find((u) => u.id === btn.dataset.id));
    });
  });

  el.querySelectorAll(".delete-usage").forEach((btn) => {
    btn.addEventListener("click", async () => {
      if (await confirm("Delete this usage record?")) {
        await api.del(`usage/${btn.dataset.id}`);
        await renderUsage(el);
      }
    });
  });

  el.querySelectorAll(".item-link").forEach((a) => {
    a.addEventListener("click", (e) => {
      e.stopPropagation();
      navigate("item-detail", a.dataset.id);
    });
  });
}

// ── Forms ───────────────────────────────────────────────

async function showItemForm(item = null, onDone = null) {
  const isEdit = !!item;
  const formHtml = html`
    <div class="form-group">
      <label class="form-label">Name <span class="required">*</span></label>
      <input
        type="text"
        class="form-input"
        id="f-name"
        value="${item?.name || ""}"
        placeholder="e.g. Composite Resin"
      />
    </div>
    <div class="form-row">
      <div class="form-group">
        <label class="form-label">Unit of Measure</label>
        <select class="form-select" id="f-unit">
          ${UNITS.map(
            (u) =>
              `<option value="${u.value}" ${item?.unit === u.value ? "selected" : ""}>${u.label}</option>`,
          ).join("")}
        </select>
      </div>
      <div class="form-group">
        <label class="form-label">Reorder Level</label>
        <input
          type="number"
          class="form-input"
          id="f-reorder"
          value="${item?.reorderLevel ?? 10}"
          min="0"
        />
      </div>
    </div>
    <div class="form-group">
      <label class="form-checkbox">
        <input
          type="checkbox"
          id="f-perishable"
          ${item?.isPerishable ? "checked" : ""}
        />
        Perishable item
      </label>
    </div>
    <div class="form-group">
      <label class="form-label">Storage Location</label>
      <input
        type="text"
        class="form-input"
        id="f-location"
        value="${item?.storageLocation || ""}"
        placeholder="e.g. Cabinet A, Shelf 3"
      />
    </div>
    <div class="form-group">
      <label class="form-label">Notes</label>
      <textarea class="form-textarea" id="f-notes" placeholder="Optional notes">
${item?.notes || ""}</textarea
      >
    </div>
  `;

  openModal(isEdit ? "Edit Item" : "New Item", formHtml, async () => {
    const name = $("#f-name").value.trim();
    if (!name) {
      $("#f-name").focus();
      return;
    }
    const data = {
      name,
      unit: $("#f-unit").value,
      reorderLevel: parseInt($("#f-reorder").value) || 10,
      isPerishable: $("#f-perishable").checked,
      storageLocation: $("#f-location").value.trim(),
      notes: $("#f-notes").value.trim(),
    };
    if (isEdit) {
      await api.put(`items/${item.id}`, data);
    } else {
      await api.post("items", data);
    }
    closeModal();
    if (onDone) {
      onDone();
    } else {
      navigate("items");
    }
  });
}

async function showVendorForm(vendor = null, onDone = null) {
  const isEdit = !!vendor;
  const formHtml = html`
    <div class="form-group">
      <label class="form-label"
        >Vendor Name <span class="required">*</span></label
      >
      <input
        type="text"
        class="form-input"
        id="f-name"
        value="${vendor?.name || ""}"
        placeholder="e.g. DentalCo Supply"
      />
    </div>
    <div class="form-group">
      <label class="form-label">Contact Name</label>
      <input
        type="text"
        class="form-input"
        id="f-contact"
        value="${vendor?.contactName || ""}"
        placeholder="Primary contact person"
      />
    </div>
    <div class="form-row">
      <div class="form-group">
        <label class="form-label">Phone</label>
        <input
          type="tel"
          class="form-input"
          id="f-phone"
          value="${vendor?.phone ? formatPhone(vendor.phone) : ""}"
          placeholder="(555) 123-4567"
        />
      </div>
      <div class="form-group">
        <label class="form-label">Email</label>
        <input
          type="email"
          class="form-input"
          id="f-email"
          value="${vendor?.email || ""}"
          placeholder="vendor@example.com"
        />
      </div>
    </div>
    <div class="form-group">
      <label class="form-label">Address</label>
      <input
        type="text"
        class="form-input"
        id="f-address"
        value="${vendor?.address || ""}"
        placeholder="Street address"
      />
    </div>
    <div class="form-group">
      <label class="form-label">Notes</label>
      <textarea class="form-textarea" id="f-notes" placeholder="Optional notes">
${vendor?.notes || ""}</textarea
      >
    </div>
  `;

  openModal(isEdit ? "Edit Vendor" : "New Vendor", formHtml, async () => {
    const name = $("#f-name").value.trim();
    if (!name) {
      $("#f-name").focus();
      return;
    }
    const data = {
      name,
      contactName: $("#f-contact").value.trim(),
      phone: stripPhone($("#f-phone").value),
      email: $("#f-email").value.trim(),
      address: $("#f-address").value.trim(),
      notes: $("#f-notes").value.trim(),
    };
    if (isEdit) {
      await api.put(`vendors/${vendor.id}`, data);
    } else {
      await api.post("vendors", data);
    }
    closeModal();
    if (onDone) {
      onDone();
    } else {
      navigate("vendors");
    }
  });
}

async function showPurchaseForm(purchase = null, preselectedItemId = null) {
  const isEdit = !!purchase;
  const items = await api.get("items");
  const vendors = await api.get("vendors");
  const selItemId = purchase?.itemId || preselectedItemId || "";
  const selVendorId = purchase?.vendorId || "";

  const formHtml = html`
    <div class="form-row">
      <div class="form-group">
        <label class="form-label">Item <span class="required">*</span></label>
        <select class="form-select" id="f-item">
          <option value="">Select an item...</option>
          ${items
            .map(
              (i) =>
                `<option value="${i.id}" ${i.id === selItemId ? "selected" : ""}>${i.name}</option>`,
            )
            .join("")}
        </select>
      </div>
      <div class="form-group">
        <label class="form-label">Vendor</label>
        <select class="form-select" id="f-vendor">
          <option value="">None</option>
          ${vendors
            .map(
              (v) =>
                `<option value="${v.id}" ${v.id === selVendorId ? "selected" : ""}>${v.name}</option>`,
            )
            .join("")}
        </select>
      </div>
    </div>
    <div class="form-group">
      <label class="form-label">Date</label>
      <input
        type="date"
        class="form-input"
        id="f-date"
        value="${purchase?.date || todayISO()}"
      />
    </div>
    <div class="form-row">
      <div class="form-group">
        <label class="form-label"
          >Quantity <span class="required">*</span></label
        >
        <input
          type="number"
          class="form-input"
          id="f-qty"
          value="${purchase?.quantity || 1}"
          min="1"
        />
      </div>
      <div class="form-group">
        <label class="form-label"
          >Price per Unit <span class="required">*</span></label
        >
        <input
          type="number"
          class="form-input"
          id="f-price"
          value="${purchase?.pricePerUnit || ""}"
          min="0"
          step="0.01"
          placeholder="0.00"
        />
      </div>
    </div>
    <div class="form-row">
      <div class="form-group">
        <label class="form-label">Lot Number</label>
        <input
          type="text"
          class="form-input"
          id="f-lot"
          value="${purchase?.lotNumber || ""}"
          placeholder="Optional"
        />
      </div>
      <div class="form-group">
        <label class="form-label">Expiration Date</label>
        <input
          type="date"
          class="form-input"
          id="f-exp"
          value="${purchase?.expirationDate || ""}"
        />
      </div>
    </div>
    <div class="form-group">
      <label class="form-label">Notes</label>
      <textarea class="form-textarea" id="f-notes" placeholder="Optional notes">
${purchase?.notes || ""}</textarea
      >
    </div>
  `;

  openModal(isEdit ? "Edit Purchase" : "New Purchase", formHtml, async () => {
    const itemId = $("#f-item").value;
    const price = parseFloat($("#f-price").value);
    const qty = parseInt($("#f-qty").value);
    if (!itemId || !price || !qty) return;

    const data = {
      itemId,
      vendorId: $("#f-vendor").value || null,
      date: $("#f-date").value,
      quantity: qty,
      pricePerUnit: price,
      lotNumber: $("#f-lot").value.trim(),
      expirationDate: $("#f-exp").value || null,
      notes: $("#f-notes").value.trim(),
    };
    if (isEdit) {
      await api.put(`purchases/${purchase.id}`, data);
    } else {
      await api.post("purchases", data);
    }
    closeModal();
    navigate(
      state.view === "item-detail" ? "item-detail" : "purchases",
      state.detailId,
    );
  });
}

async function showUsageForm(usage = null, preselectedItemId = null) {
  const isEdit = !!usage;
  const items = await api.get("items");
  const selItemId = usage?.itemId || preselectedItemId || "";

  const formHtml = html`
    <div class="form-group">
      <label class="form-label">Item <span class="required">*</span></label>
      <select class="form-select" id="f-item">
        <option value="">Select an item...</option>
        ${items
          .map(
            (i) =>
              `<option value="${i.id}" ${i.id === selItemId ? "selected" : ""}>${i.name} (${i.currentInventory} ${unitAbbr(i.unit)})</option>`,
          )
          .join("")}
      </select>
    </div>
    <div class="form-row">
      <div class="form-group">
        <label class="form-label">Date</label>
        <input
          type="date"
          class="form-input"
          id="f-date"
          value="${usage?.date || todayISO()}"
        />
      </div>
      <div class="form-group">
        <label class="form-label"
          >Quantity <span class="required">*</span></label
        >
        <input
          type="number"
          class="form-input"
          id="f-qty"
          value="${usage?.quantity || 1}"
          min="1"
        />
      </div>
    </div>
    <div class="form-group">
      <label class="form-checkbox">
        <input
          type="checkbox"
          id="f-estimate"
          ${usage?.isEstimate ? "checked" : ""}
        />
        This is an estimate
      </label>
    </div>
    <div class="form-group">
      <label class="form-label">Notes</label>
      <textarea class="form-textarea" id="f-notes" placeholder="Optional notes">
${usage?.notes || ""}</textarea
      >
    </div>
  `;

  openModal(isEdit ? "Edit Usage" : "Record Usage", formHtml, async () => {
    const itemId = $("#f-item").value;
    const qty = parseInt($("#f-qty").value);
    if (!itemId || !qty) return;

    const data = {
      itemId,
      date: $("#f-date").value,
      quantity: qty,
      isEstimate: $("#f-estimate").checked,
      notes: $("#f-notes").value.trim(),
    };
    if (isEdit) {
      await api.put(`usage/${usage.id}`, data);
    } else {
      await api.post("usage", data);
    }
    closeModal();
    navigate(
      state.view === "item-detail" ? "item-detail" : "usage",
      state.detailId,
    );
  });
}

// ── Search & Sort helpers ───────────────────────────────

function bindSearch(el, rerender) {
  const input = el.querySelector(".search-input");
  if (!input) return;
  input.addEventListener("input", (e) => {
    state.search = e.target.value;
    rerender();
    const newInput = el.querySelector(".search-input");
    if (newInput) {
      newInput.focus();
      newInput.selectionStart = newInput.selectionEnd = newInput.value.length;
    }
  });
}

function bindSort(el, rerender) {
  el.querySelectorAll("th[data-sort]").forEach((th) => {
    if (state.sort.key === th.dataset.sort) {
      th.classList.add(state.sort.dir === "asc" ? "sorted-asc" : "sorted-desc");
    }
    th.addEventListener("click", () => {
      const key = th.dataset.sort;
      if (state.sort.key === key) {
        state.sort.dir = state.sort.dir === "asc" ? "desc" : "asc";
      } else {
        state.sort = { key, dir: "asc" };
      }
      rerender();
    });
  });
}

function sortList(list) {
  if (!state.sort.key) return list;
  const key = state.sort.key;
  const dir = state.sort.dir === "asc" ? 1 : -1;
  return [...list].sort((a, b) => {
    let va = a[key] ?? "";
    let vb = b[key] ?? "";
    if (typeof va === "number" && typeof vb === "number")
      return (va - vb) * dir;
    if (typeof va === "boolean") return (va === vb ? 0 : va ? -1 : 1) * dir;
    return String(va).localeCompare(String(vb)) * dir;
  });
}

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

// ── Init ────────────────────────────────────────────────

document.addEventListener("DOMContentLoaded", () => {
  // Nav items: always go through navigate() to avoid stale hash issues
  $$(".nav-item").forEach((a) => {
    a.addEventListener("click", (e) => {
      e.preventDefault();
      navigate(a.dataset.view);
    });
  });

  const hash = location.hash.slice(1) || "dashboard";
  const parts = hash.split("/");
  navigate(parts[0], parts[1] || null);
});
