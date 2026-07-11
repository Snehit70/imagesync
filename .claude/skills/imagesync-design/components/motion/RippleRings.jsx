// Ripple rings radiating outward from a central child (success orb).
// Recreation of RippleRings in widgets.dart: 3 stroked rings, 2200ms loop,
// radius 45%→100%, alpha 0.8→0.
export function RippleRings({ size = 160, color = "var(--petal)", children }) {
  const rings = [0, 1, 2];
  return (
    <div style={{ width: size, height: size, position: "relative", display: "grid", placeItems: "center" }}>
      <style>{`
        @keyframes is-ripple {
          from { transform: scale(0.45); opacity: 0.8; }
          to   { transform: scale(1); opacity: 0; }
        }
      `}</style>
      {rings.map((i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            inset: 0,
            borderRadius: "50%",
            border: `2px solid ${color}`,
            animation: `is-ripple var(--dur-ripple, 2200ms) linear infinite`,
            animationDelay: `${(-2200 / 3) * i}ms`,
          }}
        ></div>
      ))}
      <div style={{ position: "relative" }}>{children}</div>
    </div>
  );
}
