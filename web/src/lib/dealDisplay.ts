// Value-oriented display layer for offers — pure UI derivation from the existing
// restaurant_offers fields (no schema change). Produces short, attractive card
// labels, the deal-filter taxonomy, and the card-priority ordering.
import { offerTitle, type RestaurantOffer } from "@/types";
import { t } from "@/i18n";

export type DealKind = "group" | "ayce" | "discount" | "student" | "member" | "lunch" | "other";

/** Split an offer description into its distinct terms. The curated data uses
 *  " · " as the separator between conditions (e.g. "£32.80pp for 2+ · £45 solo
 *  · 20% off 12–17"); a single-clause description returns one element. */
export function splitTerms(desc: string): string[] {
  return desc.split("·").map((s) => s.trim()).filter(Boolean);
}


function en(o: RestaurantOffer): string {
  return `${o.title_en ?? ""} ${o.description_en ?? ""}`.toLowerCase();
}

/** Percentage in the offer text, e.g. "20% off" → 20. Null if none. */
function pct(o: RestaurantOffer): number | null {
  const m = `${o.title_en ?? ""} ${o.description_en ?? ""}`.match(/(\d{1,2})\s*%/);
  return m ? parseInt(m[1], 10) : null;
}

/** Classify an offer into a deal sub-kind (English text is the signal). */
export function dealKind(o: RestaurantOffer): DealKind {
  if (o.category === "group_gated") return "group";
  const s = en(o);
  if (/student/.test(s)) return "student";
  if (/member/.test(s)) return "member";
  if (/all[ -]you[ -]can[ -]eat|ayce|buffet|unlimited|yum cha|steam pot|malatang/.test(s)) return "ayce";
  if (/%|\boff\b|discount|tastecard|first table|save/.test(s)) return "discount";
  if (/lunch/.test(s)) return "lunch";
  return "other";
}

/** Card priority — lower wins. Group > AYCE > discount > student > member > lunch > other. */
const PRIORITY: Record<DealKind, number> = {
  group: 0, ayce: 1, discount: 2, student: 3, member: 4, lunch: 5, other: 6,
};

/** Among an offer list, the strongest one to feature on a card (deals only). */
export function bestOffer(offers: RestaurantOffer[]): RestaurantOffer | null {
  const deals = offers.filter((o) => o.category !== "highlight");
  if (deals.length === 0) return null;
  return deals.slice().sort((a, b) => PRIORITY[dealKind(a)] - PRIORITY[dealKind(b)])[0];
}

export interface ShortLabel { emoji: string; text: string; }

/** Short, value-oriented, localized label for a card or deal heading. */
export function offerShortLabel(o: RestaurantOffer): ShortLabel {
  const kind = dealKind(o);
  const s = en(o);
  switch (kind) {
    case "group": {
      const bg = s.match(/buy\s*(\d+)\s*get\s*(\d+)/);
      if (bg) return { emoji: "👥", text: t("Buy %lld get %lld free", +bg[1], +bg[2]) };
      if (o.price_pp != null) return { emoji: "👥", text: t("AYCE from £%@", String(o.price_pp)) };
      if (o.offer_type === "group_set_menu") return { emoji: "👥", text: t("Group set menu") };
      const p = pct(o);
      return p ? { emoji: "👥", text: t("Group deal: save %lld%", p) } : { emoji: "👥", text: t("Group deal") };
    }
    case "ayce":
      return o.price_pp != null
        ? { emoji: "🍽", text: t("AYCE from £%@", String(o.price_pp)) }
        : { emoji: "🍽", text: t("All you can eat") };
    case "discount": {
      const p = pct(o);
      return { emoji: "💸", text: p ? t("Save %lld%", p) : t("Special offer") };
    }
    case "student": return { emoji: "🎓", text: t("Student deal") };
    case "member":  return { emoji: "💳", text: t("Member discount") };
    case "lunch":   return { emoji: "🍜", text: t("Lunch set") };
    default:        return { emoji: "🔥", text: offerTitle(o) };
  }
}

// ----- Deal filters (separate from cuisine) -----

export type DealFilter = "all" | "group" | "ayce" | "discount" | "student" | "member";

export const DEAL_FILTERS: { value: DealFilter; emoji: string; key: string }[] = [
  { value: "all",      emoji: "🔥", key: "All Deals" },
  { value: "group",    emoji: "👥", key: "Group Deals" },
  { value: "ayce",     emoji: "🍽", key: "AYCE / Buffet" },
  { value: "student",  emoji: "🎓", key: "Student" },
  { value: "member",   emoji: "💳", key: "Member" },
];

/** Does this restaurant's offer set satisfy the given deal filter? */
export function matchesDealFilter(offers: RestaurantOffer[], f: DealFilter): boolean {
  const deals = offers.filter((o) => o.category !== "highlight");
  if (deals.length === 0) return false;
  if (f === "all") return true;
  return deals.some((o) => dealKind(o) === f);
}
