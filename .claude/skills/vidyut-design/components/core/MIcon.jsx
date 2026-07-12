// Material Icons glyph helper. Vidyut uses Flutter's built-in Icons.* set,
// loaded here from Google Fonts ("Material Icons" / "Material Icons Outlined").
export function MIcon({ name, size = 24, color = "currentColor", outlined = false, style }) {
  return (
    <span
      className={outlined ? "material-icons-outlined" : "material-icons"}
      style={{ fontSize: size, color, lineHeight: 1, userSelect: "none", ...style }}
    >
      {name}
    </span>
  );
}
