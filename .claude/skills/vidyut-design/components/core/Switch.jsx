// Switch as themed: selected = raspberry track / white thumb;
// unselected = mist track, hairline outline, muted thumb.
export function Switch({ checked = false, onChange, style }) {
  return (
    <button
      role="switch"
      aria-checked={checked}
      onClick={() => onChange && onChange(!checked)}
      style={{
        width: 52,
        height: 32,
        borderRadius: 999,
        border: checked ? "2px solid transparent" : "2px solid var(--hairline)",
        background: checked ? "var(--raspberry)" : "var(--mist)",
        position: "relative",
        cursor: "pointer",
        transition: "background 200ms ease, border-color 200ms ease",
        padding: 0,
        boxSizing: "border-box",
        flexShrink: 0,
        ...style,
      }}
    >
      <span
        style={{
          position: "absolute",
          top: "50%",
          left: checked ? 24 : 6,
          transform: "translateY(-50%)",
          width: checked ? 20 : 14,
          height: checked ? 20 : 14,
          borderRadius: "50%",
          background: checked ? "#fff" : "var(--muted)",
          transition: "all 200ms var(--ease-out-cubic, ease-out)",
        }}
      ></span>
    </button>
  );
}
