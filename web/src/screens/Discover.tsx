// Mirrors DiscoverView.swift: Restaurants/Plans toggle, Featured section,
// cuisine chips (incl. AYCE/Buffet), search, plan cards with Deal + joined.
import { useMemo, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { fetchRestaurants, fetchAllActivePlans, fetchOffersMap, defaultPlanOrder } from "@/services/db";
import { restaurantName, restaurantDeals, dealToOffer, offerTitle, offerGroupBadge, topOffer, dealOffers, needsMorePeople, type Plan, type Restaurant, type RestaurantOffer } from "@/types";
import { t, localizedCuisine } from "@/i18n";
import { fetchPlanByCode } from "@/services/db";
import { Chip, EmptyState, Segmented, Spinner } from "@/components/ui";
import { useDragScroll } from "@/hooks/useDragScroll";
import { usePullToRefresh } from "@/hooks/usePullToRefresh";
import { trackDealClick, trackRestaurantClick } from "@/lib/analytics";

const DEALS_FILTER = "🔥 Deals";
const BUFFET_CATEGORY = "AYCE / Buffet";
const DEAL_KEYWORDS = ["優惠", "优惠", "买", "買", "送", "deal", "offer", "discount", "ayce", "buffet"];

function planHasDeal(p: Plan): boolean {
  const hay = `${p.notes} ${p.restaurant_name}`.toLowerCase();
  return DEAL_KEYWORDS.some((k) => hay.includes(k));
}
function featuredEligible(r: Restaurant): boolean {
  const deals = r.deals ?? [];
  if (deals.length === 0 || !r.last_deals_verified_at) return false;
  const ms = Date.now() - new Date(r.last_deals_verified_at).getTime();
  return ms < 14 * 24 * 60 * 60 * 1000;
}
function planTimeLabel(p: Plan): string {
  if (p.time_type === "asap") return t("ASAP");
  if (p.time_type === "flexible") {
    const day = t(p.flex_day === "weekend" ? "Weekend" : "Weekday");
    const meal = t(p.flex_meal === "dinner" ? "Dinner" : "Lunch");
    return `${day} ${meal}`;
  }
  return new Date(p.scheduled_at).toLocaleString(undefined, {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

export function Discover() {
  const nav = useNavigate();
  const [mode, setMode] = useState<"restaurants" | "plans">("restaurants");
  const [search, setSearch] = useState("");
  const [cuisine, setCuisine] = useState<string | null>(null);
  const restaurants = useQuery({ queryKey: ["restaurants"], queryFn: fetchRestaurants });
  const plans = useQuery({ queryKey: ["activePlans"], queryFn: fetchAllActivePlans });
  const offersQ = useQuery({ queryKey: ["offers"], queryFn: fetchOffersMap });

  const restaurantMap = Object.fromEntries((restaurants.data ?? []).map((r) => [r.id, r]));
  const offersMap = offersQ.data ?? {};

  // Offers-first, with legacy restaurants.deals as fallback when a restaurant
  // has no rows in restaurant_offers (or the table isn't there yet).
  const offersFor = (r: Restaurant): RestaurantOffer[] => {
    const o = offersMap[r.id];
    if (o && o.length) return o;
    return restaurantDeals(r).map((d, i) => dealToOffer(d, r.id, i));
  };
  const hasDealLike = (r: Restaurant) => dealOffers(offersFor(r)).length > 0;

  const [codeInput, setCodeInput] = useState("");
  const [codeBusy, setCodeBusy] = useState(false);

  async function lookupCode() {
    if (codeInput.trim().length < 3) return;
    setCodeBusy(true);
    try {
      const plan = await fetchPlanByCode(codeInput.trim());
      if (plan) nav(`/plan/${plan.id}`);
      else alert("No plan found for that code.");
    } finally {
      setCodeBusy(false);
    }
  }

  const cuisineScroll = useDragScroll<HTMLDivElement>();
  const { ref: pullRef, refreshing } = usePullToRefresh(async () => {
    await Promise.all([restaurants.refetch(), plans.refetch(), offersQ.refetch()]);
  });

  const cuisines = useMemo(() => {
    const list = Array.from(new Set((restaurants.data ?? []).map((r) => r.cuisine))).filter((c) => c !== BUFFET_CATEGORY).sort();
    if ((restaurants.data ?? []).some((r) => r.is_buffet)) list.unshift(BUFFET_CATEGORY);
    if ((restaurants.data ?? []).some(hasDealLike)) list.unshift(DEALS_FILTER);
    return list;
  }, [restaurants.data, offersMap]);

  const filtered = useMemo(() => {
    let rows = restaurants.data ?? [];
    if (cuisine) {
      if (cuisine === DEALS_FILTER)
        rows = rows.filter(hasDealLike);
      else if (cuisine === BUFFET_CATEGORY)
        rows = rows.filter((r) => r.is_buffet);
      else
        rows = rows.filter((r) => r.cuisine === cuisine);
    }
    if (search.trim()) {
      const q = search.toLowerCase();
      rows = rows.filter((r) =>
        r.name.toLowerCase().includes(q) ||
        r.cuisine.toLowerCase().includes(q) ||
        (r.name_zh_hans ?? "").includes(q) ||
        (r.name_zh_hant ?? "").includes(q)
      );
    }
    return rows;
  }, [restaurants.data, cuisine, search, offersMap]);

  const showFeatured = !search.trim();
  const featured = showFeatured ? filtered.filter(featuredEligible) : [];
  const general = showFeatured ? filtered.filter((r) => !featuredEligible(r)) : filtered;

  const visiblePlans = useMemo(
    () => (plans.data ?? []).filter((p) => needsMorePeople(p) > 0 && !p.attendance_confirmed_at).sort(defaultPlanOrder),
    [plans.data],
  );

  return (
    <div ref={pullRef} className="flex flex-col">
      {refreshing && <PullSpinner />}
      {/* Header */}
      <div className="px-5 pb-4 pt-3">
        <h1 className="leading-tight">
          <span className="font-sans text-[28px] font-light text-ink">{t("Find a ")}</span>
          <span className="font-accent text-[38px] italic text-clayDeep">{t("Deal")}</span>
        </h1>
        <p className="font-subtitle text-[13px] text-inkMuted">{t("Group dining offers near you")}</p>

        <div className="mt-3 flex items-center gap-2">
          <input
            className="pin-field flex-1 py-2 text-[13px]"
            placeholder="Have a code? e.g. PT482"
            value={codeInput}
            onChange={(e) => setCodeInput(e.target.value.toUpperCase().replace(/[^A-Z0-9]/g, ""))}
            onKeyDown={(e) => e.key === "Enter" && lookupCode()}
            autoCapitalize="characters"
            autoCorrect="off"
          />
          {codeInput.length >= 3 && (
            <button
              onClick={lookupCode}
              disabled={codeBusy}
              className="shrink-0 rounded-full bg-clay px-3 py-2 text-[12px] font-semibold text-cream"
            >
              {codeBusy ? "…" : "Go"}
            </button>
          )}
        </div>

        <div className="mt-3">
          <Segmented
            value={mode}
            onChange={setMode}
            options={[
              { value: "restaurants", label: t("Restaurants") },
              { value: "plans", label: t("Plans") },
            ]}
          />
        </div>

        {mode === "restaurants" && (
          <>
            <input
              className="pin-field mt-3"
              placeholder={t("Search restaurants or cuisine")}
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            <div
              ref={cuisineScroll}
              className="mt-3 flex cursor-grab select-none flex-nowrap gap-2 overflow-x-auto overscroll-x-contain pb-1 [-webkit-overflow-scrolling:touch] active:cursor-grabbing"
            >
              <CuisineChip label={t("All cuisines")} active={!cuisine} onClick={() => setCuisine(null)} />
              {cuisines.map((c) => (
                <CuisineChip
                  key={c}
                  label={localizedCuisine(c)}
                  active={cuisine === c}
                  onClick={() => setCuisine(cuisine === c ? null : c)}
                />
              ))}
            </div>
          </>
        )}
      </div>

      {/* Body */}
      {mode === "restaurants" ? (
        restaurants.isLoading ? (
          <Spinner label={t("Finding restaurants nearby…")} />
        ) : (
          <div className="space-y-3 px-5 pb-6">
            {showFeatured && featured.length > 0 && (
              <>
                <SectionHeader title={t("Featured")} />
                {featured.map((r) => (
                  <RestaurantCard key={r.id} r={r} offers={offersFor(r)} onClick={() => nav(`/restaurant/${r.id}`)} />
                ))}
                <SectionHeader title={t("All restaurants")} />
              </>
            )}
            {general.map((r) => (
              <RestaurantCard key={r.id} r={r} offers={offersFor(r)} onClick={() => nav(`/restaurant/${r.id}`)} />
            ))}
            {filtered.length === 0 && <EmptyState title={t("No restaurants yet")} emoji="🔍" />}
          </div>
        )
      ) : plans.isLoading ? (
        <Spinner />
      ) : visiblePlans.length === 0 ? (
        <EmptyState
          title={t("No active tables yet")}
          message={t("Start a table and find people to share a meal or deal.")}
          emoji="📍"
        />
      ) : (
        <div className="space-y-3 px-5 pb-6">
          {visiblePlans.map((p) => (
            <PlanCard key={p.id} p={p} rmap={restaurantMap} onClick={() => nav(`/plan/${p.id}`)} />
          ))}
        </div>
      )}
    </div>
  );
}

function PullSpinner() {
  return (
    <div className="flex justify-center py-3">
      <div className="h-5 w-5 animate-spin rounded-full border-2 border-clay/30 border-t-clay" />
    </div>
  );
}

function CuisineChip({ label, active, onClick }: { label: string; active: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className={`shrink-0 whitespace-nowrap rounded-full px-3.5 py-2 text-[13px] font-semibold ${
        active ? "bg-clay text-cream" : "bg-shell text-ink"
      }`}
    >
      {label}
    </button>
  );
}

function SectionHeader({ title }: { title: string }) {
  return <div className="pt-1 text-[13px] font-semibold uppercase tracking-wide text-inkMuted">{title}</div>;
}

function RestaurantCard({ r, offers, onClick }: { r: Restaurant; offers: RestaurantOffer[]; onClick: () => void }) {
  // The single most important offer: group-gated wins, then deal; highlights
  // never surface on the card.
  const top = topOffer(offers);
  const isGroup = top?.category === "group_gated";
  const groupBadge = isGroup ? offerGroupBadge(top) : null;
  const handleClick = () => {
    trackRestaurantClick(r.id);
    if (top) trackDealClick(top.id, r.id, { offer_type: top.offer_type, category: top.category });
    onClick();
  };
  return (
    <button onClick={handleClick} className="block w-full overflow-hidden rounded-card bg-shell text-left">
      {r.image_url && (
        <img src={r.image_url} alt="" className="h-32 w-full object-cover" loading="lazy" />
      )}
      <div className="p-3.5">
        <div className="flex items-center gap-2">
          <span className="font-sans text-[16px] font-medium text-ink">{restaurantName(r)}</span>
          {groupBadge && (
            <span className="rounded-full bg-clay/15 px-2 py-0.5 text-[11px] font-semibold text-clayDeep">
              {groupBadge}
            </span>
          )}
        </div>
        <div className="text-[13px] text-inkMuted">{localizedCuisine(r.cuisine)}</div>
        {top && (
          <div className={`mt-1.5 text-[13px] font-semibold ${isGroup ? "text-clayDeep" : "text-sunDeep"}`}>
            🔥 {offerTitle(top)}
          </div>
        )}
      </div>
    </button>
  );
}

function PlanCard({ p, rmap, onClick }: { p: Plan; rmap: Record<string, Restaurant>; onClick: () => void }) {
  const need = needsMorePeople(p);
  const name = rmap[p.restaurant_id] ? restaurantName(rmap[p.restaurant_id]) : p.restaurant_name;
  return (
    <button onClick={onClick} className="block w-full rounded-card bg-shell p-3.5 text-left">
      <div className="flex items-center gap-2">
        <span className="font-sans text-[15px] font-medium text-ink">{name}</span>
        {planHasDeal(p) && <Chip text={t("Deal")} tint="sun" />}
        <span className="ml-auto text-[12px] text-inkMuted">{planTimeLabel(p)}</span>
      </div>
      <div className="mt-2 flex items-center">
        <span className="text-[13px] text-inkMuted">{p.creator_name}</span>
        <span className="ml-auto">
          {need > 0 ? (
            <Chip text={t("%lld/%lld joined", p.current_people, p.needed_people)} tint="clay" />
          ) : (
            <Chip text={t("Full")} tint="sage" />
          )}
        </span>
      </div>
      {p.created_at && (
        <div className="mt-1 text-[11px] text-inkMuted">
          {new Date(p.created_at).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" })}
        </div>
      )}
    </button>
  );
}
