// Text input as styled by theme.dart: mist fill, 16px radius, hairline border,
// raspberry 1.6px focus border, floating label, muted prefix icon.
export function TextField({ label, icon, value, onChange, type = "text", placeholder, error = false, style }) {
  const [focused, setFocused] = React.useState(false);
  const active = focused || (value != null && value !== "");
  const borderColor = error ? "var(--error)" : focused ? "var(--raspberry)" : "var(--hairline)";
  const borderWidth = focused ? "var(--input-focus-border, 1.6px)" : "1px";
  return (
    <label style={{ position: "relative", display: "block", ...style }}>
      {icon ? (
        <span
          className="material-icons-outlined"
          style={{
            position: "absolute",
            left: 14,
            top: "50%",
            transform: "translateY(-50%)",
            fontSize: 20,
            color: "var(--muted)",
          }}
        >
          {icon}
        </span>
      ) : null}
      <span
        style={{
          position: "absolute",
          left: icon ? 46 : 16,
          top: active ? 7 : "50%",
          transform: active ? "none" : "translateY(-50%)",
          fontSize: active ? 12 : 14,
          fontWeight: active ? 600 : 500,
          color: active && focused ? "var(--raspberry)" : "var(--muted)",
          transition: "all 150ms ease",
          pointerEvents: "none",
          fontFamily: "var(--font-sans)",
        }}
      >
        {label}
      </span>
      <input
        type={type}
        value={value}
        placeholder={focused ? placeholder : undefined}
        onChange={(e) => onChange && onChange(e.target.value)}
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
        style={{
          width: "100%",
          boxSizing: "border-box",
          height: 56,
          padding: `20px 16px 6px ${icon ? "46px" : "16px"}`,
          background: "var(--mist)",
          border: `${borderWidth} solid ${borderColor}`,
          borderRadius: "var(--radius-input, 16px)",
          fontFamily: "var(--font-sans)",
          fontSize: 16,
          fontWeight: 500,
          color: "var(--ink)",
          outline: "none",
        }}
      />
    </label>
  );
}
