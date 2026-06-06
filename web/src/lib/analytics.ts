// Minimal first-party analytics — anonymous guests only, stored in Supabase
// (analytics_events). No third-party tooling. Fire-and-forget; never blocks UI.
import { supabase } from "@/lib/supabase";

const GUEST_KEY = "pintable_guest_id";

/** Stable per-browser anonymous id, created on first use. */
export function guestId(): string {
  let id = localStorage.getItem(GUEST_KEY);
  if (!id) {
    id = crypto.randomUUID();
    localStorage.setItem(GUEST_KEY, id);
  }
  return id;
}

interface TrackOpts {
  page_path?: string | null;
  deal_id?: string | null;
  metadata?: Record<string, unknown> | null;
}

function track(event_name: string, opts: TrackOpts = {}): void {
  void supabase
    .from("analytics_events")
    .insert({
      guest_id: guestId(),
      event_name,
      page_path: opts.page_path ?? null,
      deal_id: opts.deal_id ?? null,
      metadata: opts.metadata ?? null,
    })
    .then(({ error }) => {
      if (error) console.debug("[analytics] insert failed:", error.message);
    });
}

export function trackPageView(path: string): void {
  track("page_view", { page_path: path });
}

export function trackDealClick(dealId: string, metadata?: Record<string, unknown>): void {
  track("deal_click", { deal_id: dealId, metadata });
}
