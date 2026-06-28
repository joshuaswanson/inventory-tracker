import { $, ICON_EDIT, ICON_TRASH, api, currency, fmtDate, html, shortDate, state, unitAbbr } from "./core.js";
import { showPurchaseForm } from "./forms.js";
import { confirm } from "./modal.js";
import { navigate } from "./router.js";
import { showSupplyClinicImport } from "./supplyclinic.js";
import { bindSearch, bindSort, sortList } from "./tables.js";

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
      <input
        type="text"
        class="search-input"
        placeholder="Search by item or vendor..."
        value="${state.search}"
      />
      <div class="view-header-actions">
        <div class="dropdown" id="import-dropdown">
          <button class="btn btn-secondary" id="import-btn">Import ▾</button>
          <div class="dropdown-menu hidden" id="import-menu">
            <button class="dropdown-item" data-import="supplyclinic">
              SupplyClinic
            </button>
          </div>
        </div>
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

  const importBtn = el.querySelector("#import-btn");
  const importMenu = el.querySelector("#import-menu");
  importBtn?.addEventListener("click", (e) => {
    e.stopPropagation();
    importMenu.classList.toggle("hidden");
  });
  document.addEventListener("click", () => importMenu?.classList.add("hidden"));
  el.querySelectorAll("#import-menu .dropdown-item").forEach((btn) => {
    btn.addEventListener("click", () => {
      importMenu.classList.add("hidden");
      if (btn.dataset.import === "supplyclinic") showSupplyClinicImport();
    });
  });

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


export {
  renderPurchases,
  renderPurchasesInner,
};
