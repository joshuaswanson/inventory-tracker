import { $, ICON_EDIT, ICON_TRASH, UNITS, api, currency, expirationBadge, fmtDate, html, shortDate, state, stockBadge, stockBar, unitAbbr } from "./core.js";
import { showItemForm, showPurchaseForm, showUsageForm } from "./forms.js";
import { confirm } from "./modal.js";
import { VIEW_LABELS, navigate } from "./router.js";
import { bindSearch, bindSort, sortList } from "./tables.js";

// ── Items List ──────────────────────────────────────────

async function renderItems(el) {
  state.items = await api.get("items");
  renderItemsInner(el);
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

  items = state.sort.key
    ? sortList(items)
    : [...items].sort((a, b) => a.name.localeCompare(b.name));

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
      <input
        type="text"
        class="search-input"
        placeholder="Search items..."
        value="${state.search}"
      />
      <div class="view-header-actions">
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
                  <th data-sort="name">Name</th>
                  <th data-sort="currentInventory">Stock</th>
                  <th data-sort="reorderLevel">Reorder At</th>
                  <th data-sort="needsReorder">Status</th>
                  <th data-sort="storageLocation">Location</th>
                  <th data-sort="averagePrice">Avg Price</th>
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
  bindSort(el, () => renderItemsInner(el));

  el.querySelectorAll(".filter-chip").forEach((btn) => {
    btn.addEventListener("click", () => {
      state.filter = btn.dataset.filter;
      renderItemsInner(el);
    });
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

  const back = state.detailFrom || { view: "items", filter: "all" };
  const backLabel = VIEW_LABELS[back.view] || "Items";

  el.innerHTML = html`
    <div class="detail-header">
      <button class="back-btn" id="back-to-items">&larr; ${backLabel}</button>
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

  $("#back-to-items").onclick = () => navigate(back.view, null, back.filter);
  $("#edit-detail-item").onclick = () =>
    showItemForm(item, () => renderItemDetail(el, id));
  $("#add-purchase-from-detail").onclick = () => showPurchaseForm(null, id);
  $("#add-usage-from-detail").onclick = () => showUsageForm(null, id);
}


export {
  renderItems,
  renderItemsInner,
  renderItemDetail,
};
