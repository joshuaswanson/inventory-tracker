import { $, $$, api } from "./core.js";
import { navigate } from "./router.js";

// ── Init ────────────────────────────────────────────────

async function heartbeat() {
  try {
    const r = await fetch("/api/heartbeat", { method: "POST" });
    setConnectionLost(!r.ok);
  } catch (e) {
    setConnectionLost(true);
  }
}

function setConnectionLost(lost) {
  $("#connection-banner")?.classList.toggle("hidden", !lost);
}

async function reconnect() {
  const btn = $("#connection-retry");
  const msg = btn.previousElementSibling;
  btn.textContent = "Reconnecting…";
  btn.classList.add("is-disabled");
  try {
    const r = await fetch("/api/heartbeat", { method: "POST" });
    if (!r.ok) throw new Error();
    location.reload();
  } catch (e) {
    if (msg)
      msg.textContent =
        "Still can't reach the app. Reopen it (start.command), then click Reconnect.";
    btn.textContent = "Reconnect";
    btn.classList.remove("is-disabled");
  }
}

document.addEventListener("DOMContentLoaded", () => {
  // Nav items: always go through navigate() to avoid stale hash issues
  $$(".nav-item").forEach((a) => {
    a.addEventListener("click", (e) => {
      e.preventDefault();
      navigate(a.dataset.view);
    });
  });

  // Heartbeat: keeps the server alive and detects a lost connection
  heartbeat();
  setInterval(heartbeat, 5000);
  $("#connection-retry").addEventListener("click", reconnect);

  // Update check
  checkForUpdate();
  setInterval(checkForUpdate, 10 * 60 * 1000);
  $("#update-banner-btn").addEventListener("click", runUpdate);
  $("#update-banner-dismiss").addEventListener("click", () =>
    $("#update-banner").classList.add("hidden"),
  );

  const hash = location.hash.slice(1) || "dashboard";
  const parts = hash.split("/");
  navigate(parts[0], parts[1] || null);
});

async function checkForUpdate() {
  try {
    const r = await fetch("/api/check-update");
    const data = await r.json();
    if (data.updateAvailable) {
      const text =
        data.commitCount === 1
          ? "A new update is available."
          : `${data.commitCount} new updates available.`;
      $("#update-banner-text").textContent = text;
      $("#update-banner").classList.remove("hidden");
    }
  } catch {}
}

async function runUpdate() {
  const btn = $("#update-banner-btn");
  btn.textContent = "Updating...";
  btn.disabled = true;
  try {
    const r = await fetch("/api/update", { method: "POST" });
    const data = await r.json();
    if (data.success) {
      $("#update-banner-text").textContent = "Update complete! Refreshing...";
      setTimeout(() => location.reload(), 1500);
    } else {
      $("#update-banner-text").textContent =
        "Update failed. Please try again later.";
      btn.textContent = "Retry";
      btn.disabled = false;
    }
  } catch {
    $("#update-banner-text").textContent =
      "Update failed. Please try again later.";
    btn.textContent = "Retry";
    btn.disabled = false;
  }
}


export {
  heartbeat,
  setConnectionLost,
  reconnect,
  checkForUpdate,
  runUpdate,
};
