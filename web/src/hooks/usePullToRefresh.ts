import { useEffect, useRef, useState } from "react";

const THRESHOLD = 72;

/**
 * Pull-to-refresh for the shared <main> scroll container.
 * The returned `ref` should be placed on the screen's root div so we can
 * walk up to the nearest scrollable ancestor to check scrollTop.
 */
export function usePullToRefresh(onRefresh: () => Promise<void>) {
  const ref = useRef<HTMLDivElement>(null);
  const [refreshing, setRefreshing] = useState(false);
  const startY = useRef(0);
  const pulling = useRef(false);
  const ratio = useRef(0);

  useEffect(() => {
    // Find the scrollable ancestor (the <main> element in App.tsx).
    const scrollEl = ref.current?.closest<HTMLElement>(".overflow-y-auto") ?? null;
    if (!scrollEl) return;

    const onTouchStart = (e: TouchEvent) => {
      if (scrollEl.scrollTop > 0) return;
      startY.current = e.touches[0].clientY;
      pulling.current = true;
    };

    const onTouchMove = (e: TouchEvent) => {
      if (!pulling.current) return;
      const dy = e.touches[0].clientY - startY.current;
      if (dy <= 0) { ratio.current = 0; return; }
      ratio.current = Math.min(dy / THRESHOLD, 1);
      if (dy > 8) e.preventDefault();
    };

    const onTouchEnd = async () => {
      if (!pulling.current) return;
      pulling.current = false;
      if (ratio.current >= 1) {
        setRefreshing(true);
        try { await onRefresh(); } finally { setRefreshing(false); }
      }
      ratio.current = 0;
    };

    scrollEl.addEventListener("touchstart", onTouchStart, { passive: true });
    scrollEl.addEventListener("touchmove", onTouchMove, { passive: false });
    scrollEl.addEventListener("touchend", onTouchEnd);
    return () => {
      scrollEl.removeEventListener("touchstart", onTouchStart);
      scrollEl.removeEventListener("touchmove", onTouchMove);
      scrollEl.removeEventListener("touchend", onTouchEnd);
    };
  }, [onRefresh]);

  return { ref, refreshing };
}
