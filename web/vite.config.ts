import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "node:path";

// PinTable web. Talks to the same Supabase project as the iOS app.
// `base: "./"` makes the bundle work from any path — including the GitHub Pages
// subfolder (/DealMates/app/) we deploy to. The app uses hash routing so SPA
// routes resolve without server rewrites on Pages. (PWA service worker is
// deferred to the dedicated public-site deploy.)
export default defineConfig({
  base: "./",
  plugins: [react()],
  resolve: { alias: { "@": path.resolve(__dirname, "src") } },
});
