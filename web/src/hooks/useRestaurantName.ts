import { useQueryClient } from "@tanstack/react-query";
import { restaurantName } from "@/types";
import type { Restaurant } from "@/types";

/**
 * Returns the locale-aware restaurant name for a given restaurantId.
 * Reads from the "restaurants" query already in the React Query cache
 * (populated by the Discover screen) — zero extra network requests.
 * Falls back to the English `fallback` string if not cached.
 */
export function useRestaurantName(restaurantId: string, fallback: string): string {
  const qc = useQueryClient();
  const restaurants = qc.getQueryData<Restaurant[]>(["restaurants"]) ?? [];
  const r = restaurants.find((x) => x.id === restaurantId);
  return r ? restaurantName(r) : fallback;
}
