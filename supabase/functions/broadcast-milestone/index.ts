// Invoked by the `trg_impact_milestone_fcm` trigger on public.platform_stats
// (function public.notify_impact_milestone_fcm) via pg_net. Secrets are read
// from public.app_secrets: `broadcast_secret` and `firebase_service_account`.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { initializeApp, cert, getApps } from "npm:firebase-admin@12/app";
import { getMessaging } from "npm:firebase-admin@12/messaging";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

// Global state to cache Firebase app initialization
let isFirebaseInitialized = false;

async function ensureFirebase() {
  if (isFirebaseInitialized && getApps().length > 0) {
    return;
  }

  // Query secrets from database table
  const { data: secrets, error } = await supabase
    .from("app_secrets")
    .select("key, value");

  if (error) {
    throw new Error(`Failed to fetch app secrets: ${error.message}`);
  }

  const serviceAccountValue = secrets?.find((s) => s.key === "firebase_service_account")?.value;
  if (!serviceAccountValue) {
    throw new Error("firebase_service_account secret not found in database app_secrets table");
  }

  const serviceAccount = JSON.parse(serviceAccountValue);

  if (!getApps().length) {
    initializeApp({ credential: cert(serviceAccount) });
  }
  isFirebaseInitialized = true;
}

Deno.serve(async (req) => {
  try {
    // 1. Fetch broadcast secret from db to validate request
    const { data: secrets, error: secretsError } = await supabase
      .from("app_secrets")
      .select("key, value")
      .eq("key", "broadcast_secret")
      .single();

    if (secretsError || !secrets) {
      return new Response("Unauthorized: Server misconfigured (no broadcast secret)", { status: 401 });
    }

    if (req.headers.get("x-broadcast-secret") !== secrets.value) {
      return new Response("Unauthorized: Invalid secret", { status: 401 });
    }

    // 2. Parse request body
    const { milestone, books_circulated } = await req.json();

    // 3. Initialize Firebase using database credentials
    await ensureFirebase();

    // 4. Send topic notification
    const response = await getMessaging().send({
      topic: "bookbridge_milestones",
      notification: {
        title: "BookBridge milestone reached! 🎉",
        body: `We just circulated book #${milestone}! Together we're making education accessible across Cameroon.`,
      },
      data: {
        type: "impact_milestone",
        milestone: String(milestone),
        books_circulated: String(books_circulated),
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    return new Response(JSON.stringify({ ok: true, messageId: response }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message || String(error) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
