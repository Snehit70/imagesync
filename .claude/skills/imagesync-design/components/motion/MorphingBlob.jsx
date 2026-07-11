// Organic blob that slowly morphs between two silhouettes (10s reverse loop).
// Recreation of MorphingBlob in app/lib/src/design/widgets.dart.
export function MorphingBlob({ size = 150, color = "var(--raspberry)", children }) {
  const s = size;
  return (
    <div
      style={{
        width: s,
        height: s,
        background: color,
        display: "grid",
        placeItems: "center",
        animation: "is-blob-morph var(--dur-blob-morph, 10s) ease-in-out infinite alternate",
      }}
    >
      <style>{`
        @keyframes is-blob-morph {
          from { border-radius: 42% 58% 63% 37% / 55% 45% 58% 42%; }
          to   { border-radius: 55% 45% 52% 48% / 48% 52% 46% 54%; }
        }
      `}</style>
      {children}
    </div>
  );
}
