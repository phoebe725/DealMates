// Data access — mirrors DealMates/Services/DatabaseService.swift against the
// same tables. Read paths first (Discover); write/realtime paths are added as
// the matching screens are ported.

import { supabase } from "@/lib/supabase";
import type { AppUser, ChatMessage, DirectMessage, DMConversation, Plan, Poll, PollVote, Restaurant, RestaurantOffer } from "@/types";

export async function fetchRestaurants(): Promise<Restaurant[]> {
  const { data, error } = await supabase
    .from("restaurants")
    .select("*")
    .order("name", { ascending: true });
  if (error) throw error;
  return (data ?? []) as Restaurant[];
}

/** All active offers, grouped by restaurant_id and ordered. Returns {} if the
 *  restaurant_offers table is missing or errors. */
export async function fetchOffersMap(): Promise<Record<string, RestaurantOffer[]>> {
  const { data, error } = await supabase
    .from("restaurant_offers")
    .select("*")
    .eq("is_active", true)
    .order("offer_order", { ascending: true });
  if (error || !data) return {};
  const map: Record<string, RestaurantOffer[]> = {};
  for (const o of data as RestaurantOffer[]) (map[o.restaurant_id] ??= []).push(o);
  return map;
}

/** Active offers for one restaurant (empty array if none / table missing). */
export async function fetchRestaurantOffers(restaurantId: string): Promise<RestaurantOffer[]> {
  const { data, error } = await supabase
    .from("restaurant_offers")
    .select("*")
    .eq("restaurant_id", restaurantId)
    .eq("is_active", true)
    .order("offer_order", { ascending: true });
  if (error || !data) return [];
  return data as RestaurantOffer[];
}

export async function fetchRestaurant(id: string): Promise<Restaurant | null> {
  const { data, error } = await supabase
    .from("restaurants")
    .select("*")
    .eq("id", id)
    .limit(1);
  if (error) throw error;
  return ((data ?? [])[0] as Restaurant) ?? null;
}

/** All non-expired plans (the Discover "Plans" feed). */
export async function fetchAllActivePlans(): Promise<Plan[]> {
  const { data, error } = await supabase
    .from("plans")
    .select("*")
    .gt("expires_at", new Date().toISOString())
    .order("scheduled_at", { ascending: true });
  if (error) throw error;
  return (data ?? []) as Plan[];
}

/** Active plans at one restaurant (restaurant board). */
export async function fetchActivePlans(restaurantId: string): Promise<Plan[]> {
  const { data, error } = await supabase
    .from("plans")
    .select("*")
    .eq("restaurant_id", restaurantId)
    .gt("expires_at", new Date().toISOString())
    .order("scheduled_at", { ascending: true });
  if (error) throw error;
  return (data ?? []) as Plan[];
}

export async function updateProfile(
  uid: string,
  fields: { display_name?: string; bio?: string; avatar_url?: string },
): Promise<void> {
  const { error } = await supabase
    .from("users")
    .update({ ...fields, updated_at: new Date().toISOString() })
    .eq("id", uid);
  if (error) throw error;
}

/** Upload to the public `avatars` bucket ({uid}.jpg) + return a cache-busted URL. */
export async function uploadAvatar(uid: string, file: File): Promise<string> {
  const path = `${uid}.jpg`;
  const { error } = await supabase.storage
    .from("avatars")
    .upload(path, file, { upsert: true, contentType: file.type || "image/jpeg" });
  if (error) throw error;
  const { data } = supabase.storage.from("avatars").getPublicUrl(path);
  return `${data.publicUrl}?t=${Date.now()}`;
}

export async function fetchUsers(ids: string[]): Promise<AppUser[]> {
  if (ids.length === 0) return [];
  const { data, error } = await supabase.from("users").select("*").in("id", ids);
  if (error) throw error;
  return (data ?? []) as AppUser[];
}

export async function fetchPlan(id: string): Promise<Plan | null> {
  const { data, error } = await supabase.from("plans").select("*").eq("id", id).limit(1);
  if (error) throw error;
  return ((data ?? [])[0] as Plan) ?? null;
}

/** Plans the user is a member of (My Plans). */
export async function fetchMyPlans(userId: string): Promise<Plan[]> {
  const { data, error } = await supabase
    .from("plans")
    .select("*")
    .contains("member_ids", [userId])
    .order("scheduled_at", { ascending: false });
  if (error) throw error;
  return (data ?? []) as Plan[];
}

/** The user's non-expired plans — the plan chats shown in Messages. */
export async function fetchMyActivePlans(userId: string): Promise<Plan[]> {
  const { data, error } = await supabase
    .from("plans")
    .select("*")
    .contains("member_ids", [userId])
    .gt("expires_at", new Date().toISOString());
  if (error) throw error;
  return (data ?? []) as Plan[];
}

/** The user's plans whose attendance hasn't been confirmed yet.
 *  Drives unread badge counts. */
export async function fetchMyOpenPlans(userId: string): Promise<Plan[]> {
  const { data, error } = await supabase
    .from("plans")
    .select("*")
    .contains("member_ids", [userId])
    .is("attendance_confirmed_at", null);
  if (error) throw error;
  return (data ?? []) as Plan[];
}

/** System messages (joins/leaves/etc.) across the given plans — used to count
 *  unread plan *actions* for the My Plans tab badge. */
export async function fetchSystemMessages(planIds: string[]): Promise<ChatMessage[]> {
  if (planIds.length === 0) return [];
  const { data, error } = await supabase
    .from("messages")
    .select("*")
    .in("plan_id", planIds)
    .eq("is_system", true);
  if (error) throw error;
  return (data ?? []) as ChatMessage[];
}

/** Latest message per plan (for Messages subtitles). */
export async function fetchLatestMessages(planIds: string[]): Promise<Record<string, ChatMessage>> {
  if (planIds.length === 0) return {};
  const { data, error } = await supabase
    .from("messages")
    .select("*")
    .in("plan_id", planIds)
    .order("timestamp", { ascending: false });
  if (error) throw error;
  const latest: Record<string, ChatMessage> = {};
  for (const m of (data ?? []) as ChatMessage[]) if (!latest[m.plan_id]) latest[m.plan_id] = m;
  return latest;
}

// ----- Direct messages (mirror DatabaseService DM methods) -----

export async function fetchConversations(currentUid: string): Promise<DMConversation[]> {
  const { data, error } = await supabase
    .from("direct_messages")
    .select("*")
    .or(`sender_id.eq.${currentUid},recipient_id.eq.${currentUid}`)
    .order("timestamp", { ascending: false });
  if (error) throw error;
  const map = new Map<string, DMConversation>();
  for (const m of (data ?? []) as DirectMessage[]) {
    const out = m.sender_id === currentUid;
    const otherId = out ? m.recipient_id : m.sender_id;
    if (!map.has(otherId))
      map.set(otherId, {
        otherUserId: otherId,
        otherUserName: out ? m.recipient_name : m.sender_name,
        otherUserAvatarURL: out ? m.recipient_avatar_url : m.sender_avatar_url,
        lastMessage: m.text,
        lastTimestamp: m.timestamp,
        lastSenderId: m.sender_id,
      });
  }
  return [...map.values()].sort((a, b) => b.lastTimestamp.localeCompare(a.lastTimestamp));
}

export async function fetchDirectMessages(currentUid: string, otherUid: string): Promise<DirectMessage[]> {
  const { data, error } = await supabase
    .from("direct_messages")
    .select("*")
    .or(
      `and(sender_id.eq.${currentUid},recipient_id.eq.${otherUid}),and(sender_id.eq.${otherUid},recipient_id.eq.${currentUid})`,
    )
    .order("timestamp", { ascending: true });
  if (error) throw error;
  return (data ?? []) as DirectMessage[];
}

export async function sendDirectMessage(
  from: AppUser,
  to: { id: string; name: string; avatar: string | null },
  text: string,
): Promise<void> {
  const { error } = await supabase.from("direct_messages").insert({
    id: crypto.randomUUID(),
    sender_id: from.id,
    sender_name: from.display_name,
    sender_avatar_url: from.avatar_url ?? null,
    recipient_id: to.id,
    recipient_name: to.name,
    recipient_avatar_url: to.avatar,
    text,
    timestamp: new Date().toISOString(),
  });
  if (error) throw error;
}

export function listenToDirectMessages(
  currentUid: string,
  otherUid: string,
  onInsert: (m: DirectMessage) => void,
): () => void {
  const channel = supabase
    .channel(`dm:${currentUid}:${otherUid}:${crypto.randomUUID()}`)
    .on("postgres_changes", { event: "INSERT", schema: "public", table: "direct_messages" }, (payload) => {
      const m = payload.new as DirectMessage;
      const pair =
        (m.sender_id === currentUid && m.recipient_id === otherUid) ||
        (m.sender_id === otherUid && m.recipient_id === currentUid);
      if (pair) onInsert(m);
    })
    .subscribe();
  return () => {
    supabase.removeChannel(channel);
  };
}

export async function createPlan(plan: Plan): Promise<void> {
  const { error } = await supabase.from("plans").insert(plan);
  if (error) throw error;
}

/** Organiser edit — update the plan's editable fields (id/creator/members kept). */
export async function updatePlan(plan: Plan): Promise<void> {
  const { error } = await supabase
    .from("plans")
    .update({
      is_asap: plan.is_asap,
      scheduled_at: plan.scheduled_at,
      time_type: plan.time_type,
      flex_day: plan.flex_day,
      flex_meal: plan.flex_meal,
      needed_people: plan.needed_people,
      current_people: plan.current_people,
      gender_preference: plan.gender_preference,
      notes: plan.notes,
      expires_at: plan.expires_at,
    })
    .eq("id", plan.id);
  if (error) throw error;
}

/** Organiser cancel — delete the plan. */
export async function deletePlan(id: string): Promise<void> {
  const { error } = await supabase.from("plans").delete().eq("id", id);
  if (error) throw error;
}

/** Look up a plan by its short event code (e.g. PT482). Case-insensitive. */
export async function fetchPlanByCode(code: string): Promise<Plan | null> {
  const { data, error } = await supabase
    .from("plans")
    .select("*")
    .ilike("event_code", code.trim())
    .limit(1);
  if (error) throw error;
  return ((data ?? [])[0] as Plan) ?? null;
}

// ----- Join / leave (mirror DatabaseService.joinPlan / leavePlan) -----

export async function joinPlan(plan: Plan, userId: string, userName: string): Promise<void> {
  if (plan.member_ids.includes(userId)) return;
  const member_ids = [...plan.member_ids, userId];
  const { error } = await supabase
    .from("plans")
    .update({ member_ids, current_people: member_ids.length })
    .eq("id", plan.id);
  if (error) throw error;
  await postSystemMessage(plan.id, "joined", [userName]);
}

export async function leavePlan(plan: Plan, userId: string, userName: string): Promise<void> {
  if (!plan.member_ids.includes(userId)) return;
  const member_ids = plan.member_ids.filter((id) => id !== userId);
  // Organiser succession: if the creator leaves and members remain, promote the
  // next-earliest member (mirrors DatabaseService.leavePlan).
  if (plan.creator_id === userId && member_ids.length > 0) {
    const next = (await fetchUsers([member_ids[0]]))[0];
    if (next) {
      const { error } = await supabase
        .from("plans")
        .update({
          member_ids,
          current_people: member_ids.length,
          creator_id: next.id,
          creator_name: next.display_name,
          creator_avatar_url: next.avatar_url ?? null,
        })
        .eq("id", plan.id);
      if (error) throw error;
      await postSystemMessage(plan.id, "left_promoted", [userName, next.display_name]);
      return;
    }
  }
  const { error } = await supabase
    .from("plans")
    .update({ member_ids, current_people: member_ids.length })
    .eq("id", plan.id);
  if (error) throw error;
  await postSystemMessage(plan.id, "left", [userName]);
}

/** Organiser kicks a non-organiser member (mirrors DatabaseService.removeMember). */
export async function removeMember(
  plan: Plan,
  targetUid: string,
  targetName: string,
  removerName: string,
): Promise<void> {
  if (!plan.member_ids.includes(targetUid) || plan.creator_id === targetUid) return;
  const member_ids = plan.member_ids.filter((id) => id !== targetUid);
  const { error } = await supabase
    .from("plans")
    .update({ member_ids, current_people: member_ids.length })
    .eq("id", plan.id);
  if (error) throw error;
  await postSystemMessage(plan.id, "removed", [removerName, targetName]);
}

/** Organiser locks an ASAP/flexible plan to a concrete time (mirrors
 *  DatabaseService.setPlanScheduledTime): becomes scheduled, expiry +2h. */
export async function setPlanScheduledTime(planId: string, scheduledAt: Date): Promise<void> {
  const expiry = new Date(scheduledAt.getTime() + 2 * 3600_000);
  const { error } = await supabase
    .from("plans")
    .update({
      scheduled_at: scheduledAt.toISOString(),
      time_type: "scheduled",
      is_asap: false,
      flex_day: null,
      flex_meal: null,
      expires_at: expiry.toISOString(),
    })
    .eq("id", planId);
  if (error) throw error;
}

/** Records who attended a completed plan (mirrors DatabaseService.confirmAttendance):
 *  increments attended/hosted counts atomically via the confirm_plan_attendance RPC. */
export async function confirmAttendance(planId: string, attendedUserIds: string[]): Promise<void> {
  const { error } = await supabase.rpc("confirm_plan_attendance", {
    p_plan_id: planId,
    p_attended: attendedUserIds,
  });
  if (error) throw error;
}

// ----- Plan chat (mirror messages table + listenToMessages) -----

export async function fetchMessages(planId: string): Promise<ChatMessage[]> {
  const { data, error } = await supabase
    .from("messages")
    .select("*")
    .eq("plan_id", planId)
    .order("timestamp", { ascending: true });
  if (error) throw error;
  return (data ?? []) as ChatMessage[];
}

export async function sendMessage(planId: string, sender: AppUser, text: string): Promise<void> {
  const { error } = await supabase.from("messages").insert({
    id: crypto.randomUUID(),
    plan_id: planId,
    sender_id: sender.id,
    sender_name: sender.display_name,
    sender_avatar_url: sender.avatar_url ?? null,
    text,
    is_system: false,
    timestamp: new Date().toISOString(),
  });
  if (error) throw error;
}

async function postSystemMessage(planId: string, kind: string, args: string[]): Promise<void> {
  await supabase.from("messages").insert({
    id: crypto.randomUUID(),
    plan_id: planId,
    sender_id: "system",
    sender_name: "system",
    text: "",
    is_system: true,
    system_kind: kind,
    system_args: args,
    timestamp: new Date().toISOString(),
  });
}

/** Realtime new-message subscription for a plan. Returns an unsubscribe fn. */
export function listenToMessages(planId: string, onInsert: (m: ChatMessage) => void): () => void {
  const channel = supabase
    .channel(`messages:${planId}:${crypto.randomUUID()}`)
    .on(
      "postgres_changes",
      { event: "INSERT", schema: "public", table: "messages", filter: `plan_id=eq.${planId}` },
      (payload) => onInsert(payload.new as ChatMessage),
    )
    .subscribe();
  return () => {
    supabase.removeChannel(channel);
  };
}

/** Realtime updates for a single plan row (membership/time changes). */
export function listenToPlan(planId: string, onUpdate: (p: Plan) => void): () => void {
  const channel = supabase
    .channel(`plan:${planId}:${crypto.randomUUID()}`)
    .on(
      "postgres_changes",
      { event: "UPDATE", schema: "public", table: "plans", filter: `id=eq.${planId}` },
      (payload) => onUpdate(payload.new as Plan),
    )
    .subscribe();
  return () => {
    supabase.removeChannel(channel);
  };
}

// ----- Polls (mirror DatabaseService polls section) -----

export async function fetchPolls(planId: string): Promise<Poll[]> {
  const { data, error } = await supabase
    .from("polls")
    .select("*")
    .eq("plan_id", planId)
    .order("created_at", { ascending: false });
  if (error) throw error;
  return (data ?? []) as Poll[];
}

export async function fetchVotes(planId: string): Promise<PollVote[]> {
  const { data: polls } = await supabase.from("polls").select("id").eq("plan_id", planId);
  const ids = (polls ?? []).map((p) => (p as { id: string }).id);
  if (ids.length === 0) return [];
  const { data, error } = await supabase.from("poll_votes").select("*").in("poll_id", ids);
  if (error) throw error;
  return (data ?? []) as PollVote[];
}

export async function createPoll(poll: Poll): Promise<void> {
  const { error } = await supabase.from("polls").insert(poll);
  if (error) throw error;
}

/** Cast/replace a vote. Delete-then-insert avoids composite-key upsert syntax
 *  (mirrors DatabaseService.castVote). */
export async function castVote(vote: PollVote): Promise<void> {
  await supabase.from("poll_votes").delete().eq("poll_id", vote.poll_id).eq("user_id", vote.user_id);
  const { error } = await supabase.from("poll_votes").insert(vote);
  if (error) throw error;
}

/** Realtime for a plan's polls + votes. Returns an unsubscribe fn. */
export function listenToPolls(planId: string, onChange: () => void): () => void {
  const channel = supabase
    .channel(`polls:${planId}:${crypto.randomUUID()}`)
    .on("postgres_changes", { event: "*", schema: "public", table: "polls", filter: `plan_id=eq.${planId}` }, () => onChange())
    .on("postgres_changes", { event: "*", schema: "public", table: "poll_votes" }, () => onChange())
    .subscribe();
  return () => {
    supabase.removeChannel(channel);
  };
}

// ----- Report / block (mirror AuthService.reportPlan / blockUser) -----

export async function reportPlan(reporterUid: string, planId: string): Promise<void> {
  const { data: u } = await supabase.from("users").select("reported_plans").eq("id", reporterUid).single();
  const reported = ((u?.reported_plans as string[] | null) ?? []);
  if (!reported.includes(planId)) {
    await supabase.from("users").update({ reported_plans: [...reported, planId] }).eq("id", reporterUid);
  }
  const { data: p } = await supabase.from("plans").select("reported_by").eq("id", planId).single();
  const by = ((p?.reported_by as string[] | null) ?? []);
  if (!by.includes(reporterUid)) {
    await supabase.from("plans").update({ reported_by: [...by, reporterUid] }).eq("id", planId);
  }
}

export async function blockUser(blockerUid: string, targetUid: string): Promise<void> {
  const { data: u } = await supabase.from("users").select("blocked_users").eq("id", blockerUid).single();
  const blocked = ((u?.blocked_users as string[] | null) ?? []);
  if (blocked.includes(targetUid)) return;
  await supabase.from("users").update({ blocked_users: [...blocked, targetUid] }).eq("id", blockerUid);
}

// ----- Account-wide realtime (mirror listenToAll* — drive unread badges) -----

/** Any new chat message anywhere. */
export function listenToAllMessageInserts(onChange: () => void): () => void {
  const channel = supabase
    .channel(`all-messages:${crypto.randomUUID()}`)
    .on("postgres_changes", { event: "INSERT", schema: "public", table: "messages" }, () => onChange())
    .subscribe();
  return () => { supabase.removeChannel(channel); };
}

/** Any new direct message anywhere. */
export function listenToAllDMInserts(onChange: () => void): () => void {
  const channel = supabase
    .channel(`all-dms:${crypto.randomUUID()}`)
    .on("postgres_changes", { event: "INSERT", schema: "public", table: "direct_messages" }, () => onChange())
    .subscribe();
  return () => { supabase.removeChannel(channel); };
}

/** Any plan change (insert/update/delete) — e.g. a member joined or attendance
 *  was confirmed — so badges repaint even from another tab. */
export function listenToAllPlanChanges(onChange: () => void): () => void {
  const channel = supabase
    .channel(`all-plans:${crypto.randomUUID()}`)
    .on("postgres_changes", { event: "*", schema: "public", table: "plans" }, () => onChange())
    .subscribe();
  return () => { supabase.removeChannel(channel); };
}

/** Default plan ordering (mirrors Plan.defaultOrder): timed plans soonest
 *  first, then untimed (asap/flexible) newest-created first. */
export function defaultPlanOrder(a: Plan, b: Plan): number {
  const at = a.time_type === "scheduled";
  const bt = b.time_type === "scheduled";
  if (at !== bt) return at ? -1 : 1;
  if (at) return a.scheduled_at.localeCompare(b.scheduled_at);
  return (b.created_at ?? "").localeCompare(a.created_at ?? "");
}
