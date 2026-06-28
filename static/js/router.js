import { $, $$, state } from "./core.js";
import { renderDashboard } from "./dashboard.js";
import { renderItemDetail, renderItems } from "./items.js";
import { renderPurchases } from "./purchases.js";
import { renderUsage } from "./usage.js";
import { renderVendorDetail, renderVendors } from "./vendors.js";

// ── Router ──────────────────────────────────────────────

const VIEW_LABELS = {
  dashboard: "Dashboard",
  items: "Items",
  vendors: "Vendors",
  purchases: "Purchases",
  usage: "Usage",
};

function navigate(view, detailId = null, filter = "all") {
  if (view.endsWith("-detail") && state.view !== view) {
    state.detailFrom = { view: state.view, filter: state.filter };
  }
  state.view = view;
  state.detailId = detailId;
  state.search = "";
  state.sort = { key: null, dir: "asc" };
  state.filter = filter;

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


export {
  VIEW_LABELS,
  navigate,
  render,
};
