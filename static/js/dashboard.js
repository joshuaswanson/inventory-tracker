import { $, api, currency, expirationBadge, html, shortDate, stockBadge, unitAbbr } from "./core.js";
import { navigate } from "./router.js";

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


export {
  renderDashboard,
};
