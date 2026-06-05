import { useEffect, useRef } from "react";

/**
 * Click-and-drag horizontal scrolling for an overflow-x strip.
 *
 * Native `overflow-x: auto` can only be scrolled by touch or a trackpad
 * sideways gesture — a plain mouse has no way to drag it. This makes the strip
 * draggable with the mouse/pen (desktop) while leaving touch scrolling to the
 * browser. A drag is suppressed from turning into a click so dragging across a
 * chip doesn't accidentally select it.
 */
export function useDragScroll<T extends HTMLElement>() {
  const ref = useRef<T>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    let down = false;
    let moved = false;
    let startX = 0;
    let startScroll = 0;

    const onDown = (e: PointerEvent) => {
      if (e.pointerType === "touch") return; // native touch scrolling is fine
      if (e.pointerType === "mouse" && e.button !== 0) return;
      down = true;
      moved = false;
      startX = e.clientX;
      startScroll = el.scrollLeft;
    };
    const onMove = (e: PointerEvent) => {
      if (!down) return;
      const dx = e.clientX - startX;
      if (Math.abs(dx) > 3) moved = true;
      el.scrollLeft = startScroll - dx;
    };
    const onUp = () => {
      down = false;
    };
    // Swallow the click that follows a drag so the gesture doesn't also toggle a chip.
    const onClick = (e: MouseEvent) => {
      if (moved) {
        e.preventDefault();
        e.stopPropagation();
        moved = false;
      }
    };

    el.addEventListener("pointerdown", onDown);
    window.addEventListener("pointermove", onMove);
    window.addEventListener("pointerup", onUp);
    el.addEventListener("click", onClick, true);
    return () => {
      el.removeEventListener("pointerdown", onDown);
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onUp);
      el.removeEventListener("click", onClick, true);
    };
  }, []);

  return ref;
}
