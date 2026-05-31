// notify-on-plan
//
// Webhook handler for public.plans. Handles two event shapes:
//
//   INSERT  → notify subscribers of the restaurant ("new plan posted")
//   UPDATE  → detect members joining or the raft becoming full and
//             push the relevant alert to the affected members
//
// The Supabase webhook needs to be configured to fire on both events.
//
// Secrets (Settings → Functions → Secrets):
//   APNS_KEY_ID
//   APNS_TEAM_ID
//   APNS_BUNDLE_ID  (default com.jj.DealMates)
//   APNS_AUTH_KEY
//   APNS_HOST       (api.sandbox.push.apple.com or api.push.apple.com)

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const APNS_KEY_ID    = Deno.env.get("APNS_KEY_ID")!;
const APNS_TEAM_ID   = Deno.env.get("APNS_TEAM_ID")!;
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID") ?? "com.jj.DealMates";
const APNS_AUTH_KEY  = Deno.env.get("APNS_AUTH_KEY")!;
const APNS_HOST      = Deno.env.get("APNS_HOST") ?? "api.sandbox.push.apple.com";

// ───────── JWT for APNs ─────────

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

// ───────── APNs send ─────────

interface PushBody {
  title: string;
  body: string;
  planId: string;
}

async function sendOne(token: string, push: PushBody, jwt: string) {
  const body = JSON.stringify({
    aps: {
      alert: { title: push.title, body: push.body },
      sound: "default",
    },
    plan_id: push.planId,
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

// ───────── Row shapes ─────────

interface PlanRecord {
  id: string;
  restaurant_id: string;
  restaurant_name: string;
  creator_id: string;
  creator_name: string;
  member_ids: string[];
  current_people: number;
  needed_people: number;
}

interface TokenRow {
  user_id: string;
  token: string;
  notification_preference: string; // "off" | "subscribed" | "all"
}

// ───────── INSERT path (existing behavior) ─────────

async function handleInsert(supabase: SupabaseClient, plan: PlanRecord, jwt: string) {
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

  const eligible = (tokens ?? []).filter((t: TokenRow) => {
    if (t.user_id === plan.creator_id) return false;
    if (t.notification_preference === "off") return false;
    if (t.notification_preference === "all") return true;
    return subscribedIds.includes(t.user_id);
  });

  if (eligible.length === 0) return { sent: 0 };

  await Promise.all(eligible.map((t: TokenRow) =>
    sendOne(t.token, {
      title: `New plan at ${plan.restaurant_name}`,
      body:  `${plan.creator_name} just created a plan`,
      planId: plan.id,
    }, jwt)
  ));
  return { sent: eligible.length };
}

// ───────── UPDATE path: member joined / raft just full ─────────

async function handleUpdate(
  supabase: SupabaseClient,
  plan: PlanRecord,
  oldPlan: PlanRecord,
  jwt: string,
) {
  const oldMembers = oldPlan.member_ids ?? [];
  const newMembers = plan.member_ids ?? [];
  const added = newMembers.filter((m: string) => !oldMembers.includes(m));

  // Bail out if no one joined — this UPDATE was a different field
  // (attendance confirmation, lock-in time, edit, etc.).
  if (added.length === 0) return { sent: 0, reason: "no_new_members" };

  const wasFull = oldPlan.current_people >= oldPlan.needed_people;
  const isFull  = plan.current_people  >= plan.needed_people;
  const justFilled = !wasFull && isFull;

  // Fetch the joining member's display name(s) so the push reads naturally.
  const { data: addedUsers } = await supabase
    .from("users")
    .select("id, display_name")
    .in("id", added);
  const nameById = new Map<string, string>(
    (addedUsers ?? []).map((u: { id: string; display_name: string }) => [u.id, u.display_name])
  );
  const namesLabel = added.length === 1
    ? (nameById.get(added[0]) ?? "Someone")
    : `${added.length} new puffins`;

  // Push tokens for every member of the raft. We then filter recipients per case.
  const { data: tokenRows } = await supabase
    .from("device_tokens")
    .select("user_id, token, notification_preference")
    .in("user_id", newMembers);
  const tokens: TokenRow[] = (tokenRows ?? []).filter(
    (t: TokenRow) => t.notification_preference !== "off"
  );

  // Member-joined → notify existing members (excluding the joiner).
  const joinRecipients = tokens.filter((t) => !added.includes(t.user_id));
  await Promise.all(joinRecipients.map((t) =>
    sendOne(t.token, {
      title: `New raft member at ${plan.restaurant_name}`,
      body:  `${namesLabel} joined the pin.`,
      planId: plan.id,
    }, jwt)
  ));

  // Raft-just-full → notify everyone in the raft (including the new joiner).
  let fullSent = 0;
  if (justFilled) {
    await Promise.all(tokens.map((t) =>
      sendOne(t.token, {
        title: `Your raft at ${plan.restaurant_name} is ready 🎉`,
        body:  `Everyone's in. Time to lock in the meet-up.`,
        planId: plan.id,
      }, jwt)
    ));
    fullSent = tokens.length;
  }

  return { sent: joinRecipients.length + fullSent, joined: joinRecipients.length, full: fullSent };
}

// ───────── Entry point ─────────

Deno.serve(async (req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const payload = await req.json();
  const type = (payload?.type as string) ?? "INSERT";
  const plan = payload?.record as PlanRecord | undefined;
  const oldPlan = payload?.old_record as PlanRecord | undefined;
  if (!plan?.id || !plan?.restaurant_id) {
    return new Response("ignored", { status: 200 });
  }

  const jwt = await makeJWT();

  let result: unknown;
  if (type === "INSERT") {
    result = await handleInsert(supabase, plan, jwt);
  } else if (type === "UPDATE" && oldPlan) {
    result = await handleUpdate(supabase, plan, oldPlan, jwt);
  } else {
    result = { sent: 0, reason: "unsupported_event" };
  }

  return new Response(JSON.stringify(result), {
    headers: { "content-type": "application/json" },
  });
});
