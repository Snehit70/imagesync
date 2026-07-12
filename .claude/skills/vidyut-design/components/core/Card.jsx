// Flat card as styled by theme.dart: mist fill, 20px radius, zero elevation,
// zero margin. variant="emphasis" = petal (banners, badges).
export function Card({ children, variant = "default", padding = 0, onClick, style }) {
  return (
    <div
      onClick={onClick}
      style={{
        background: variant === "emphasis" ? "var(--petal)" : "var(--mist)",
        borderRadius: "var(--radius-card, 20px)",
        padding,
        cursor: onClick ? "pointer" : undefined,
        ...style,
      }}
    >
      {children}
    </div>
  );
}
