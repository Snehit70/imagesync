// Snackbar as themed: ink pill, white 14px/500 text, floating.
export function Snackbar({ children, style }) {
  return (
    <div
      style={{
        background: "var(--ink)",
        color: "var(--text-on-inverse, #fff)",
        borderRadius: "var(--radius-pill, 999px)",
        padding: "14px 24px",
        fontFamily: "var(--font-sans)",
        fontSize: 14,
        fontWeight: 500,
        lineHeight: 1.3,
        display: "inline-block",
        ...style,
      }}
    >
      {children}
    </div>
  );
}
