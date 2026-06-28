import { $, UNITS, api, formatPhone, html, state, stripPhone, todayISO, unitAbbr } from "./core.js";
import { closeModal, openModal } from "./modal.js";
import { navigate } from "./router.js";

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
        <label class="form-label">Product Number</label>
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


export {
  showItemForm,
  showVendorForm,
  showPurchaseForm,
  showUsageForm,
};
