// Row shapes mirror the Supabase tables (snake_case) used by the iOS app, so
// the web client reads/writes the exact same data. See DealMates/Models/*.swift.

export interface Restaurant {
  id: string;
  name: string;
  cuisine: string;
  address: string | null;
  image_url: string | null;
  latitude: number | null;
  longitude: number | null;
  name_zh_hans: string | null;
  name_zh_hant: string | null;
  cuisine_zh_hans: string | null;
  cuisine_zh_hant: string | null;
  is_featured: boolean | null;
  is_buffet: boolean | null;
  image_fit: "cover" | "contain" | null;
  image_bg: string | null;
  last_deals_verified_at: string | null;
  plan_count: number | null;
}

export type TimeType = "asap" | "scheduled" | "flexible";
export type FlexDay = "weekday" | "weekend";
export type FlexMeal = "lunch" | "dinner";
export type GenderPreference = "any" | "female" | "male";

export interface Plan {
  id: string;
  restaurant_id: string;
  restaurant_name: string;
  creator_id: string;
  creator_name: string;
  creator_avatar_url: string | null;
  is_asap: boolean;
  scheduled_at: string;
  needed_people: number;
  current_people: number;
  member_ids: string[];
  notes: string;
  expires_at: string;
  reported_by: string[] | null;
  time_type: TimeType;
  flex_day: FlexDay | null;
  flex_meal: FlexMeal | null;
  gender_preference: GenderPreference;
  attendance_confirmed_at: string | null;
  created_at: string | null;
  event_code: string | null;
}

export interface AppUser {
  id: string;
  email: string | null;
  display_name: string;
  bio: string | null;
  avatar_url: string | null;
  gender: "female" | "male" | null;
  age: number | null;
  attended_count: number | null;
  attendance_record_count: number | null;
  hosted_count: number | null;
  is_anonymous: boolean | null;
  blocked_users: string[] | null;
  reported_plans: string[] | null;
}

export interface ChatMessage {
  id: string;
  plan_id: string;
  sender_id: string;
  sender_name: string;
  sender_avatar_url: string | null;
  text: string;
  timestamp: string;
  is_system: boolean;
  system_kind: string | null;
  system_args: string[] | null;
}

export interface DirectMessage {
  id: string;
  sender_id: string;
  sender_name: string;
  sender_avatar_url: string | null;
  recipient_id: string;
  recipient_name: string;
  recipient_avatar_url: string | null;
  text: string;
  timestamp: string;
}

export interface DMConversation {
  otherUserId: string;
  otherUserName: string;
  otherUserAvatarURL: string | null;
  lastMessage: string;
  lastTimestamp: string;
  lastSenderId: string;
}

export interface Poll {
  id: string;
  plan_id: string;
  creator_id: string;
  creator_name: string;
  question: string;
  options: string[];
  created_at: string | null;
}

export type OfferType = "buy_x_get_y" | "group_set_menu" | "min_diners_discount" | "other";
export type OfferCategory = "group_gated" | "deal" | "highlight";

// Normalized offer (restaurant_offers table) — the source of truth for promos.
export interface RestaurantOffer {
  id: string;
  restaurant_id: string;
  offer_order: number;
  title_en: string | null;
  title_zh_hans: string | null;
  title_zh_hant: string | null;
  description_en: string | null;
  description_zh_hans: string | null;
  description_zh_hant: string | null;
  offer_type: OfferType;
  category: OfferCategory;
  is_group_gated: boolean;
  is_deal_like: boolean;
  min_people: number | null;
  max_people: number | null;
  price_pp: number | null;
  currency: string | null;
  is_active: boolean;
}

// --- locale-aware accessors (mirror Restaurant.swift display* / AppLocale) ---

import { currentLang } from "./i18n";

export function restaurantName(r: Restaurant): string {
  const l = currentLang();
  if (l === "zh-Hans") return r.name_zh_hans || r.name;
  if (l === "zh-Hant") return r.name_zh_hant || r.name;
  return r.name;
}

export function offerTitle(o: RestaurantOffer): string {
  const l = currentLang();
  if (l === "zh-Hans") return o.title_zh_hans || o.title_en || "";
  if (l === "zh-Hant") return o.title_zh_hant || o.title_en || "";
  return o.title_en || "";
}

export function offerDescription(o: RestaurantOffer): string {
  const l = currentLang();
  if (l === "zh-Hans") return o.description_zh_hans || o.description_en || "";
  if (l === "zh-Hant") return o.description_zh_hant || o.description_en || "";
  return o.description_en || "";
}

/** Language-neutral group-gate badge (e.g. "👥 4+", "👥 2–4"), or null when the
 *  offer isn't group-gated. People icon + number avoids new i18n strings. */
export function offerGroupBadge(o: RestaurantOffer): string | null {
  if (!o.is_group_gated || o.min_people == null) return null;
  const { min_people: min, max_people: max } = o;
  if (max != null && max !== min) return `👥 ${min}–${max}`;
  if (max != null && max === min) return `👥 ${min}`;
  return `👥 ${min}+`;
}

/** Offers that belong in the Deals experience (everything except highlights). */
export function dealOffers(offers: RestaurantOffer[]): RestaurantOffer[] {
  return offers.filter((o) => o.category !== "highlight");
}

/** The single most important offer for a restaurant card: a group-gated offer
 *  wins, then any deal; highlights never surface here. Null if none. */
export function topOffer(offers: RestaurantOffer[]): RestaurantOffer | null {
  return offers.find((o) => o.category === "group_gated")
    ?? offers.find((o) => o.category === "deal")
    ?? null;
}

export function needsMorePeople(p: Plan): number {
  return Math.max(0, p.needed_people - p.current_people);
}
