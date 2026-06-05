/** PinTable design tokens — mirrored from DealMates/DesignSystem/Theme.swift */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        cream: "#FAF6F0",
        shell: "#F2EBE0",
        fog: "#E8DFD1",
        sage: "#9CAF94",
        sageDeep: "#6B7F62",
        clay: "#C97B5C",
        clayDeep: "#A85E42",
        lavender: "#C5BBD4",
        lavenderDeep: "#6E5E8E",
        peach: "#E8C4A8",
        sky: "#B8CFD8",
        sun: "#E0B65A",
        sunDeep: "#B88E33",
        ink: "#2B2620",
        inkMuted: "#6B6359",
      },
      fontFamily: {
        // Roles mirror Theme.swift: hero/body/button = Inter, accent/logo =
        // Cormorant Garamond, subtitle = Nunito Sans.
        sans: ['Inter', 'system-ui', 'sans-serif'],
        accent: ['"Cormorant Garamond"', 'Georgia', 'serif'],
        subtitle: ['"Nunito Sans"', 'Inter', 'sans-serif'],
      },
      borderRadius: { pin: "14px", card: "20px" },
      maxWidth: { phone: "480px" },
    },
  },
  plugins: [],
};
