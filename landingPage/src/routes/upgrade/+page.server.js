import { fail } from "@sveltejs/kit";
import { rustCore, UPGRADE_CODE_RE } from "$lib/server/rustCore.js";

const MEDIUMS = new Set(["mobile money", "orange money"]);
const DEFAULTS = { priceXaf: 500, days: 30 };

/** @type {import('./$types').PageServerLoad} */
export async function load({ url, setHeaders }) {
  setHeaders({ "cache-control": "no-store" });

  const code = url.searchParams.get("code") ?? "";
  if (!UPGRADE_CODE_RE.test(code)) {
    return { ...DEFAULTS, code: "", status: "INVALID", error: "" };
  }

  const res = await rustCore(
    `/subscriptions/status?code=${encodeURIComponent(code)}`,
  );
  if (res.status === 404) {
    return { ...DEFAULTS, code: "", status: "INVALID", error: "" };
  }
  if (!res.ok) {
    return {
      ...DEFAULTS,
      code,
      status: "ERROR",
      error: res.body?.error ?? "Something went wrong.",
    };
  }

  return {
    code,
    status: String(res.body.status ?? ""),
    priceXaf: Number(res.body.price_xaf ?? DEFAULTS.priceXaf),
    days: Number(res.body.days ?? DEFAULTS.days),
    error: "",
  };
}

/** @type {import('./$types').Actions} */
export const actions = {
  default: async ({ request }) => {
    const form = await request.formData();
    const code = String(form.get("code") ?? "");
    const phone = String(form.get("phone") ?? "").trim();
    const medium = String(form.get("medium") ?? "");

    if (!UPGRADE_CODE_RE.test(code)) {
      return fail(400, { phone, medium, error: "This upgrade link is invalid." });
    }
    if (!/^6\d{8}$/.test(phone.replace(/\D/g, "").replace(/^237/, ""))) {
      return fail(400, {
        phone,
        medium,
        error: "Enter a 9-digit Cameroonian mobile number starting with 6.",
      });
    }
    if (!MEDIUMS.has(medium)) {
      return fail(400, { phone, medium, error: "Choose MTN or Orange Money." });
    }

    const res = await rustCore("/subscriptions/initiate", {
      method: "POST",
      body: JSON.stringify({ code, phone, medium }),
    });
    if (!res.ok) {
      return fail(res.status, {
        phone,
        medium,
        error: res.body?.error ?? "Payment could not be started.",
      });
    }
    return { started: true };
  },
};
