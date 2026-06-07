// Mirrors DiscoverView.swift: Restaurants/Plans toggle, Featured section,
// cuisine chips (incl. AYCE/Buffet), search, plan cards with Deal + joined.
import { useMemo, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { fetchRestaurants, fetchAllActivePlans, fetchOffersMap, defaultPlanOrder } from "@/services/db";
import { restaurantName, dealOffers, needsMorePeople, type Plan, type Restaurant, type RestaurantOffer } from "@/types";
import { t, localizedCuisine } from "@/i18n";
import { useAuth } from "@/auth/AuthContext";
import { fetchPlanByCode } from "@/services/db";
import { Chip, EmptyState, RestaurantImage, Segmented, Spinner } from "@/components/ui";
import { useDragScroll } from "@/hooks/useDragScroll";
import { usePullToRefresh } from "@/hooks/usePullToRefresh";
import { trackDealClick, trackRestaurantClick } from "@/lib/analytics";
import { bestOffer, offerShortLabel, dealKind, DEAL_FILTERS, matchesDealFilter, type DealFilter } from "@/lib/dealDisplay";

const BUFFET_CATEGORY = "AYCE / Buffet";
const DEAL_KEYWORDS = ["優惠", "优惠", "买", "買", "送", "deal", "offer", "discount", "ayce", "buffet"];

function planHasDeal(p: Plan): boolean {
  const hay = `${p.notes} ${p.restaurant_name}`.toLowerCase();
  return DEAL_KEYWORDS.some((k) => hay.includes(k));
}
// Featured: the restaurant has at least one real deal offer and was verified
// within the last 14 days. Offers are the source of truth now.
function featuredEligible(r: Restaurant, offers: RestaurantOffer[]): boolean {
  if (dealOffers(offers).length === 0 || !r.last_deals_verified_at) return false;
  const ms = Date.now() - new Date(r.last_deals_verified_at).getTime();
  return ms < 14 * 24 * 60 * 60 * 1000;
}
// Haversine distance in metres; restaurants without coordinates sort last.
function distanceMeters(loc: { lat: number; lng: number }, r: Restaurant): number {
  if (r.latitude == null || r.longitude == null) return Infinity;
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(r.latitude - loc.lat);
  const dLng = toRad(r.longitude - loc.lng);
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(loc.lat)) * Math.cos(toRad(r.latitude)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
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
  const { isSignedIn } = useAuth();
  const [mode, setMode] = useState<"restaurants" | "plans">("restaurants");
  const [search, setSearch] = useState("");
  const [dealFilter, setDealFilter] = useState<DealFilter | null>(null);
  const [cuisine, setCuisine] = useState<string | null>(null);
  const [sort, setSort] = useState<"name" | "distance">("name");
  const [userLoc, setUserLoc] = useState<{ lat: number; lng: number } | null>(null);
  const [sortOpen, setSortOpen] = useState(false);
  const restaurants = useQuery({ queryKey: ["restaurants"], queryFn: fetchRestaurants });
  const plans = useQuery({ queryKey: ["activePlans"], queryFn: fetchAllActivePlans });
  const offersQ = useQuery({ queryKey: ["offers"], queryFn: fetchOffersMap });

  const restaurantMap = Object.fromEntries((restaurants.data ?? []).map((r) => [r.id, r]));
  const offersMap = offersQ.data ?? {};

  const offersFor = (r: Restaurant): RestaurantOffer[] => offersMap[r.id] ?? [];

  const [codeInput, setCodeInput] = useState("");
  const [codeBusy, setCodeBusy] = useState(false);

  async function lookupCode() {
    if (codeInput.trim().length < 3) return;
    setCodeBusy(true);
    try {
      const plan = await fetchPlanByCode(codeInput.trim());
      if (plan) nav(`/plan/${plan.id}`);
      else alert(t("No plan found for that code."));
    } finally {
      setCodeBusy(false);
    }
  }

  const cuisineScroll = useDragScroll<HTMLDivElement>();
  const { ref: pullRef, refreshing } = usePullToRefresh(async () => {
    await Promise.all([restaurants.refetch(), plans.refetch(), offersQ.refetch()]);
  });

  // Cuisine chips are pure cuisines now — AYCE/Buffet lives in the deal filters.
  const cuisines = useMemo(
    () => Array.from(new Set((restaurants.data ?? []).map((r) => r.cuisine)))
      .filter((c) => c !== BUFFET_CATEGORY)
      .sort(),
    [restaurants.data],
  );

  // Deal filters only show when at least one restaurant qualifies for them.
  const dealFilters = useMemo(
    () => DEAL_FILTERS.filter((f) => (restaurants.data ?? []).some((r) => matchesDealFilter(offersFor(r), f.value))),
    [restaurants.data, offersMap],
  );

  const filtered = useMemo(() => {
    let rows = restaurants.data ?? [];
    if (dealFilter) rows = rows.filter((r) => matchesDealFilter(offersFor(r), dealFilter));
    if (cuisine) rows = rows.filter((r) => r.cuisine === cuisine);
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
  }, [restaurants.data, dealFilter, cuisine, search, offersMap]);

  const showFeatured = !search.trim();
  const featured = showFeatured ? filtered.filter((r) => featuredEligible(r, offersFor(r))) : [];
  const general = showFeatured ? filtered.filter((r) => !featuredEligible(r, offersFor(r))) : filtered;

  // Pick "Nearest" → grab the browser location once (sort falls back to featured
  // order until it arrives / if permission is denied).
  function chooseNearest() {
    setSort("distance");
    if (!userLoc && typeof navigator !== "undefined" && navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (pos) => setUserLoc({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
        () => {},
        { enableHighAccuracy: false, timeout: 8000 },
      );
    }
  }

  const restaurantsToShow = useMemo(() => {
    if (sort === "distance" && userLoc) {
      return [...filtered].sort((a, b) => distanceMeters(userLoc, a) - distanceMeters(userLoc, b));
    }
    return showFeatured ? [...featured, ...general] : general;
  }, [sort, userLoc, filtered, featured, general, showFeatured]);

  const visiblePlans = useMemo(
    () => (plans.data ?? []).filter((p) => needsMorePeople(p) > 0 && !p.attendance_confirmed_at).sort(defaultPlanOrder),
    [plans.data],
  );

  return (
    <div ref={pullRef} className="flex flex-col">
      {refreshing && <PullSpinner />}
      {/* Header */}
      <div className="px-5 pb-4 pt-3">
        <div className="flex items-start justify-between">
          <h1 className="leading-tight">
            <span className="font-sans text-[28px] font-light text-ink">{t("Find ")}</span>
            <span className="font-accent text-[38px] italic text-clayDeep">{t("Deals")}</span>
          </h1>
          <div className="mt-1 flex items-center gap-2">
            <button
              onClick={() => nav("/map")}
              aria-label={t("Map")}
              className="flex h-9 w-9 items-center justify-center rounded-full bg-shell text-ink"
            >
              <svg width={20} height={20} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round">
                <path d="M9 18l-6 3V6l6-3 6 3 6-3v15l-6 3-6-3Z" />
                <path d="M9 3v15M15 6v15" />
              </svg>
            </button>
            <div className="relative">
              <button
                onClick={() => setSortOpen((o) => !o)}
                aria-label={t("Sort")}
                className={`flex h-9 w-9 items-center justify-center rounded-full ${sort === "distance" ? "bg-clay text-cream" : "bg-shell text-ink"}`}
              >
                <svg width={20} height={20} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round">
                  <line x1="4" y1="6" x2="20" y2="6" />
                  <line x1="7" y1="12" x2="17" y2="12" />
                  <line x1="10" y1="18" x2="14" y2="18" />
                </svg>
              </button>
              {sortOpen && (
                <>
                  <div className="fixed inset-0 z-10" onClick={() => setSortOpen(false)} />
                  <div className="absolute right-0 z-20 mt-1 w-36 overflow-hidden rounded-card bg-cream shadow-lg ring-1 ring-fog">
                    <button
                      className={`block w-full px-4 py-2.5 text-left text-[14px] ${sort === "name" ? "font-semibold text-clay" : "text-ink"}`}
                      onClick={() => { setSort("name"); setSortOpen(false); }}
                    >
                      {t("A–Z")}
                    </button>
                    <button
                      className={`block w-full px-4 py-2.5 text-left text-[14px] ${sort === "distance" ? "font-semibold text-clay" : "text-ink"}`}
                      onClick={() => { chooseNearest(); setSortOpen(false); }}
                    >
                      📍 {t("Nearest")}
                    </button>
                  </div>
                </>
              )}
            </div>
          </div>
        </div>
        <p className="font-subtitle text-[13px] text-inkMuted">{t(isSignedIn ? "Group dining offers near me" : "Group dining offers near you")}</p>

        <div className="mt-3 flex items-center gap-2">
          <input
            className="pin-field flex-1 py-2 text-[13px]"
            placeholder={t("Have a code? e.g. PT482")}
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
              {codeBusy ? "…" : t("Go")}
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

            {/* Deal filters — value categories, separate from cuisine */}
            {dealFilters.length > 0 && (
              <div className="mt-3 flex flex-nowrap gap-2 overflow-x-auto overscroll-x-contain pb-1 [-webkit-overflow-scrolling:touch]">
                {dealFilters.map((f) => (
                  <CuisineChip
                    key={f.value}
                    label={`${f.emoji} ${t(f.key)}`}
                    active={dealFilter === f.value}
                    onClick={() => setDealFilter(dealFilter === f.value ? null : f.value)}
                  />
                ))}
              </div>
            )}

            {/* Cuisine filters — pure cuisines */}
            <div
              ref={cuisineScroll}
              className="mt-2 flex cursor-grab select-none flex-nowrap gap-2 overflow-x-auto overscroll-x-contain pb-1 [-webkit-overflow-scrolling:touch] active:cursor-grabbing"
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
            {/* One continuous list — featured deals sort to the top, or by distance when "Nearest". */}
            {restaurantsToShow.map((r) => (
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


function RestaurantCard({ r, offers, onClick }: { r: Restaurant; offers: RestaurantOffer[]; onClick: () => void }) {
  // Strongest offer (for click tracking), plus every deal to show as pills.
  const top = bestOffer(offers);
  const deals = dealOffers(offers);
  const handleClick = () => {
    trackRestaurantClick(r.id);
    if (top) trackDealClick(top.id, r.id, { offer_type: top.offer_type, category: top.category });
    onClick();
  };
  return (
    <button onClick={handleClick} className="block w-full overflow-hidden rounded-card bg-shell text-left">
      <RestaurantImage r={r} className="h-32 w-full" />
      <div className="p-3.5">
        <span className="font-sans text-[16px] font-medium text-ink">{restaurantName(r)}</span>
        <div className="text-[13px] text-inkMuted">{localizedCuisine(r.cuisine)}</div>
        {deals.length > 0 && (
          // All deals on one row, each in a tinted pill; swipe horizontally if they overflow.
          <div className="mt-2 flex gap-1.5 overflow-x-auto pb-0.5 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
            {deals.map((o) => {
              const l = offerShortLabel(o);
              const group = dealKind(o) === "group";
              return (
                <span
                  key={o.id}
                  className={`shrink-0 whitespace-nowrap rounded-full px-2.5 py-1 text-[12px] font-semibold ${
                    group ? "bg-clay/15 text-clayDeep" : "bg-sun/20 text-sunDeep"
                  }`}
                >
                  {l.emoji} {l.text}
                </span>
              );
            })}
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
