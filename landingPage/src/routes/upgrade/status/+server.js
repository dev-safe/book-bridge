import { json } from "@sveltejs/kit";
import { rustCore, UPGRADE_CODE_RE } from "$lib/server/rustCore.js";

/** @type {import('./$types').RequestHandler} */
export async function GET({ url }) {
  const code = url.searchParams.get("code") ?? "";
  if (!UPGRADE_CODE_RE.test(code)) {
    return json({ error: "Invalid upgrade link" }, { status: 400 });
  }

  const res = await rustCore(
    `/subscriptions/status?code=${encodeURIComponent(code)}`,
  );
  return json(
    res.ok ? { status: String(res.body.status ?? "") } : { error: res.body?.error },
    { status: res.ok ? 200 : res.status, headers: { "cache-control": "no-store" } },
  );
}
