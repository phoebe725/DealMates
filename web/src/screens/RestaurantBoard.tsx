// Mirrors RestaurantBoardView.swift: venue header + deals, active plans list,
// empty state, and the create-a-table CTA.
import { useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { fetchRestaurant, fetchActivePlans, fetchRestaurantOffers, defaultPlanOrder, fetchPendingReports, submitDealReport } from "@/services/db";
import { restaurantName, offerTitle, offerDescription, offerGroupBadge, dealOffers, needsMorePeople, priceConfidenceBadge, type Plan, type Restaurant, type RestaurantOffer } from "@/types";
import { t, localizedCuisine as cuisineLabel , formatDateTime } from "@/i18n";
import { trackCreatePlanClick } from "@/lib/analytics";
import { offerShortLabel, splitTerms } from "@/lib/dealDisplay";
import { useAuth } from "@/auth/AuthContext";
import { Chip, EmptyState, RestaurantImage, Spinner } from "@/components/ui";

function timeLabel(p: Plan) {
  if (p.time_type === "asap") return t("ASAP");
  if (p.time_type === "flexible")
    return `${t(p.flex_day === "weekend" ? "Weekend" : "Weekday")} ${t(p.flex_meal === "dinner" ? "Dinner" : "Lunch")}`;
  return formatDateTime(p.scheduled_at);
}

export function RestaurantBoard() {
  const { id = "" } = useParams();
  const nav = useNavigate();
  const qc = useQueryClient();
  const { hasBlocked, user } = useAuth();
  const [showReport, setShowReport] = useState(false);
  const r = useQuery({ queryKey: ["restaurant", id], queryFn: () => fetchRestaurant(id), enabled: !!id });
  const plansQ = useQuery({ queryKey: ["plans", id], queryFn: () => fetchActivePlans(id), enabled: !!id });
  const offersQ = useQuery({ queryKey: ["offers", id], queryFn: () => fetchRestaurantOffers(id), enabled: !!id });
  const reportsQ = useQuery({ queryKey: ["pendingReports", id], queryFn: () => fetchPendingReports(id), enabled: !!id });

  if (r.isLoading) return <Spinner />;
  const rest = r.data;
  if (!rest) return <div className="p-6 text-inkMuted">Not found.</div>;

  const allOffers = offersQ.data ?? [];
  const deals = dealOffers(allOffers);                                  // group_gated + deal
  const highlights = allOffers.filter((o) => o.category === "highlight"); // info only
  const plans = (plansQ.data ?? []).filter((p) => !hasBlocked(p.creator_id)).sort(defaultPlanOrder);
  const hasPending = (reportsQ.data ?? []).length > 0;

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

        {/* Price accuracy: pending-report note + user report entry */}
        <div className="mt-3 flex items-center justify-between gap-3">
          <div className="text-[12px] text-inkMuted">
            {hasPending ? `⚠️ ${t("A user reported the price may have changed.")}` : t("Prices can change — flag it if it's wrong.")}
          </div>
          <button
            onClick={() => setShowReport(true)}
            className="shrink-0 rounded-full bg-shell px-3 py-1.5 text-[12px] font-semibold text-clay"
          >
            {t("Report price")}
          </button>
        </div>

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

        {/* 3. GOOD TO KNOW — curated highlights (price / hours / specialty) */}
        {highlights.length > 0 && (
          <>
            <div className="mt-7"><SectionHeader title={t("Good to know")} /></div>
            <div className="mt-3 space-y-2.5">
              {highlights.map((h) => (
                <div key={h.id}>
                  <div className="text-[14px] font-medium text-ink">{offerTitle(h)}</div>
                  {offerDescription(h) && (
                    <div className="mt-0.5 text-[13px] text-inkMuted">{offerDescription(h)}</div>
                  )}
                </div>
              ))}
            </div>
          </>
        )}

        {/* 4. RESTAURANT INFORMATION */}
        <div className="mt-7"><SectionHeader title={t("Restaurant info")} /></div>
        <RestaurantImage r={rest} className="mt-3 h-44 w-full rounded-card" />
        <div className="mt-2 text-[14px] text-inkMuted">
          {cuisineLabel(rest.cuisine)}
          {rest.address && (
            <>
              {" · "}
              <a
                href={mapsHref(rest)}
                target="_blank"
                rel="noopener noreferrer"
                className="text-clay underline"
              >
                {rest.address}
              </a>
            </>
          )}
        </div>
      </div>

      {/* Persistent create-a-table CTA */}
      <button
        onClick={startTable}
        className="fixed bottom-6 left-1/2 z-10 -translate-x-1/2 rounded-full bg-clay px-6 py-3 font-semibold text-cream shadow-lg"
      >
        + {t("Create a table")}
      </button>

      {showReport && (
        <ReportPriceModal
          restaurantId={rest.id}
          deals={deals}
          reporter={user}
          onClose={() => setShowReport(false)}
          onDone={() => { setShowReport(false); qc.invalidateQueries({ queryKey: ["pendingReports", id] }); }}
        />
      )}
    </div>
  );
}

// Search Maps by every known name (English + 简体 + 繁體) plus the address, so it
// locates the actual venue regardless of which name the map has indexed.
function mapsHref(r: Restaurant): string {
  const names = [r.name, r.name_zh_hans, r.name_zh_hant].filter((s): s is string => !!s);
  const unique = names.filter((s, i) => names.indexOf(s) === i);
  const query = [...unique, r.address].filter(Boolean).join(" ");
  return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(query)}`;
}

function SectionHeader({ title }: { title: string }) {
  return <div className="text-[13px] font-semibold uppercase tracking-wide text-inkMuted">{title}</div>;
}

/** Bulleted list of an offer's description terms. */
function TermList({ desc }: { desc: string }) {
  const terms = splitTerms(desc);
  if (terms.length === 0) return null;
  return (
    <ul className="mt-1.5 space-y-1">
      {terms.map((term, i) => (
        <li key={i} className="flex gap-1.5 text-[13px] text-ink">
          <span className="select-none text-clayDeep">•</span>
          <span>{term}</span>
        </li>
      ))}
    </ul>
  );
}

function ConfidenceBadge({ o }: { o: RestaurantOffer }) {
  const b = priceConfidenceBadge(o);
  return <Chip text={t(b.key)} tint={b.tint} />;
}

function DealCard({ o }: { o: RestaurantOffer }) {
  // Headline is the authored title; the short-label emoji is kept as a category cue.
  const title = offerTitle(o) || offerShortLabel(o).text;
  const { emoji } = offerShortLabel(o);
  return (
    <div className="rounded-card bg-clay/10 p-3.5">
      <div className="flex items-center gap-2">
        <span className="text-[15px] font-semibold text-clayDeep">{emoji} {title}</span>
        {o.price_pp != null && (
          <span className="ml-auto shrink-0 text-[12px] font-semibold text-clayDeep">£{o.price_pp}/pp</span>
        )}
      </div>
      <TermList desc={offerDescription(o)} />
      <div className="mt-2"><ConfidenceBadge o={o} /></div>
    </div>
  );
}

function GroupDealCard({ o, onCreate }: { o: RestaurantOffer; onCreate: () => void }) {
  const title = offerTitle(o) || offerShortLabel(o).text;
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
      <div className="mt-1 text-[15px] font-semibold text-ink">{title}</div>
      <TermList desc={offerDescription(o)} />
      <div className="mt-2"><ConfidenceBadge o={o} /></div>
      <button onClick={onCreate} className="mt-3 w-full rounded-full bg-clay py-2.5 text-[14px] font-semibold text-cream">
        {t("Create table for this deal")}
      </button>
    </div>
  );
}

function ReportPriceModal({
  restaurantId, deals, reporter, onClose, onDone,
}: {
  restaurantId: string;
  deals: RestaurantOffer[];
  reporter: { id: string; display_name: string } | null;
  onClose: () => void;
  onDone: () => void;
}) {
  const [offerId, setOfferId] = useState<string>(deals[0]?.id ?? "");
  const [price, setPrice] = useState("");
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);
  const canSubmit = price.trim() !== "" || note.trim() !== "";
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/30" onClick={onClose}>
      <div className="w-full max-w-[480px] rounded-t-3xl bg-cream p-5 pb-8" onClick={(e) => e.stopPropagation()}>
        <div className="mb-3 flex items-center">
          <button onClick={onClose} className="text-[14px] font-semibold text-ink">{t("Cancel")}</button>
          <span className="flex-1 text-center text-[15px] font-medium text-ink">{t("Report price")}</span>
          <span className="w-10" />
        </div>
        <p className="mb-3 text-[12px] text-inkMuted">{t("Spotted a different price? Let us know — we'll review it.")}</p>

        {deals.length > 0 && (
          <select
            className="pin-field mb-2 w-full"
            value={offerId}
            onChange={(e) => setOfferId(e.target.value)}
          >
            {deals.map((d) => (
              <option key={d.id} value={d.id}>{offerTitle(d) || offerShortLabel(d).text}</option>
            ))}
          </select>
        )}
        <input
          className="pin-field mb-2"
          inputMode="decimal"
          placeholder={t("Correct price per person (£)")}
          value={price}
          onChange={(e) => setPrice(e.target.value)}
        />
        <textarea
          className="pin-field mb-3 min-h-[72px]"
          placeholder={t("Anything else? (optional)")}
          value={note}
          onChange={(e) => setNote(e.target.value)}
        />
        <button
          className="pin-btn-primary disabled:opacity-40"
          disabled={!canSubmit || busy}
          onClick={async () => {
            setBusy(true);
            try {
              const parsed = Number(price.replace(/[^0-9.]/g, ""));
              await submitDealReport({
                restaurant_id: restaurantId,
                offer_id: offerId || null,
                reporter_id: reporter?.id ?? null,
                reporter_name: reporter?.display_name ?? null,
                reported_price: Number.isFinite(parsed) && price.trim() !== "" ? parsed : null,
                note: note.trim() || null,
              });
              onDone();
            } finally {
              setBusy(false);
            }
          }}
        >
          {t("Submit report")}
        </button>
      </div>
    </div>
  );
}
