import { error } from "@sveltejs/kit";
import { createClient } from "@supabase/supabase-js";
import { env } from "$env/dynamic/private";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Public listing preview only: never select seller identity or contact fields.
const PUBLIC_LISTING_SELECT =
  "id,title,author,price_fcfa,condition,image_url,image_urls,status,school:schools!school_id(name)";

/** @type {import('@supabase/supabase-js').SupabaseClient | undefined} */
let supabase;

function getSupabase() {
  const key = env.SUPABASE_ANON_KEY;
  if (!supabase && env.SUPABASE_URL && key) {
    supabase = createClient(env.SUPABASE_URL, key, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
  }
  return supabase;
}

/** @type {import('./$types').PageServerLoad} */
export async function load({ params, setHeaders }) {
  if (!UUID_RE.test(params.id)) {
    error(404, "Listing not found");
  }

  const client = getSupabase();
  if (!client) {
    console.error(
      "Listing preview: SUPABASE_URL / SUPABASE_ANON_KEY not configured",
    );
    return { id: params.id, listing: null };
  }

  const { data, error: dbError } = await client
    .from("listings")
    .select(PUBLIC_LISTING_SELECT)
    .eq("id", params.id)
    .maybeSingle();

  if (dbError) {
    console.error("Listing preview query failed:", dbError.message);
    return { id: params.id, listing: null };
  }

  setHeaders({ "cache-control": "public, max-age=300" });

  if (!data) {
    return { id: params.id, listing: null };
  }

  const images = Array.isArray(data.image_urls)
    ? data.image_urls.filter(Boolean)
    : [];
  const school = Array.isArray(data.school) ? data.school[0] : data.school;

  return {
    id: params.id,
    listing: {
      title: data.title ?? "",
      author: data.author ?? "",
      priceFcfa: data.price_fcfa ?? 0,
      condition: data.condition ?? "",
      imageUrl: images[0] || data.image_url || "",
      status: data.status ?? "available",
      schoolName: school?.name ?? "",
    },
  };
}
