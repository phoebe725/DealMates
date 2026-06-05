// Mirrors DiscoverView.swift: Restaurants/Plans toggle, Featured section,
// cuisine chips (incl. AYCE/Buffet), search, plan cards with Deal + joined.
import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { fetchRestaurants, fetchAllActivePlans, defaultPlanOrder } from "@/services/db";
import { restaurantName, restaurantDeals, needsMorePeople, type Plan, type Restaurant } from "@/types";
import { t, localizedCuisine } from "@/i18n";
import { Chip, EmptyState, Segmented, Spinner } from "@/components/ui";
import { useDragScroll } from "@/hooks/useDragScroll";

const BUFFET_CATEGORY = "AYCE / Buffet";
const BUFFET_IDS = new Set([
  "e6f9a2b3-3a4d-4e7f-6c8b-9e1d3e5a8c1e", // Yauatcha
  "a2b56d7e-8c9f-4a3b-2e4d-5a6f8a1c4e6a", // Happy Lamb
  "a2b5c7d8-8c9f-4a3b-2e4d-5a6f8a1c4e6a", // Eat Tokyo
]);
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
  const cuisineScroll = useDragScroll<HTMLDivElement>();

  const restaurants = useQuery({ queryKey: ["restaurants"], queryFn: fetchRestaurants });
  const plans = useQuery({ queryKey: ["activePlans"], queryFn: fetchAllActivePlans });

  const cuisines = useMemo(() => {
    const list = Array.from(new Set((restaurants.data ?? []).map((r) => r.cuisine))).sort();
    if ((restaurants.data ?? []).some((r) => BUFFET_IDS.has(r.id))) list.unshift(BUFFET_CATEGORY);
    return list;
  }, [restaurants.data]);

  const filtered = useMemo(() => {
    let rows = restaurants.data ?? [];
    if (cuisine) {
      rows = cuisine === BUFFET_CATEGORY ? rows.filter((r) => BUFFET_IDS.has(r.id)) : rows.filter((r) => r.cuisine === cuisine);
    }
    if (search.trim()) {
      const q = search.toLowerCase();
      rows = rows.filter((r) => r.name.toLowerCase().includes(q) || r.cuisine.toLowerCase().includes(q));
    }
    return rows;
  }, [restaurants.data, cuisine, search]);

  const showFeatured = !search.trim();
  const featured = showFeatured ? filtered.filter(featuredEligible) : [];
  const general = showFeatured ? filtered.filter((r) => !featuredEligible(r)) : filtered;

  const visiblePlans = useMemo(
    () => (plans.data ?? []).filter((p) => needsMorePeople(p) > 0 && !p.attendance_confirmed_at).sort(defaultPlanOrder),
    [plans.data],
  );

  return (
    <div className="flex flex-col">
      {/* Header */}
      <div className="px-5 pb-4 pt-3">
        <h1 className="leading-tight">
          <span className="font-sans text-[28px] font-light text-ink">{t("Find a ")}</span>
          <span className="font-accent text-[38px] italic text-clayDeep">{t("Table")}</span>
        </h1>
        <p className="font-subtitle text-[13px] text-inkMuted">{t("Join dining plans nearby")}</p>

        <div className="mt-4">
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
                  <RestaurantCard key={r.id} r={r} onClick={() => nav(`/restaurant/${r.id}`)} />
                ))}
                <SectionHeader title={t("All restaurants")} />
              </>
            )}
            {general.map((r) => (
              <RestaurantCard key={r.id} r={r} onClick={() => nav(`/restaurant/${r.id}`)} />
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
            <PlanCard key={p.id} p={p} onClick={() => nav(`/plan/${p.id}`)} />
          ))}
        </div>
      )}
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

function RestaurantCard({ r, onClick }: { r: Restaurant; onClick: () => void }) {
  return (
    <button onClick={onClick} className="block w-full overflow-hidden rounded-card bg-shell text-left">
      {r.image_url && (
        <img src={r.image_url} alt="" className="h-32 w-full object-cover" loading="lazy" />
      )}
      <div className="p-3.5">
        <div className="flex items-center gap-2">
          <span className="font-sans text-[16px] font-medium text-ink">{restaurantName(r)}</span>
          {(restaurantDeals(r).length > 0) && <Chip text={t("Deal")} tint="sun" />}
        </div>
        <div className="text-[13px] text-inkMuted">{localizedCuisine(r.cuisine)}</div>
      </div>
    </button>
  );
}

function PlanCard({ p, onClick }: { p: Plan; onClick: () => void }) {
  const need = needsMorePeople(p);
  return (
    <button onClick={onClick} className="block w-full rounded-card bg-shell p-3.5 text-left">
      <div className="flex items-center gap-2">
        <span className="font-sans text-[15px] font-medium text-ink">{p.restaurant_name}</span>
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
