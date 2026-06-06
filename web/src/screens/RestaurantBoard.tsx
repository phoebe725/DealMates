// Mirrors RestaurantBoardView.swift: venue header + deals, active plans list,
// empty state, and the create-a-table CTA.
import { useParams, useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { fetchRestaurant, fetchActivePlans, fetchRestaurantOffers, defaultPlanOrder } from "@/services/db";
import { restaurantName, restaurantDeals, dealToOffer, offerTitle, offerDescription, offerGroupBadge, dealOffers, needsMorePeople, type Plan, type RestaurantOffer } from "@/types";
import { t, localizedCuisine as cuisineLabel } from "@/i18n";
import { trackCreatePlanClick } from "@/lib/analytics";
import { offerShortLabel } from "@/lib/dealDisplay";
import { Chip, EmptyState, RestaurantImage, Spinner } from "@/components/ui";

function timeLabel(p: Plan) {
  if (p.time_type === "asap") return t("ASAP");
  if (p.time_type === "flexible")
    return `${t(p.flex_day === "weekend" ? "Weekend" : "Weekday")} ${t(p.flex_meal === "dinner" ? "Dinner" : "Lunch")}`;
  return new Date(p.scheduled_at).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" });
}

export function RestaurantBoard() {
  const { id = "" } = useParams();
  const nav = useNavigate();
  const r = useQuery({ queryKey: ["restaurant", id], queryFn: () => fetchRestaurant(id), enabled: !!id });
  const plansQ = useQuery({ queryKey: ["plans", id], queryFn: () => fetchActivePlans(id), enabled: !!id });
  const offersQ = useQuery({ queryKey: ["offers", id], queryFn: () => fetchRestaurantOffers(id), enabled: !!id });

  if (r.isLoading) return <Spinner />;
  const rest = r.data;
  if (!rest) return <div className="p-6 text-inkMuted">Not found.</div>;

  // Offers-first; fall back to the legacy deals JSON if there are no offer rows.
  const allOffers = (offersQ.data && offersQ.data.length)
    ? offersQ.data
    : restaurantDeals(rest).map((d, i) => dealToOffer(d, rest.id, i));
  const deals = dealOffers(allOffers);                                  // group_gated + deal
  const highlights = allOffers.filter((o) => o.category === "highlight"); // info only
  const plans = (plansQ.data ?? []).slice().sort(defaultPlanOrder);

  const startTable = () => { trackCreatePlanClick(rest.id); nav(`/create?restaurant=${rest.id}`); };

  return (
    <div className="relative min-h-screen pb-24">
      <div className="flex items-center gap-2 px-4 py-3">
        <button onClick={() => nav(-1)} className="text-[22px] text-ink">‹</button>
        <span className="truncate font-medium text-ink">{restaurantName(rest)}</span>
      </div>

      <div className="px-5 pt-1">
        {/* 1. CURRENT DEALS — top of the page */}
        {deals.length > 0 && (
          <>
            <SectionHeader title={t("Current deals")} />
            <div className="mt-3 space-y-2">
              {deals.map((o) =>
                o.category === "group_gated"
                  ? <GroupDealCard key={o.id} o={o} onCreate={startTable} />
                  : <DealCard key={o.id} o={o} />,
              )}
            </div>
          </>
        )}

        {/* 2. ACTIVE TABLES / PLANS */}
        <div className="mt-7"><SectionHeader title={t("Active plans")} /></div>
        {plansQ.isLoading ? (
          <Spinner />
        ) : plans.length === 0 ? (
          <EmptyState title={t("No active plans here yet")} message={t("Be the first to pin a plan.")} emoji="📍" />
        ) : (
          <div className="mt-3 space-y-3">
            {plans.map((p) => {
              const need = needsMorePeople(p);
              return (
                <button key={p.id} onClick={() => nav(`/plan/${p.id}`)} className="block w-full rounded-card bg-shell p-3.5 text-left">
                  <div className="flex items-center">
                    <span className="text-[15px] font-medium text-ink">🕐 {timeLabel(p)}</span>
                    <span className="ml-auto">
                      {need > 0 ? (
                        <Chip text={t("%lld/%lld joined", p.current_people, p.needed_people)} />
                      ) : (
                        <Chip text={t("Full")} tint="sage" />
                      )}
                    </span>
                  </div>
                  <div className="mt-1 text-[13px] text-inkMuted">{p.creator_name}{p.notes ? ` · ${p.notes}` : ""}</div>
                </button>
              );
            })}
          </div>
        )}

        {/* 3. RESTAURANT INFORMATION */}
        <div className="mt-7"><SectionHeader title={t("Restaurant info")} /></div>
        <RestaurantImage r={rest} className="mt-3 h-44 w-full rounded-card" />
        <div className="mt-2 text-[14px] text-inkMuted">
          {cuisineLabel(rest.cuisine)}{rest.address ? ` · ${rest.address}` : ""}
        </div>
        {highlights.length > 0 && (
          <ul className="mt-2 space-y-1">
            {highlights.map((h) => (
              <li key={h.id} className="text-[13px] text-ink">
                · {offerTitle(h)}{offerDescription(h) ? ` — ${offerDescription(h)}` : ""}
              </li>
            ))}
          </ul>
        )}
      </div>

      {/* Persistent create-a-table CTA */}
      <button
        onClick={startTable}
        className="fixed bottom-6 left-1/2 z-10 -translate-x-1/2 rounded-full bg-clay px-6 py-3 font-semibold text-cream shadow-lg"
      >
        + {t("Create a table")}
      </button>
    </div>
  );
}

function SectionHeader({ title }: { title: string }) {
  return <div className="text-[13px] font-semibold uppercase tracking-wide text-inkMuted">{title}</div>;
}

function DealCard({ o }: { o: RestaurantOffer }) {
  const desc = offerDescription(o);
  const label = offerShortLabel(o);
  return (
    <div className="rounded-card bg-clay/10 p-3">
      <div className="flex items-center gap-2">
        <span className="text-[14px] font-semibold text-clayDeep">{label.emoji} {label.text}</span>
        {o.price_pp != null && (
          <span className="ml-auto text-[12px] font-semibold text-clayDeep">£{o.price_pp}/pp</span>
        )}
      </div>
      {desc && <div className="mt-0.5 text-[13px] text-ink">{desc}</div>}
    </div>
  );
}

function GroupDealCard({ o, onCreate }: { o: RestaurantOffer; onCreate: () => void }) {
  const desc = offerDescription(o);
  const badge = offerGroupBadge(o);
  return (
    <div className="rounded-card border-2 border-clay/40 bg-clay/15 p-3.5">
      <div className="flex items-center gap-2">
        <span className="text-[12px] font-bold uppercase tracking-wide text-clayDeep">🔥 {t("Group deal")}</span>
        {badge && (
          <span className="rounded-full bg-clay/25 px-2 py-0.5 text-[11px] font-semibold text-clayDeep">{badge}</span>
        )}
        {o.price_pp != null && (
          <span className="ml-auto text-[12px] font-semibold text-clayDeep">£{o.price_pp}/pp</span>
        )}
      </div>
      {o.min_people != null && (
        <div className="mt-1 text-[12px] text-clayDeep">{t("Requires %lld people", o.min_people)}</div>
      )}
      <div className="mt-1 text-[15px] font-semibold text-ink">{offerShortLabel(o).text}</div>
      {desc && <div className="mt-0.5 text-[13px] text-ink">{desc}</div>}
      <button onClick={onCreate} className="mt-3 w-full rounded-full bg-clay py-2.5 text-[14px] font-semibold text-cream">
        {t("Create table for this deal")}
      </button>
    </div>
  );
}
