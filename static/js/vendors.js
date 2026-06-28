import { $, ICON_EDIT, ICON_TRASH, api, currency, formatPhone, html, shortDate, state } from "./core.js";
import { showVendorForm } from "./forms.js";
import { confirm } from "./modal.js";
import { VIEW_LABELS, navigate } from "./router.js";
import { bindSearch, bindSort, sortList } from "./tables.js";

// ── Vendors List ────────────────────────────────────────

async function renderVendors(el) {
  state.vendors = await api.get("vendors");
  renderVendorsInner(el);
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

  vendors = state.sort.key
    ? sortList(vendors)
    : [...vendors].sort((a, b) => a.name.localeCompare(b.name));

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
      <input
        type="text"
        class="search-input"
        placeholder="Search vendors..."
        value="${state.search}"
      />
      <div class="view-header-actions">
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
                  <th data-sort="name">Name</th>
                  <th data-sort="contactName">Contact</th>
                  <th data-sort="phone">Phone</th>
                  <th data-sort="email">Email</th>
                  <th data-sort="totalPurchases">Orders</th>
                  <th data-sort="totalSpent">Total Spent</th>
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
                        <td class="text-secondary">
                          ${v.email
                            ? html`<a
                                class="email-link"
                                href="mailto:${v.email}"
                                >${v.email}</a
                              >`
                            : "-"}
                        </td>
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
  bindSort(el, () => renderVendorsInner(el));

  el.querySelectorAll(".filter-chip").forEach((btn) => {
    btn.addEventListener("click", () => {
      state.filter = btn.dataset.filter;
      renderVendorsInner(el);
    });
  });

  el.querySelector("#add-vendor-btn")?.addEventListener("click", () =>
    showVendorForm(),
  );

  el.querySelectorAll("tr.clickable").forEach((tr) => {
    tr.addEventListener("click", (e) => {
      if (e.target.closest("button, a")) return;
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

  const back = state.detailFrom || { view: "vendors", filter: "all" };
  const backLabel = VIEW_LABELS[back.view] || "Vendors";

  el.innerHTML = html`
    <div class="detail-header">
      <button class="back-btn" id="back-to-vendors">&larr; ${backLabel}</button>
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
              ><span class="value"
                ><a class="email-link" href="mailto:${vendor.email}"
                  >${vendor.email}</a
                ></span
              >
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

  $("#back-to-vendors").onclick = () => navigate(back.view, null, back.filter);
  $("#edit-detail-vendor").onclick = () =>
    showVendorForm(vendor, () => renderVendorDetail(el, id));
}


export {
  renderVendors,
  renderVendorsInner,
  renderVendorDetail,
};
