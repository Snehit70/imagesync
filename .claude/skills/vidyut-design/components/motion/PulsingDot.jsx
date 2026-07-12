// Small dot with a soft expanding halo; pulses while searching.
// Recreation of PulsingDot in widgets.dart (1400ms loop, halo = 2.6× size, alpha 0.3→0).
export function PulsingDot({ color = "var(--raspberry)", size = 10 }) {
  const halo = size * 2.6;
  return (
    <div style={{ width: halo, height: halo, position: "relative", display: "grid", placeItems: "center" }}>
      <style>{`
        @keyframes is-dot-halo {
          from { transform: scale(${size / halo}); opacity: 0.3; }
          to   { transform: scale(1); opacity: 0; }
        }
      `}</style>
      <div
        style={{
          position: "absolute",
          inset: 0,
          borderRadius: "50%",
          background: color,
          animation: "is-dot-halo var(--dur-dot-pulse, 1400ms) ease-out infinite",
        }}
      ></div>
      <div style={{ width: size, height: size, borderRadius: "50%", background: color, position: "relative" }}></div>
    </div>
  );
}
