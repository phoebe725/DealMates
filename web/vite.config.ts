import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "node:path";

// PinTable web. Talks to the same Supabase project as the iOS app.
// Deployed to Firebase Hosting at the domain root (e.g. pintable-london.web.app),
// so base is "/" and the app uses normal routing (Firebase rewrites all paths
// to index.html — see firebase.json). PWA service worker deferred for now.
export default defineConfig({
  base: "/",
  plugins: [react()],
  resolve: { alias: { "@": path.resolve(__dirname, "src") } },
});
