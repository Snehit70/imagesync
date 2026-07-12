// Staggered screen entrance: rise 30px + fade, 600ms spring, 100ms apart.
// Recreation of Entrance/.entrance(i) in widgets.dart.
export function Entrance({ index = 0, children, style }) {
  return (
    <div
      style={{
        animation: "is-entrance var(--dur-entrance, 600ms) var(--ease-spring, ease-out) both",
        animationDelay: `${index * 100}ms`,
        ...style,
      }}
    >
      <style>{`
        @keyframes is-entrance {
          from { opacity: 0; transform: translateY(30px); }
          to   { opacity: 1; transform: translateY(0); }
        }
      `}</style>
      {children}
    </div>
  );
}
