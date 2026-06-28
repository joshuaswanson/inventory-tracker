import { state } from "./core.js";

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


export {
  bindSearch,
  bindSort,
  sortList,
};
