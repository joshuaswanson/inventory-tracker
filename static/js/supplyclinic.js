import { $, api, html, state } from "./core.js";
import { closeModal, openModal, wireRequiredValidation } from "./modal.js";
import { navigate } from "./router.js";

// ── SupplyClinic import ─────────────────────────────────

async function showSupplyClinicImport() {
  let status = { remembered: false, email: "" };
  try {
    status = await (await fetch("/api/import/supplyclinic/status")).json();
  } catch (e) {
    /* fall back to login form */
  }
  openModal("Import from SupplyClinic", "", () => {});
  if (status.remembered) scShowRemembered(status.email);
  else scShowLogin(status.email, "");
}

function scShowRemembered(email) {
  $("#modal-body").innerHTML = html`
    <p class="modal-intro">
      Signed in to SupplyClinic${email
        ? html` as <strong>${email}</strong>`
        : ""}. Click Import to bring in any new orders.
    </p>
    <p id="sc-error" class="text-red"></p>
    <button class="link-btn" id="sc-switch-account">
      Use a different account
    </button>
  `;
  $("#sc-switch-account").onclick = () => scShowLogin(email, "");
  const save = $("#modal-save");
  save.textContent = "Import";
  state.modalSaveHandler = () => scRunImport({});
  wireRequiredValidation();
}

function scShowLogin(email, errorMsg) {
  $("#modal-body").innerHTML = html`
    <p class="modal-intro">
      Sign in with your SupplyClinic account to import your order history as
      purchases. Only new orders are added, so it's safe to run anytime.
    </p>
    <div class="form-group">
      <label class="form-label"
        >SupplyClinic Email <span class="required">*</span></label
      >
      <input
        type="email"
        class="form-input"
        id="sc-email"
        value="${email || ""}"
        placeholder="you@example.com"
        autocomplete="username"
      />
    </div>
    <div class="form-group">
      <label class="form-label">Password <span class="required">*</span></label>
      <input
        type="password"
        class="form-input"
        id="sc-password"
        placeholder="Your SupplyClinic password"
        autocomplete="current-password"
      />
    </div>
    <p class="sc-note text-secondary">
      Your password is only used to sign in to SupplyClinic. It is never saved.
    </p>
    <p id="sc-error" class="text-red">${errorMsg || ""}</p>
  `;
  const save = $("#modal-save");
  save.textContent = "Sign in & Import";
  state.modalSaveHandler = () =>
    scRunImport({
      email: $("#sc-email").value.trim(),
      password: $("#sc-password").value,
    });
  wireRequiredValidation();
  setTimeout(() => $("#sc-email")?.focus(), 50);
}

async function scRunImport(creds) {
  const save = $("#modal-save");
  if (save.dataset.busy) return;
  const errEl = $("#sc-error");
  if (errEl) errEl.textContent = "";
  save.dataset.busy = "1";
  save.classList.add("is-disabled");
  save.textContent = creds.password ? "Signing in…" : "Importing…";
  try {
    const r = await fetch("/api/import/supplyclinic", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(creds),
    });
    const data = await r.json();
    if (!r.ok) {
      if (data.needLogin) {
        delete save.dataset.busy;
        scShowLogin(creds.email || "", data.error || "Please sign in again.");
        return;
      }
      throw new Error(data.error || "Import failed. Please try again.");
    }
    scShowResult(data);
  } catch (e) {
    if (errEl) errEl.textContent = e.message;
    save.textContent = creds.password ? "Sign in & Import" : "Import";
    save.classList.remove("is-disabled");
  } finally {
    delete save.dataset.busy;
  }
}

function scShowResult(data) {
  const plural = (n) => (n === 1 ? "" : "s");
  $("#modal-body").innerHTML = html`
    <div class="sc-result">
      <p class="sc-result-title">Import complete</p>
      <ul class="sc-result-list">
        <li>
          <strong>${data.imported}</strong> new purchase${plural(data.imported)}
          added
        </li>
        <li>
          <strong>${data.newItems}</strong> new item${plural(data.newItems)}
          created
        </li>
        <li>
          <strong>${data.newVendors}</strong> new vendor${plural(
            data.newVendors,
          )}
          created
        </li>
        <li>${data.duplicates} already imported (skipped)</li>
        ${data.skipped
          ? html`<li>${data.skipped} cancelled or returned (skipped)</li>`
          : ""}
      </ul>
    </div>
  `;
  const save = $("#modal-save");
  save.textContent = "Done";
  save.classList.remove("is-disabled");
  state.modalSaveHandler = () => {
    closeModal();
    navigate("purchases");
  };
}


export {
  showSupplyClinicImport,
  scShowRemembered,
  scShowLogin,
  scRunImport,
  scShowResult,
};
