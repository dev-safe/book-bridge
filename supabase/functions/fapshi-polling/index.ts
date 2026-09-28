import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function adminClient() {
  return createClient(supabaseUrl, supabaseServiceKey);
}

function resp(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  try {
    // Validate cron secret
    const supabase = adminClient();
    const cronSecret = req.headers.get("x-cron-secret");
    const { data: secretRow } = await supabase
      .from("app_secrets")
      .select("value")
      .eq("key", "broadcast_secret")
      .single();

    if (!cronSecret || cronSecret !== secretRow?.value) {
      return resp(401, { error: "Unauthorized" });
    }

    // Retrieve Fapshi credentials from database secrets
    const { data: userRow } = await supabase
      .from("app_secrets")
      .select("value")
      .eq("key", "fapshi_api_user")
      .single();
    const { data: keyRow } = await supabase
      .from("app_secrets")
      .select("value")
      .eq("key", "fapshi_api_key")
      .single();

    const fapshiApiUser = userRow?.value;
    const fapshiApiKey = keyRow?.value;

    if (!fapshiApiUser || !fapshiApiKey) {
      return resp(500, { error: "Fapshi API credentials not configured in app_secrets" });
    }

    // Find all transactions stuck in pending_payment for more than 10 minutes
    const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000).toISOString();
    const { data: txs, error: txsErr } = await supabase
      .from("transactions")
      .select("id, payment_reference, listing_id, buyer_id, seller_id, amount")
      .eq("status", "pending_payment")
      .lte("created_at", tenMinutesAgo);

    if (txsErr) {
      return resp(500, { error: txsErr.message });
    }

    const results: Array<{ id: string; reference: string; status: string; error?: string }> = [];

    for (const tx of txs ?? []) {
      const reference = tx.payment_reference;
      try {
        console.log(`Checking Fapshi status for transaction ref: ${reference}`);
        const fapshiRes = await fetch(`https://api.fapshi.com/payment-status/${reference}`, {
          method: "GET",
          headers: {
            "apiuser": fapshiApiUser,
            "apikey": fapshiApiKey,
          },
        });

        if (!fapshiRes.ok) {
          const errMsg = await fapshiRes.text();
          results.push({ id: tx.id, reference, status: "error", error: `Fapshi error: ${fapshiRes.status} - ${errMsg}` });
          console.error(`Fapshi status check failed for ${reference}: ${fapshiRes.status} - ${errMsg}`);
          continue;
        }

        const data = await fapshiRes.json();
        const fapshiStatus = data.status || data.state;
        console.log(`Fapshi status for ${reference} is ${fapshiStatus}`);

        if (fapshiStatus === "SUCCESSFUL" || fapshiStatus === "SUCCESS") {
          // Process successful payment
          // 1. Mark listing as sold
          await supabase
            .from("listings")
            .update({ status: "sold" })
            .eq("id", tx.listing_id);

          // 2. Update transaction status to held (since escrow is enabled)
          await supabase
            .from("transactions")
            .update({ status: "held" })
            .eq("id", tx.id);

          // 3. Create escrow transaction
          await supabase
            .from("escrow_transactions")
            .upsert({
              transaction_id: tx.id,
              status: "held",
              created_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            }, { onConflict: "transaction_id" });

          // 4. Send automated chat message
          await supabase
            .from("messages")
            .insert({
              listing_id: tx.listing_id,
              sender_id: tx.buyer_id,
              receiver_id: tx.seller_id,
              content: "Hello! I just purchased this book via BookBridge. When can we meet to complete the exchange?",
              is_read: false,
              created_at: new Date().toISOString(),
            });

          results.push({ id: tx.id, reference, status: "held" });
        } else if (fapshiStatus === "FAILED" || fapshiStatus === "EXPIRED") {
          // Mark transaction as failed
          await supabase
            .from("transactions")
            .update({ status: "failed" })
            .eq("id", tx.id);

          results.push({ id: tx.id, reference, status: "failed" });
        } else {
          // Still pending/created
          results.push({ id: tx.id, reference, status: fapshiStatus });
        }
      } catch (err) {
        results.push({ id: tx.id, reference, status: "error", error: String(err) });
        console.error(`Error processing status check for ${reference}:`, err);
      }
    }

    return resp(200, { processed: results.length, results });
  } catch (err) {
    console.error("fapshi-polling unhandled error:", err);
    return resp(500, { error: String(err) });
  }
});
