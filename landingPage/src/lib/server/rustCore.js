import { env } from "$env/dynamic/private";

export const UPGRADE_CODE_RE = /^[0-9a-f]{32}$/;

const TIMEOUT_MS = 20_000;

/**
 * Calls the Rust core service. The browser never talks to it directly:
 * Rust has no CORS, and keeping the URL server-side avoids exposing it.
 *
 * @param {string} path
 * @param {RequestInit} [init]
 * @returns {Promise<{ ok: boolean, status: number, body: any }>}
 */
export async function rustCore(path, init = {}) {
  const base = env.RUST_CORE_URL?.replace(/\/+$/, "");
  if (!base) {
    console.error("RUST_CORE_URL is not configured");
    return {
      ok: false,
      status: 503,
      body: { error: "Payments are temporarily unavailable." },
    };
  }

  try {
    const res = await fetch(`${base}${path}`, {
      ...init,
      headers: { "content-type": "application/json", ...init.headers },
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    const body = await res.json().catch(() => ({}));
    return { ok: res.ok, status: res.status, body };
  } catch (e) {
    console.error("Rust core request failed:", e instanceof Error ? e.message : e);
    return {
      ok: false,
      status: 502,
      body: { error: "Could not reach the payment service. Please try again." },
    };
  }
}
