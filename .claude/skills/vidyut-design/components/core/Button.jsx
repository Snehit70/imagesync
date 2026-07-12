// Pill buttons as styled by theme.dart: filled (raspberry/white), outlined
// (1.5px petal border, raspberry text), text (raspberry; muted for Skip).
// Full-width, 54px tall, 15px/600 label.
export function Button({
  variant = "filled",
  children,
  icon,
  muted = false,
  fullWidth = true,
  onClick,
  disabled = false,
  style,
}) {
  const base = {
    fontFamily: "var(--font-sans)",
    fontSize: variant === "text" ? "14px" : "var(--type-button-size, 15px)",
    fontWeight: 600,
    lineHeight: 1.3,
    borderRadius: "var(--radius-pill, 999px)",
    height: variant === "text" ? "auto" : "var(--button-height, 54px)",
    padding: variant === "text" ? "10px 16px" : "0 24px",
    width: fullWidth && variant !== "text" ? "100%" : undefined,
    display: "inline-flex",
    alignItems: "center",
    justifyContent: "center",
    gap: "8px",
    cursor: disabled ? "default" : "pointer",
    opacity: disabled ? 0.5 : 1,
    border: "none",
    background: "transparent",
    transition: "background 150ms ease",
  };
  const variants = {
    filled: { background: "var(--raspberry)", color: "var(--text-on-primary, #fff)" },
    outlined: {
      background: "var(--ground)",
      color: "var(--raspberry)",
      border: "var(--button-border, 1.5px) solid var(--petal)",
    },
    text: { color: muted ? "var(--muted)" : "var(--raspberry)" },
  };
  return (
    <button style={{ ...base, ...variants[variant], ...style }} onClick={onClick} disabled={disabled}>
      {icon ? (
        <span className="material-icons" style={{ fontSize: 18, lineHeight: 1 }}>
          {icon}
        </span>
      ) : null}
      {children}
    </button>
  );
}
