// notify-on-plan
//
// Called by a Supabase Database Webhook on INSERT to public.plans.
// Looks up subscribers of the new plan's restaurant + all "notify all" device tokens,
// then sends an APNs alert push to each token via APNs HTTP/2.
//
// Secrets needed (set in Supabase Dashboard → Settings → Functions → Secrets):
//   APNS_KEY_ID       — your APNs Auth Key ID (10 chars)
//   APNS_TEAM_ID      — your Apple Developer Team ID (10 chars)
//   APNS_BUNDLE_ID    — bundle id, e.g. com.jj.DealMates
//   APNS_AUTH_KEY     — the FULL contents of your AuthKey_XXXXXXXXXX.p8 file
//   APNS_HOST         — "api.sandbox.push.apple.com" (dev) or "api.push.apple.com" (prod)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const APNS_KEY_ID    = Deno.env.get("APNS_KEY_ID")!;
const APNS_TEAM_ID   = Deno.env.get("APNS_TEAM_ID")!;
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID") ?? "com.jj.DealMates";
const APNS_AUTH_KEY  = Deno.env.get("APNS_AUTH_KEY")!;
const APNS_HOST      = Deno.env.get("APNS_HOST") ?? "api.sandbox.push.apple.com";

const enc = (o: unknown) =>
  btoa(JSON.stringify(o)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

async function importP8(pem: string): Promise<CryptoKey> {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    bytes,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
}

async function makeJWT(): Promise<string> {
  const header = { alg: "ES256", kid: APNS_KEY_ID };
  const claims = { iss: APNS_TEAM_ID, iat: Math.floor(Date.now() / 1000) };
  const unsigned = `${enc(header)}.${enc(claims)}`;
  const key = await importP8(APNS_AUTH_KEY);
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(unsigned),
  );
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  return `${unsigned}.${sigB64}`;
}

interface PlanRecord {
  id: string;
  restaurant_id: string;
  restaurant_name: string;
  creator_id: string;
  creator_name: string;
}

async function sendOne(token: string, plan: PlanRecord, jwt: string) {
  const body = JSON.stringify({
    aps: {
      alert: {
        title: `New plan at ${plan.restaurant_name}`,
        body:  `${plan.creator_name} just created a plan`,
      },
      sound: "default",
    },
    plan_id: plan.id,
  });
  const res = await fetch(`https://${APNS_HOST}/3/device/${token}`, {
    method: "POST",
    headers: {
      "authorization":  `bearer ${jwt}`,
      "apns-topic":     APNS_BUNDLE_ID,
      "apns-push-type": "alert",
      "apns-priority":  "10",
      "content-type":   "application/json",
    },
    body,
  });
  if (!res.ok) {
    console.error("APNs failed", token.slice(0, 8), res.status, await res.text());
  }
}

Deno.serve(async (req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const payload = await req.json();
  const plan = payload?.record as PlanRecord | undefined;
  if (!plan?.id || !plan?.restaurant_id) {
    return new Response("ignored", { status: 200 });
  }

  const { data: subs } = await supabase
    .from("restaurant_subscriptions")
    .select("user_id")
    .eq("restaurant_id", plan.restaurant_id);
  const subscribedIds = (subs ?? [])
    .map((s: { user_id: string }) => s.user_id)
    .filter((u) => u !== plan.creator_id);

  const { data: tokens } = await supabase
    .from("device_tokens")
    .select("user_id, token, notification_preference");

  const eligible = (tokens ?? []).filter((t: { user_id: string; notification_preference: string }) => {
    if (t.user_id === plan.creator_id) return false;
    if (t.notification_preference === "off") return false;
    if (t.notification_preference === "all") return true;
    return subscribedIds.includes(t.user_id);
  });

  if (eligible.length === 0) {
    return new Response(JSON.stringify({ sent: 0 }), {
      headers: { "content-type": "application/json" },
    });
  }

  const jwt = await makeJWT();
  await Promise.all(eligible.map((t) => sendOne(t.token, plan, jwt)));

  return new Response(JSON.stringify({ sent: eligible.length }), {
    headers: { "content-type": "application/json" },
  });
});
