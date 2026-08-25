/* SYSTEM STATUS module — progressive enhancement.
 * Fetches the sanitized status JSON (served by Caddy from the runtime dir).
 * On 404 / network error / stale data the server-rendered placeholder stays.
 * No external libraries; no logging of failures.
 */
(function () {
  "use strict";
  var mod = document.getElementById("status-module");
  if (!mod) return;

  var endpoint = mod.getAttribute("data-endpoint") || "status/status.json";
  var staleMs = parseInt(mod.getAttribute("data-stale-ms") || "300000", 10);
  var body = document.getElementById("status-body");
  var updated = document.getElementById("status-updated");
  if (!body || !updated) return;

  function esc(s) {
    var d = document.createElement("div");
    d.textContent = String(s == null ? "" : s);
    return d.innerHTML;
  }

  function stateClass(state) {
    var s = String(state || "").toLowerCase();
    if (s === "online" || s === "up" || s === "ok") return "online";
    if (s === "degraded" || s === "slow" || s === "warn") return "degraded";
    if (s === "offline" || s === "down" || s === "error") return "offline";
    return "unknown";
  }

  function fmtTime(iso) {
    var t = Date.parse(iso);
    if (isNaN(t)) return null;
    var d = new Date(t);
    var p = function (n) { return (n < 10 ? "0" : "") + n; };
    return p(d.getUTCHours()) + ":" + p(d.getUTCMinutes()) + " UTC";
  }

  function render(data) {
    var age = Date.now() - Date.parse(data.updated_at || "");
    var stale = !isFinite(age) || age > staleMs;

    updated.textContent = stale
      ? "stale — " + (fmtTime(data.updated_at) || "unknown time")
      : "updated " + fmtTime(data.updated_at);
    updated.classList.add(stale ? "is-stale" : "is-fresh");

    var services = Array.isArray(data.services) ? data.services : [];
    var cells = services.map(function (svc) {
      var cls = stateClass(svc.state);
      return (
        '<li class="status-cell ' + cls + '">' +
        '<span class="dot" aria-hidden="true"></span>' +
        '<span class="name mono">' + esc(svc.name) + "</span>" +
        '<span class="state mono">' + esc(svc.state) + "</span>" +
        "</li>"
      );
    });
    if (data.portal_revision) {
      cells.push(
        '<li class="status-cell unknown">' +
        '<span class="dot" aria-hidden="true"></span>' +
        '<span class="name mono">PORTAL REV</span>' +
        '<span class="state mono">' + esc(String(data.portal_revision).slice(0, 8)) + "</span>" +
        "</li>"
      );
    }
    body.innerHTML =
      (stale ? '<p class="status-note mono">status data is stale — last update shown above</p>' : "") +
      '<ul class="status-tiles">' + cells.join("") + "</ul>";
  }

  fetch(endpoint, { cache: "no-store" })
    .then(function (r) {
      if (!r.ok) throw new Error("http " + r.status);
      return r.json();
    })
    .then(render)
    .catch(function () {
      /* placeholder stays — nothing to do */
    });
})();