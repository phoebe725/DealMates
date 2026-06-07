// Mirrors RestaurantMapView.swift: a map of all restaurants with pins; tapping
// a pin opens that restaurant. Uses Leaflet + OpenStreetMap (free, no API key).
import { useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import L from "leaflet";
import { fetchRestaurants } from "@/services/db";
import { restaurantName } from "@/types";
import { t } from "@/i18n";

const LONDON: L.LatLngTuple = [51.5074, -0.1278];

export function MapView() {
  const nav = useNavigate();
  const elRef = useRef<HTMLDivElement>(null);
  const { data: restaurants } = useQuery({ queryKey: ["restaurants"], queryFn: fetchRestaurants });

  useEffect(() => {
    const el = elRef.current;
    if (!el || !restaurants) return;

    const map = L.map(el);
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "&copy; OpenStreetMap contributors",
      maxZoom: 19,
    }).addTo(map);

    // Emoji pin avoids Leaflet's bundler-broken default marker assets.
    const icon = L.divIcon({
      className: "",
      html: '<div style="transform:translate(-50%,-100%);font-size:28px;line-height:1;filter:drop-shadow(0 1px 1px rgba(0,0,0,.35))">📍</div>',
      iconSize: [0, 0],
    });

    const pts: L.LatLngTuple[] = [];
    for (const r of restaurants) {
      if (r.latitude == null || r.longitude == null) continue;
      const m = L.marker([r.latitude, r.longitude], { icon, title: restaurantName(r) }).addTo(map);
      m.on("click", () => nav(`/restaurant/${r.id}`));
      pts.push([r.latitude, r.longitude]);
    }
    if (pts.length) map.fitBounds(pts, { padding: [48, 48] });
    else map.setView(LONDON, 12);

    // Leaflet needs a re-measure once the flex container has its final size.
    const id = window.setTimeout(() => map.invalidateSize(), 0);
    return () => {
      window.clearTimeout(id);
      map.remove();
    };
  }, [restaurants, nav]);

  return (
    <div className="flex h-full flex-col">
      <div className="flex items-center gap-2 px-4 py-3">
        <button onClick={() => nav(-1)} className="text-[22px] text-ink">‹</button>
        <span className="font-medium text-ink">{t("Map")}</span>
      </div>
      <div ref={elRef} className="min-h-0 flex-1" />
    </div>
  );
}
