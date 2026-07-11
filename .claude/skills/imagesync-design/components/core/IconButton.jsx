// App-bar icon chip: mist square with 14px radius, ink (or raspberry) icon.
// From _AppBarAction in main.dart + IconButton.styleFrom uses in screens.
export function IconButton({ icon, color = "var(--ink)", size = 20, radius = 14, title, onClick, style }) {
  return (
    <button
      title={title}
      onClick={onClick}
      style={{
        width: 40,
        height: 40,
        display: "grid",
        placeItems: "center",
        background: "var(--mist)",
        border: "none",
        borderRadius: radius,
        cursor: "pointer",
        color,
        ...style,
      }}
    >
      <span className="material-icons-outlined" style={{ fontSize: size, lineHeight: 1 }}>
        {icon}
      </span>
    </button>
  );
}
