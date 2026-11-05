/* JSON Formatter Pro — core UI logic, validation engine, syntax highlighting. */
(() => {
  "use strict";

  const $ = (id) => document.getElementById(id);
  const input   = $("json-input");
  const output  = $("json-output");
  const errCard = $("error-card");
  const stats   = $("input-stats");
  const indent  = $("indent-select");

  /* ---------- Toasts ---------- */
  function toast(message, type = "info") {
    const el = document.createElement("div");
    el.className = `toast ${type}`;
    el.textContent = message;
    $("toasts").appendChild(el);
    setTimeout(() => {
      el.classList.add("leaving");
      el.addEventListener("transitionend", () => el.remove(), { once: true });
      setTimeout(() => el.remove(), 500); // fallback
    }, 2600);
  }

  /* ---------- Minimal safe JSON syntax highlighter (no innerHTML of raw input) ---------- */
  function highlight(json) {
    const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    // Tokenize strings/keys first, then numbers, booleans, null, punctuation.
    return esc(json).replace(
      /("(\\u[\da-fA-F]{4}|\\[^u]|[^\\"])*")(\s*:)?|\b(true|false)\b|\bnull\b|-?\d+(\.\d+)?([eE][+-]?\d+)?|([{}\[\],:])/g,
      (match, str, _c, _d, bool, _e, _f, _g, punct) => {
        if (str)  return `<span class="${match.endsWith(":") && match.trimEnd() !== str ? "key" : "str"}">${str}</span>` + match.slice(str.length).replace(/^(\s*:)/, '<span class="punct">$1</span>');
        if (bool) return `<span class="bool">${match}</span>`;
        if (match === "null") return '<span class="null">null</span>';
        if (punct) return `<span class="punct">${punct}</span>`;
        return `<span class="num">${match}</span>`;
      }
    );
  }
  // Simpler, more robust key/string distinction:
  function highlightJSON(json) {
    const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    let out = "";
    let i = 0;
    while (i < json.length) {
      const ch = json[i];
      if (ch === '"') {
        let j = i + 1;
        while (j < json.length) {
          if (json[j] === "\\") j += 2;
          else if (json[j] === '"') { j++; break; }
          else j++;
        }
        const raw = json.slice(i, j);
        // Peek ahead for a colon => key
        let k = j;
        while (k < json.length && /\s/.test(json[k])) k++;
        const cls = json[k] === ":" ? "key" : "str";
        out += `<span class="${cls}">${esc(raw)}</span>`;
        i = j;
      } else if (/[{}\[\],:]/.test(ch)) {
        out += `<span class="punct">${ch}</span>`;
        i++;
      } else {
        const rest = json.slice(i);
        const m = rest.match(/^-?\d+(\.\d+)?([eE][+-]?\d+)?/);
        if (m && m.index === 0) {
          out += `<span class="num">${m[0]}</span>`;
          i += m[0].length;
        } else if (rest.startsWith("true") || rest.startsWith("false")) {
          const word = rest.startsWith("true") ? "true" : "false";
          out += `<span class="bool">${word}</span>`;
          i += word.length;
        } else if (rest.startsWith("null")) {
          out += '<span class="null">null</span>';
          i += 4;
        } else {
          out += esc(ch);
          i++;
        }
      }
    }
    return out;
  }

  /* ---------- Local validation event log (privacy-preserving alternative to remote telemetry) ---------- */
  const eventLog = [];
  function logEvent(event) {
    eventLog.push({ ...event, ts: new Date().toISOString() });
    // Hook for your own, consent-gated analytics endpoint if desired.
  }

  /* ---------- Core: format & validate ---------- */
  function formatAndAnalyze() {
    const raw = input.value.trim();
    errCard.classList.add("hidden");
    output.innerHTML = "";

    if (!raw) {
      toast("Input is empty — paste some JSON first.", "error");
      return;
    }
    stats.textContent = `${new Blob([raw]).size} bytes · ${raw.length} chars`;

    try {
      const parsed = JSON.parse(raw);
      const spaces = parseInt(indent.value, 10);
      const pretty = JSON.stringify(parsed, null, spaces);
      output.innerHTML = highlightJSON(pretty);
      errCard.classList.add("hidden");
      logEvent({ type: "format_success", size: raw.length });
      toast("Valid JSON — formatted successfully.", "success");
    } catch (err) {
      const loc = locateError(raw, err);
      errCard.innerHTML =
        "<strong>Syntax error</strong>" +
        escHTML(err.message) +
        (loc ? `<br>≈ Line ${loc.line}, column ${loc.column}` : "");
      errCard.classList.remove("hidden");
      logEvent({ type: "format_error", size: raw.length });
      toast("Invalid JSON — see error details.", "error");
    }
  }

  function escHTML(s) {
    const d = document.createElement("div");
    d.textContent = s;
    return d.innerHTML;
  }

  /* Best-effort line/column extraction from JSON.parse error messages. */
  function locateError(raw, err) {
    const m = err.message.match(/position (\d+)/i);
    let pos = m ? parseInt(m[1], 10) : null;
    if (pos == null) {
      const lm = err.message.match(/line (\d+) column (\d+)/i);
      if (lm) return { line: +lm[1], column: +lm[2] };
      return null;
    }
    const upto = raw.slice(0, pos);
    const line = upto.split("\n").length;
    const column = pos - upto.lastIndexOf("\n");
    return { line, column };
  }

  /* ---------- Actions ---------- */
  $("btn-format").addEventListener("click", formatAndAnalyze);

  input.addEventListener("keydown", (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key === "Enter") formatAndAnalyze();
  });

  // Live validation feedback (debounced, non-intrusive).
  let debounce;
  input.addEventListener("input", () => {
    clearTimeout(debounce);
    debounce = setTimeout(() => {
      const raw = input.value.trim();
      if (!raw) { errCard.classList.add("hidden"); stats.textContent = ""; return; }
      try {
        JSON.parse(raw);
        errCard.classList.add("hidden");
        stats.textContent = `✓ valid · ${raw.length} chars`;
      } catch {
        stats.textContent = `✗ invalid (so far) · ${raw.length} chars`;
      }
    }, 350);
  });

  $("btn-clear").addEventListener("click", () => {
    input.value = "";
    output.innerHTML = "";
    stats.textContent = "";
    errCard.classList.add("hidden");
    input.focus();
    toast("Workspace cleared.");
  });

  $("btn-copy").addEventListener("click", async () => {
    const text = output.textContent;
    if (!text) return toast("Nothing to copy yet.", "error");
    try {
      await navigator.clipboard.writeText(text);
      const btn = $("btn-copy");
      btn.textContent = "✓ Copied";
      btn.classList.add("copied");
      setTimeout(() => { btn.textContent = "Copy"; btn.classList.remove("copied"); }, 1500);
      toast("Copied to clipboard.", "success");
    } catch {
      toast("Clipboard access denied by browser.", "error");
    }
  });

  $("btn-download").addEventListener("click", () => {
    const text = output.textContent;
    if (!text) return toast("Format something first.", "error");
    const blob = new Blob([text], { type: "application/json" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "formatted.json";
    a.click();
    URL.revokeObjectURL(a.href);
    toast("Download started.", "success");
  });

  $("btn-sample").addEventListener("click", () => {
    input.value = JSON.stringify({
      app: "JSON Formatter Pro",
      version: "1.0.0",
      features: ["format", "validate", "highlight", "download"],
      metrics: { requests: 12840, uptime: 99.98, regions: ["us-east", "eu-west", "ap-south"] },
      maintainer: { name: "Ada Lovelace", active: true, tags: null }
    });
    toast("Sample JSON loaded.");
  });
})();