// Mirrors RestaurantBoardView.swift: venue header + deals, active plans list,
// empty state, and the create-a-table CTA.
import { useParams, useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { fetchRestaurant, fetchActivePlans, fetchRestaurantOffers, defaultPlanOrder } from "@/services/db";
import { restaurantName, restaurantDeals, dealToOffer, offerTitle, offerDescription, offerGroupBadge, needsMorePeople, type Plan } from "@/types";
import { t, localizedCuisine as cuisineLabel } from "@/i18n";
import { Chip, EmptyState, Spinner } from "@/components/ui";

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
  const offers = (offersQ.data && offersQ.data.length)
    ? offersQ.data
    : restaurantDeals(rest).map((d, i) => dealToOffer(d, rest.id, i));
  const plans = (plansQ.data ?? []).slice().sort(defaultPlanOrder);

  return (
    <div className="relative min-h-screen pb-24">
      <div className="flex items-center gap-2 px-4 py-3">
        <button onClick={() => nav(-1)} className="text-[22px] text-ink">‹</button>
      </div>

      {rest.image_url && <img src={rest.image_url} alt="" className="h-44 w-full object-cover" />}

      <div className="px-5 pt-4">
        <h1 className="font-sans text-[24px] font-medium text-ink">{restaurantName(rest)}</h1>
        <div className="text-[14px] text-inkMuted">{cuisineLabel(rest.cuisine)}{rest.address ? ` · ${rest.address}` : ""}</div>

        {offers.length > 0 && (
          <div className="mt-4 space-y-2">
            {offers.map((o) => {
              const badge = offerGroupBadge(o);
              const desc = offerDescription(o);
              return (
                <div key={o.id} className="rounded-card bg-clay/10 p-3">
                  <div className="flex items-center gap-2">
                    <span className="text-[14px] font-semibold text-clayDeep">{offerTitle(o)}</span>
                    {badge && (
                      <span className="rounded-full bg-clay/20 px-2 py-0.5 text-[11px] font-semibold text-clayDeep">
                        {badge}
                      </span>
                    )}
                    {o.price_pp != null && (
                      <span className="ml-auto text-[12px] font-semibold text-clayDeep">
                        £{o.price_pp}/pp
                      </span>
                    )}
                  </div>
                  {desc && <div className="mt-0.5 text-[13px] text-ink">{desc}</div>}
                </div>
              );
            })}
          </div>
        )}

        <div className="mt-6 text-[13px] font-semibold uppercase tracking-wide text-inkMuted">{t("Active plans")}</div>
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
      </div>

      {/* Create-a-table CTA (create flow is the next phase). */}
      <button
        onClick={() => nav(`/create?restaurant=${rest.id}`)}
        className="fixed bottom-6 left-1/2 z-10 -translate-x-1/2 rounded-full bg-clay px-6 py-3 font-semibold text-cream shadow-lg"
      >
        + {t("Create a table")}
      </button>
    </div>
  );
}
