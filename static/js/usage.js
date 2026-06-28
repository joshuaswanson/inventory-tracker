import { $, ICON_EDIT, ICON_TRASH, api, fmtDate, html, state, unitAbbr } from "./core.js";
import { showUsageForm } from "./forms.js";
import { confirm } from "./modal.js";
import { navigate } from "./router.js";
import { bindSearch, bindSort, sortList } from "./tables.js";

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
      <input
        type="text"
        class="search-input"
        placeholder="Search by item..."
        value="${state.search}"
      />
      <div class="view-header-actions">
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


export {
  renderUsage,
  renderUsageInner,
};
