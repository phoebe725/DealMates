// Mirrors DiscoverView.swift: Restaurants/Plans toggle, Featured section,
// cuisine chips (incl. AYCE/Buffet), search, plan cards with Deal + joined.
import { useMemo, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { fetchRestaurants, fetchAllActivePlans, defaultPlanOrder } from "@/services/db";
import { restaurantName, restaurantDeals, needsMorePeople, type Plan, type Restaurant } from "@/types";
import { t, localizedCuisine } from "@/i18n";
import { fetchPlanByCode } from "@/services/db";
import { Chip, EmptyState, Segmented, Spinner } from "@/components/ui";
import { useDragScroll } from "@/hooks/useDragScroll";
import { usePullToRefresh } from "@/hooks/usePullToRefresh";

const DEALS_FILTER = "🔥 Deals";
const BUFFET_CATEGORY = "AYCE / Buffet";
// Existing restaurants whose cuisine column is not "AYCE / Buffet" but
// which offer a buffet/AYCE menu. New AYCE restaurants use cuisine="AYCE / Buffet"
// directly and are matched by the cuisine check in the filter below.
const BUFFET_IDS = new Set([
  // Existing restaurants — real UUIDs from the database
  "e6f9a2b3-3a4d-4e7f-6c8b-9e1d3e5a8c1e", // Yauatcha — Soho
  "a2b56d7e-8c9f-4a3b-2e4d-5a6f8a1c4e6a", // Happy Lamb — Bayswater
  "a2b5c7d8-8c9f-4a3b-2e4d-5a6f8a1c4e6a", // Eat Tokyo — Soho
  "fe3c6f9d-3504-4b30-ac40-087e7819031e", // Haidilao — O2
  "7ffaadc0-1c28-4305-a43f-8a7b57b90249", // Haidilao — Piccadilly
  "52a665e1-fdf3-49c1-81ba-c3434d43835a", // Da Long Yi — Fitzrovia
  "8833e03a-f43a-4974-88de-9f18ac04cb6a", // Ning's — Chinatown
  "105b7fbd-e54c-4ca7-bfb6-5acb52e36ee2", // Ning's — Tottenham Street
  "fa0e7619-0c96-44ec-b61f-02ffe33d8b2b", // Ai Sushi — North Finchley
  "098dcf82-89a5-4c0e-9671-a58f2d413efb", // Mu Yang Ren — Shepherd's Bush
  "75ce5b67-52c1-4492-8dcd-367295d99fdb", // Sumiya — Shoreditch
  "7540f6f8-4f57-4f71-94ce-103950805921", // Er Mei — Chinatown
  "28b60ce5-9af5-40dd-ac1d-41d30da73368", // Mr Charcoal — Lambeth North
  // New AYCE restaurants (cuisine already set to AYCE/Buffet — listed here for explicitness)
  "955e387c-ee1f-4a77-8c8b-de80c5fb7595", // High Yaki — Chinatown
  "2272f145-26e1-43c3-8316-7f8bfed56b3a", // Sanshun BBQ Hotpot — Hammersmith
  "e0f7cf51-cd68-40ef-914d-54da5499c8b5", // DAIU — Wembley
  "2e905009-8485-4deb-8451-ae1847e6b834", // DAIU — Wimbledon
  "cdea95aa-de47-4d48-856a-3765065cd97f", // DAIU — Croydon
  "8be0d9a1-308a-4626-bff2-5401e0620139", // Hotpot Master — Canary Wharf
  "906bff7d-4b9b-4251-9347-4bee870bf0c6", // Chengdu Chengdu — Leicester Square
  "1b52d32d-eeb0-471a-94bf-2fc736f75cf1", // Real Beijing Food House — Chinatown
  "67be35be-d371-4632-926d-1481b48fee37", // New China — Chinatown
  "f0b8f931-f549-48a0-8487-c5c196d04c47", // Cheli — Elephant Park
  "1a6f9e8f-3e93-4e72-aafb-5617310bbe3b", // Happy Lamb — Holborn
  "1aa93e5c-001e-44ae-bbb0-8da6d34f4679", // NIU Hot Pot — Spitalfields
  "166f8eaa-f7fb-4d87-abf4-5a74aa6f6d01", // Master Li — Earl's Court
  "9c42c076-792f-4d8f-a119-068c7d689256", // Pao Men Shi Jia — Spitalfields
  "e210ad68-01bd-4b80-a781-048cd6c349c5", // ZhangLiang Malatang — Liverpool Street
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
  const restaurants = useQuery({ queryKey: ["restaurants"], queryFn: fetchRestaurants });
  const plans = useQuery({ queryKey: ["activePlans"], queryFn: fetchAllActivePlans });

  const restaurantMap = Object.fromEntries((restaurants.data ?? []).map((r) => [r.id, r]));

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
    await Promise.all([restaurants.refetch(), plans.refetch()]);
  });

  const cuisines = useMemo(() => {
    const list = Array.from(new Set((restaurants.data ?? []).map((r) => r.cuisine))).filter((c) => c !== BUFFET_CATEGORY).sort();
    if ((restaurants.data ?? []).some((r) => BUFFET_IDS.has(r.id) || r.cuisine === BUFFET_CATEGORY)) list.unshift(BUFFET_CATEGORY);
    if ((restaurants.data ?? []).some((r) => restaurantDeals(r).length > 0)) list.unshift(DEALS_FILTER);
    return list;
  }, [restaurants.data]);

  const filtered = useMemo(() => {
    let rows = restaurants.data ?? [];
    if (cuisine) {
      if (cuisine === DEALS_FILTER)
        rows = rows.filter((r) => restaurantDeals(r).length > 0);
      else if (cuisine === BUFFET_CATEGORY)
        rows = rows.filter((r) => BUFFET_IDS.has(r.id) || r.cuisine === BUFFET_CATEGORY);
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
  }, [restaurants.data, cuisine, search]);

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

function RestaurantCard({ r, onClick }: { r: Restaurant; onClick: () => void }) {
  const deals = restaurantDeals(r);
  return (
    <button onClick={onClick} className="block w-full overflow-hidden rounded-card bg-shell text-left">
      {r.image_url && (
        <img src={r.image_url} alt="" className="h-32 w-full object-cover" loading="lazy" />
      )}
      <div className="p-3.5">
        <div className="flex items-center gap-2">
          <span className="font-sans text-[16px] font-medium text-ink">{restaurantName(r)}</span>
          {deals.length > 0 && <Chip text={t("Deal")} tint="sun" />}
        </div>
        <div className="text-[13px] text-inkMuted">{localizedCuisine(r.cuisine)}</div>
        {deals.length > 0 && (
          <div className="mt-1.5 text-[12px] font-medium text-sunDeep">
            🔥 {deals[0].title}
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
