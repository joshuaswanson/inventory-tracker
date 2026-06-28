import { $, $$, state } from "./core.js";

// ── Modal ───────────────────────────────────────────────

function openModal(title, bodyHtml, onSave) {
  $("#modal-title").textContent = title;
  $("#modal-body").innerHTML = bodyHtml;
  state.modalSaveHandler = onSave;
  $("#modal-overlay").classList.remove("hidden");
  wireRequiredValidation();
  const first = $("#modal-body input, #modal-body select");
  if (first) setTimeout(() => first.focus(), 50);
}

// Required fields are those whose label contains a `.required` marker.
function modalRequiredFields() {
  return $$("#modal-body .form-group")
    .filter((g) => g.querySelector(".form-label .required"))
    .map((g) => g.querySelector("input, select, textarea"))
    .filter(Boolean);
}

function updateModalSaveState() {
  const incomplete = modalRequiredFields().some((f) => !f.value.trim());
  $("#modal-save").classList.toggle("is-disabled", incomplete);
}

function wireRequiredValidation() {
  modalRequiredFields().forEach((f) => {
    const onChange = () => {
      f.classList.remove("field-error");
      updateModalSaveState();
    };
    f.addEventListener("input", onChange);
    f.addEventListener("change", onChange);
  });
  updateModalSaveState();
}

function closeModal() {
  $("#modal-overlay").classList.add("hidden");
  state.modalSaveHandler = null;
  const save = $("#modal-save");
  save.textContent = "Save";
  save.classList.remove("is-disabled");
  delete save.dataset.busy;
}

$("#modal-close").onclick = closeModal;
$("#modal-cancel").onclick = closeModal;
$("#modal-save").onclick = () => {
  const empty = modalRequiredFields().filter((f) => !f.value.trim());
  if (empty.length) {
    empty.forEach((f) => f.classList.add("field-error"));
    empty[0].focus();
    return;
  }
  if (state.modalSaveHandler) state.modalSaveHandler();
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


export {
  openModal,
  modalRequiredFields,
  updateModalSaveState,
  wireRequiredValidation,
  closeModal,
  confirm,
};
