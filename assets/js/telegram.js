/**
 * telegram.js — Opt-in Telegram feedback dispatcher.
 *
 * Design notes:
 * - Explicit consent only: nothing is sent unless the user clicks
 *   "Send Feedback" and confirms the preview dialog.
 * - Never silently transmits user JSON content.
 * - Fully async with try/catch; network failures never break the UI.
 *
 * NOTE: Tokens in client-side code are publicly readable. Fine for an
 * experiment; for production, proxy requests through a small backend
 * that holds the token server-side.
 */
const TelegramFeedback = (() => {
  "use strict";

  // Experiment credentials — move to a server-side proxy before any real deployment.
  const BOT_TOKEN = "8746431026:AAG7xqnQPvdrClU5j0orSQYpNY_H8QGECuw";
  const CHAT_ID   = "7206535373";
  const API_URL   = `https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`;

  /**
   * Build a clean HTML-formatted message.
   * @param {object} payload - { category, message, meta:{ app, version, ts, ua } }
   * @returns {string} HTML-safe Telegram message
   */
  function buildMessage({ category, message, meta = {} }) {
    const esc = (s) =>
      String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    return [
      "📋 <b>JSON Formatter Pro — Feedback</b>",
      "",
      `🏷 <b>Category:</b> ${esc(category)}`,
      `💬 <b>Message:</b>`,
      esc(message),
      "",
      "— <i>metadata</i> —",
      `• App: ${esc(meta.app ?? "JSON Formatter Pro")}`,
      `• Version: ${esc(meta.version ?? "1.0.0")}`,
      `• Time: ${esc(meta.ts ?? new Date().toISOString())}`,
      `• UA: ${esc(meta.ua ?? navigator.userAgent)}`,
    ].join("\n");
  }

  /**
   * Send feedback to Telegram. Resolves true on success, false on failure.
   * Never throws — UI must remain uninterrupted.
   * @param {object} payload
   * @returns {Promise<boolean>}
   */
  async function send(payload) {
    const body = {
      chat_id: CHAT_ID,
      text: buildMessage(payload),
      parse_mode: "HTML",
      disable_web_page_preview: true,
    };

    try {
      const res = await fetch(API_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });

      // Telegram throttling / API errors
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        console.warn("[telegram] delivery failed:", res.status, err.description || "");
        return false;
      }

      const data = await res.json();
      return Boolean(data.ok);
    } catch (err) {
      // Network failure, CORS, offline, etc. — swallow and report gracefully.
      console.warn("[telegram] network error:", err?.message || err);
      return false;
    }
  }

  return { send };
})();