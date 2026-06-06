// Minimal first-party analytics — anonymous guests only, stored in Supabase
// (analytics_events). No third-party tooling. Fire-and-forget; never blocks UI.
import { supabase } from "@/lib/supabase";

const GUEST_KEY = "pintable_guest_id";
const SESSION_KEY = "pintable_session_id";

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
      guest_id: guestId(),
      session_id: sessionId(),
      page_path: opts.page_path ?? null,
      restaurant_id: opts.restaurant_id ?? null,
      offer_id: opts.offer_id ?? null,
      plan_id: opts.plan_id ?? null,
      metadata: opts.metadata ?? null,
    })
    .then(({ error }) => {
      if (error) console.debug("[analytics] insert failed:", error.message);
    });
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
