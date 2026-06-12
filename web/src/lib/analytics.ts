// Minimal first-party analytics — anonymous guests only, stored in Supabase
// (analytics_events). No third-party tooling. Fire-and-forget; never blocks UI.
import { supabase } from "@/lib/supabase";

const GUEST_KEY = "pintable_guest_id";
const SESSION_KEY = "pintable_session_id";
const OWNER_KEY = "pintable_owner";

// Founder self-tagging: visiting the site with ?owner=1 marks THIS browser as the
// owner's, so every event it sends carries is_owner=true and can be filtered out
// of "real visitor" counts (?owner=0 clears it). Read once at load, then stripped
// from the URL so it isn't shared. Persists in localStorage — incognito windows
// keep no localStorage, so those still rely on IP exclusion.
(function initOwnerFlag() {
  try {
    const params = new URLSearchParams(window.location.search);
    const flag = params.get("owner");
    if (flag === "1") localStorage.setItem(OWNER_KEY, "1");
    else if (flag === "0") localStorage.removeItem(OWNER_KEY);
    if (flag !== null) {
      params.delete("owner");
      const qs = params.toString();
      window.history.replaceState({}, "", window.location.pathname + (qs ? `?${qs}` : "") + window.location.hash);
    }
  } catch {
    /* localStorage/history unavailable — ignore */
  }
})();

/** True when this browser has been tagged as the owner's (via ?owner=1). */
export function isOwner(): boolean {
  try {
    return localStorage.getItem(OWNER_KEY) === "1";
  } catch {
    return false;
  }
}

/** Stable per-browser anonymous id, created on first use (localStorage). */
export function guestId(): string {
  let id = localStorage.getItem(GUEST_KEY);
  if (!id) {
    id = crypto.randomUUID();
    localStorage.setItem(GUEST_KEY, id);
  }
  return id;
}

/** Per-browser-session id, created once per session (sessionStorage). */
export function sessionId(): string {
  let id = sessionStorage.getItem(SESSION_KEY);
  if (!id) {
    id = crypto.randomUUID();
    sessionStorage.setItem(SESSION_KEY, id);
  }
  return id;
}

// The signed-in / anonymous auth user id, so events join to the users table
// (member_no / display_name). Set from AuthContext when the profile loads.
let currentUserId: string | null = null;
export function setAnalyticsUser(uid: string | null): void {
  currentUserId = uid;
}

interface TrackOpts {
  page_path?: string | null;
  restaurant_id?: string | null;
  offer_id?: string | null;
  plan_id?: string | null;
  metadata?: Record<string, unknown> | null;
}

function track(event_name: string, opts: TrackOpts = {}): void {
  void supabase
    .from("analytics_events")
    .insert({
      event_name,
      user_id: currentUserId,
      guest_id: guestId(),
      session_id: sessionId(),
      page_path: opts.page_path ?? null,
      restaurant_id: opts.restaurant_id ?? null,
      offer_id: opts.offer_id ?? null,
      plan_id: opts.plan_id ?? null,
      metadata: opts.metadata ?? null,
      is_owner: isOwner(),
    })
    .then(({ error }) => {
      if (error) console.debug("[analytics] insert failed:", error.message);
    });
}

// --- Screen time: session_start + heartbeat (while visible) + session_end ---

const SESSION_START_KEY = "pintable_session_start";

function sessionElapsedMs(): number {
  const start = Number(sessionStorage.getItem(SESSION_START_KEY) || Date.now());
  return Date.now() - start;
}

/** Start screen-time tracking for this session. Returns a cleanup function. */
export function startScreenTimeTracking(): () => void {
  if (!sessionStorage.getItem(SESSION_START_KEY)) {
    sessionStorage.setItem(SESSION_START_KEY, String(Date.now()));
    track("session_start");
  }
  const HEARTBEAT_MS = 30_000;
  const beat = () => {
    if (!document.hidden) track("session_heartbeat", { metadata: { elapsed_ms: sessionElapsedMs() } });
  };
  const timer = window.setInterval(beat, HEARTBEAT_MS);
  const onHide = () => track("session_end", { metadata: { duration_ms: sessionElapsedMs() } });
  document.addEventListener("visibilitychange", () => { if (document.hidden) onHide(); });
  window.addEventListener("pagehide", onHide);
  return () => {
    window.clearInterval(timer);
    window.removeEventListener("pagehide", onHide);
  };
}

export function trackPageView(path: string): void {
  track("page_view", { page_path: path });
}

export function trackDealClick(offerId: string, restaurantId: string, metadata?: Record<string, unknown>): void {
  track("deal_click", { offer_id: offerId, restaurant_id: restaurantId, metadata });
}

export function trackRestaurantClick(restaurantId: string): void {
  track("restaurant_click", { restaurant_id: restaurantId });
}

export function trackJoinClick(planId: string, restaurantId?: string | null): void {
  track("join_click", { plan_id: planId, restaurant_id: restaurantId ?? null });
}

export function trackCreatePlanClick(restaurantId?: string | null): void {
  track("create_plan_click", { restaurant_id: restaurantId ?? null });
}

export function trackGuestJoinSuccess(planId: string, restaurantId?: string | null): void {
  track("guest_join_success", { plan_id: planId, restaurant_id: restaurantId ?? null });
}
