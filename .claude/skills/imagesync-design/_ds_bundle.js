/* @ds-bundle: {"format":4,"namespace":"ImageSyncDesignSystem_5c35fc","components":[{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"Card","sourcePath":"components/core/Card.jsx"},{"name":"IconButton","sourcePath":"components/core/IconButton.jsx"},{"name":"MIcon","sourcePath":"components/core/MIcon.jsx"},{"name":"Snackbar","sourcePath":"components/core/Snackbar.jsx"},{"name":"Switch","sourcePath":"components/core/Switch.jsx"},{"name":"TextField","sourcePath":"components/core/TextField.jsx"},{"name":"Entrance","sourcePath":"components/motion/Entrance.jsx"},{"name":"MorphingBlob","sourcePath":"components/motion/MorphingBlob.jsx"},{"name":"PressableScale","sourcePath":"components/motion/PressableScale.jsx"},{"name":"PulsingDot","sourcePath":"components/motion/PulsingDot.jsx"},{"name":"RippleRings","sourcePath":"components/motion/RippleRings.jsx"},{"name":"ManualPairingForm","sourcePath":"components/pairing/ManualPairingForm.jsx"},{"name":"NearbyRelaysCard","sourcePath":"components/pairing/NearbyRelaysCard.jsx"}],"sourceHashes":{"components/core/Button.jsx":"f5683f66da16","components/core/Card.jsx":"8ce74810749d","components/core/IconButton.jsx":"4ca46b090f2f","components/core/MIcon.jsx":"9ed8e365327c","components/core/Snackbar.jsx":"a0e6727a9266","components/core/Switch.jsx":"4907b4b1ddc6","components/core/TextField.jsx":"75f3f23b9124","components/motion/Entrance.jsx":"46ef85ab788f","components/motion/MorphingBlob.jsx":"e16a36f92be7","components/motion/PressableScale.jsx":"2bbd110eec7d","components/motion/PulsingDot.jsx":"b16b96b8f36b","components/motion/RippleRings.jsx":"2ac7ecec0249","components/pairing/ManualPairingForm.jsx":"16892cacbe34","components/pairing/NearbyRelaysCard.jsx":"cf3e4e280e17","ui_kits/android/AppChrome.jsx":"c3d28b23cffc","ui_kits/android/AppScreens.jsx":"f0bab71a5752","ui_kits/android/OnboardingScreens.jsx":"ca87b7cf941d"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.ImageSyncDesignSystem_5c35fc = window.ImageSyncDesignSystem_5c35fc || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/core/Button.jsx
try { (() => {
// Pill buttons as styled by theme.dart: filled (raspberry/white), outlined
// (1.5px petal border, raspberry text), text (raspberry; muted for Skip).
// Full-width, 54px tall, 15px/600 label.
function Button({
  variant = "filled",
  children,
  icon,
  muted = false,
  fullWidth = true,
  onClick,
  disabled = false,
  style
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
    transition: "background 150ms ease"
  };
  const variants = {
    filled: {
      background: "var(--raspberry)",
      color: "var(--text-on-primary, #fff)"
    },
    outlined: {
      background: "var(--ground)",
      color: "var(--raspberry)",
      border: "var(--button-border, 1.5px) solid var(--petal)"
    },
    text: {
      color: muted ? "var(--muted)" : "var(--raspberry)"
    }
  };
  return /*#__PURE__*/React.createElement("button", {
    style: {
      ...base,
      ...variants[variant],
      ...style
    },
    onClick: onClick,
    disabled: disabled
  }, icon ? /*#__PURE__*/React.createElement("span", {
    className: "material-icons",
    style: {
      fontSize: 18,
      lineHeight: 1
    }
  }, icon) : null, children);
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/Card.jsx
try { (() => {
// Flat card as styled by theme.dart: mist fill, 20px radius, zero elevation,
// zero margin. variant="emphasis" = petal (banners, badges).
function Card({
  children,
  variant = "default",
  padding = 0,
  onClick,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClick,
    style: {
      background: variant === "emphasis" ? "var(--petal)" : "var(--mist)",
      borderRadius: "var(--radius-card, 20px)",
      padding,
      cursor: onClick ? "pointer" : undefined,
      ...style
    }
  }, children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Card.jsx", error: String((e && e.message) || e) }); }

// components/core/IconButton.jsx
try { (() => {
// App-bar icon chip: mist square with 14px radius, ink (or raspberry) icon.
// From _AppBarAction in main.dart + IconButton.styleFrom uses in screens.
function IconButton({
  icon,
  color = "var(--ink)",
  size = 20,
  radius = 14,
  title,
  onClick,
  style
}) {
  return /*#__PURE__*/React.createElement("button", {
    title: title,
    onClick: onClick,
    style: {
      width: 40,
      height: 40,
      display: "grid",
      placeItems: "center",
      background: "var(--mist)",
      border: "none",
      borderRadius: radius,
      cursor: "pointer",
      color,
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-icons-outlined",
    style: {
      fontSize: size,
      lineHeight: 1
    }
  }, icon));
}
Object.assign(__ds_scope, { IconButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/IconButton.jsx", error: String((e && e.message) || e) }); }

// components/core/MIcon.jsx
try { (() => {
// Material Icons glyph helper. ImageSync uses Flutter's built-in Icons.* set,
// loaded here from Google Fonts ("Material Icons" / "Material Icons Outlined").
function MIcon({
  name,
  size = 24,
  color = "currentColor",
  outlined = false,
  style
}) {
  return /*#__PURE__*/React.createElement("span", {
    className: outlined ? "material-icons-outlined" : "material-icons",
    style: {
      fontSize: size,
      color,
      lineHeight: 1,
      userSelect: "none",
      ...style
    }
  }, name);
}
Object.assign(__ds_scope, { MIcon });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/MIcon.jsx", error: String((e && e.message) || e) }); }

// components/core/Snackbar.jsx
try { (() => {
// Snackbar as themed: ink pill, white 14px/500 text, floating.
function Snackbar({
  children,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--ink)",
      color: "var(--text-on-inverse, #fff)",
      borderRadius: "var(--radius-pill, 999px)",
      padding: "14px 24px",
      fontFamily: "var(--font-sans)",
      fontSize: 14,
      fontWeight: 500,
      lineHeight: 1.3,
      display: "inline-block",
      ...style
    }
  }, children);
}
Object.assign(__ds_scope, { Snackbar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Snackbar.jsx", error: String((e && e.message) || e) }); }

// components/core/Switch.jsx
try { (() => {
// Switch as themed: selected = raspberry track / white thumb;
// unselected = mist track, hairline outline, muted thumb.
function Switch({
  checked = false,
  onChange,
  style
}) {
  return /*#__PURE__*/React.createElement("button", {
    role: "switch",
    "aria-checked": checked,
    onClick: () => onChange && onChange(!checked),
    style: {
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
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: "absolute",
      top: "50%",
      left: checked ? 24 : 6,
      transform: "translateY(-50%)",
      width: checked ? 20 : 14,
      height: checked ? 20 : 14,
      borderRadius: "50%",
      background: checked ? "#fff" : "var(--muted)",
      transition: "all 200ms var(--ease-out-cubic, ease-out)"
    }
  }));
}
Object.assign(__ds_scope, { Switch });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Switch.jsx", error: String((e && e.message) || e) }); }

// components/core/TextField.jsx
try { (() => {
// Text input as styled by theme.dart: mist fill, 16px radius, hairline border,
// raspberry 1.6px focus border, floating label, muted prefix icon.
function TextField({
  label,
  icon,
  value,
  onChange,
  type = "text",
  placeholder,
  error = false,
  style
}) {
  const [focused, setFocused] = React.useState(false);
  const active = focused || value != null && value !== "";
  const borderColor = error ? "var(--error)" : focused ? "var(--raspberry)" : "var(--hairline)";
  const borderWidth = focused ? "var(--input-focus-border, 1.6px)" : "1px";
  return /*#__PURE__*/React.createElement("label", {
    style: {
      position: "relative",
      display: "block",
      ...style
    }
  }, icon ? /*#__PURE__*/React.createElement("span", {
    className: "material-icons-outlined",
    style: {
      position: "absolute",
      left: 14,
      top: "50%",
      transform: "translateY(-50%)",
      fontSize: 20,
      color: "var(--muted)"
    }
  }, icon) : null, /*#__PURE__*/React.createElement("span", {
    style: {
      position: "absolute",
      left: icon ? 46 : 16,
      top: active ? 7 : "50%",
      transform: active ? "none" : "translateY(-50%)",
      fontSize: active ? 12 : 14,
      fontWeight: active ? 600 : 500,
      color: active && focused ? "var(--raspberry)" : "var(--muted)",
      transition: "all 150ms ease",
      pointerEvents: "none",
      fontFamily: "var(--font-sans)"
    }
  }, label), /*#__PURE__*/React.createElement("input", {
    type: type,
    value: value,
    placeholder: focused ? placeholder : undefined,
    onChange: e => onChange && onChange(e.target.value),
    onFocus: () => setFocused(true),
    onBlur: () => setFocused(false),
    style: {
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
      outline: "none"
    }
  }));
}
Object.assign(__ds_scope, { TextField });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/TextField.jsx", error: String((e && e.message) || e) }); }

// components/motion/Entrance.jsx
try { (() => {
// Staggered screen entrance: rise 30px + fade, 600ms spring, 100ms apart.
// Recreation of Entrance/.entrance(i) in widgets.dart.
function Entrance({
  index = 0,
  children,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      animation: "is-entrance var(--dur-entrance, 600ms) var(--ease-spring, ease-out) both",
      animationDelay: `${index * 100}ms`,
      ...style
    }
  }, /*#__PURE__*/React.createElement("style", null, `
        @keyframes is-entrance {
          from { opacity: 0; transform: translateY(30px); }
          to   { opacity: 1; transform: translateY(0); }
        }
      `), children);
}
Object.assign(__ds_scope, { Entrance });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/motion/Entrance.jsx", error: String((e && e.message) || e) }); }

// components/motion/MorphingBlob.jsx
try { (() => {
// Organic blob that slowly morphs between two silhouettes (10s reverse loop).
// Recreation of MorphingBlob in app/lib/src/design/widgets.dart.
function MorphingBlob({
  size = 150,
  color = "var(--raspberry)",
  children
}) {
  const s = size;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: s,
      height: s,
      background: color,
      display: "grid",
      placeItems: "center",
      animation: "is-blob-morph var(--dur-blob-morph, 10s) ease-in-out infinite alternate"
    }
  }, /*#__PURE__*/React.createElement("style", null, `
        @keyframes is-blob-morph {
          from { border-radius: 42% 58% 63% 37% / 55% 45% 58% 42%; }
          to   { border-radius: 55% 45% 52% 48% / 48% 52% 46% 54%; }
        }
      `), children);
}
Object.assign(__ds_scope, { MorphingBlob });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/motion/MorphingBlob.jsx", error: String((e && e.message) || e) }); }

// components/motion/PressableScale.jsx
try { (() => {
// Squash-on-press wrapper: scale 0.93 down (120ms easeOutCubic),
// spring overshoot back up (300ms). Recreation of PressableScale.
function PressableScale({
  children,
  style
}) {
  const [pressed, setPressed] = React.useState(false);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      transform: pressed ? "scale(0.93)" : "scale(1)",
      transition: pressed ? "transform var(--dur-press-down, 120ms) var(--ease-out-cubic, ease-out)" : "transform var(--dur-press-up, 300ms) var(--ease-spring, ease-out)",
      ...style
    },
    onPointerDown: () => setPressed(true),
    onPointerUp: () => setPressed(false),
    onPointerLeave: () => setPressed(false)
  }, children);
}
Object.assign(__ds_scope, { PressableScale });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/motion/PressableScale.jsx", error: String((e && e.message) || e) }); }

// components/motion/PulsingDot.jsx
try { (() => {
// Small dot with a soft expanding halo; pulses while searching.
// Recreation of PulsingDot in widgets.dart (1400ms loop, halo = 2.6× size, alpha 0.3→0).
function PulsingDot({
  color = "var(--raspberry)",
  size = 10
}) {
  const halo = size * 2.6;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: halo,
      height: halo,
      position: "relative",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("style", null, `
        @keyframes is-dot-halo {
          from { transform: scale(${size / halo}); opacity: 0.3; }
          to   { transform: scale(1); opacity: 0; }
        }
      `), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      borderRadius: "50%",
      background: color,
      animation: "is-dot-halo var(--dur-dot-pulse, 1400ms) ease-out infinite"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      width: size,
      height: size,
      borderRadius: "50%",
      background: color,
      position: "relative"
    }
  }));
}
Object.assign(__ds_scope, { PulsingDot });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/motion/PulsingDot.jsx", error: String((e && e.message) || e) }); }

// components/motion/RippleRings.jsx
try { (() => {
// Ripple rings radiating outward from a central child (success orb).
// Recreation of RippleRings in widgets.dart: 3 stroked rings, 2200ms loop,
// radius 45%→100%, alpha 0.8→0.
function RippleRings({
  size = 160,
  color = "var(--petal)",
  children
}) {
  const rings = [0, 1, 2];
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: size,
      height: size,
      position: "relative",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("style", null, `
        @keyframes is-ripple {
          from { transform: scale(0.45); opacity: 0.8; }
          to   { transform: scale(1); opacity: 0; }
        }
      `), rings.map(i => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      position: "absolute",
      inset: 0,
      borderRadius: "50%",
      border: `2px solid ${color}`,
      animation: `is-ripple var(--dur-ripple, 2200ms) linear infinite`,
      animationDelay: `${-2200 / 3 * i}ms`
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative"
    }
  }, children));
}
Object.assign(__ds_scope, { RippleRings });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/motion/RippleRings.jsx", error: String((e && e.message) || e) }); }

// components/pairing/ManualPairingForm.jsx
try { (() => {
// Manual host/port/secret entry form. Recreation of ManualPairingForm.

function ManualPairingForm({
  host = "",
  port = "17321",
  secret = "",
  onHostChange,
  onPortChange,
  onSecretChange,
  error,
  onScanQr,
  onPair
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 12,
      fontFamily: "var(--font-sans)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 16,
      fontWeight: 600,
      color: "var(--ink)"
    }
  }, "Manual pairing"), /*#__PURE__*/React.createElement(__ds_scope.TextField, {
    label: "Relay IP",
    icon: "router",
    value: host,
    onChange: onHostChange
  }), /*#__PURE__*/React.createElement(__ds_scope.TextField, {
    label: "Port",
    icon: "settings_ethernet",
    value: port,
    onChange: onPortChange
  }), /*#__PURE__*/React.createElement(__ds_scope.TextField, {
    label: "Pairing secret",
    icon: "key",
    type: "password",
    value: secret,
    onChange: onSecretChange
  }), error ? /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--mist)",
      borderRadius: 16,
      padding: 12,
      display: "flex",
      alignItems: "center",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-icons-outlined",
    style: {
      fontSize: 18,
      color: "var(--error)"
    }
  }, "error_outline"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      fontWeight: 500,
      color: "var(--error)",
      lineHeight: 1.3
    }
  }, error)) : null, /*#__PURE__*/React.createElement("div", {
    style: {
      height: 8
    }
  }), /*#__PURE__*/React.createElement(__ds_scope.PressableScale, null, /*#__PURE__*/React.createElement(__ds_scope.Button, {
    icon: "link",
    onClick: onPair
  }, "Pair manually")), /*#__PURE__*/React.createElement(__ds_scope.PressableScale, null, /*#__PURE__*/React.createElement(__ds_scope.Button, {
    variant: "outlined",
    icon: "qr_code_scanner",
    onClick: onScanQr
  }, "Scan QR")));
}
Object.assign(__ds_scope, { ManualPairingForm });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/pairing/ManualPairingForm.jsx", error: String((e && e.message) || e) }); }

// components/pairing/NearbyRelaysCard.jsx
try { (() => {
// Discovery results card — shared by home pairing and the wizard finale.
// Recreation of NearbyRelaysCard in pairing_widgets.dart.

function NearbyRelaysCard({
  relays = [],
  selected,
  discovering = false,
  onRefresh,
  onSelect
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 10
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 4
    }
  }, discovering ? /*#__PURE__*/React.createElement(__ds_scope.PulsingDot, {
    size: 8
  }) : null, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      fontSize: 16,
      fontWeight: 600,
      fontFamily: "var(--font-sans)",
      color: "var(--ink)"
    }
  }, "Nearby relays"), !discovering ? /*#__PURE__*/React.createElement("button", {
    title: "Search again",
    onClick: onRefresh,
    style: {
      width: 40,
      height: 40,
      display: "grid",
      placeItems: "center",
      background: "var(--mist)",
      color: "var(--raspberry)",
      border: "none",
      borderRadius: 12,
      cursor: "pointer"
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-icons",
    style: {
      fontSize: 20
    }
  }, "refresh")) : null), relays.length === 0 ? /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      fontWeight: 500,
      color: "var(--muted)",
      fontFamily: "var(--font-sans)",
      lineHeight: 1.3
    }
  }, discovering ? "Searching for relays on this network…" : "No relays found. Make sure the laptop relay is running, or pair manually below.") : relays.map(relay => /*#__PURE__*/React.createElement("div", {
    key: `${relay.host}:${relay.port}`,
    onClick: () => onSelect && onSelect(relay),
    style: {
      background: "var(--mist)",
      borderRadius: 20,
      padding: "10px 16px",
      display: "flex",
      alignItems: "center",
      gap: 14,
      cursor: "pointer"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 40,
      height: 40,
      background: "var(--petal)",
      borderRadius: 13,
      display: "grid",
      placeItems: "center",
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-icons",
    style: {
      fontSize: 20,
      color: "var(--raspberry)"
    }
  }, "dns")), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      fontFamily: "var(--font-sans)",
      lineHeight: 1.3
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      fontWeight: 600,
      color: "var(--ink)"
    }
  }, relay.name), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      fontWeight: 500,
      color: "var(--muted)"
    }
  }, relay.host, ":", relay.port)), selected && selected.host === relay.host && selected.port === relay.port ? /*#__PURE__*/React.createElement("span", {
    className: "material-icons",
    style: {
      fontSize: 24,
      color: "var(--raspberry)"
    }
  }, "check_circle") : null)), selected ? /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      fontWeight: 500,
      color: "var(--muted)",
      fontFamily: "var(--font-sans)"
    }
  }, "Enter the pairing secret below and tap Pair manually.") : null);
}
Object.assign(__ds_scope, { NearbyRelaysCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/pairing/NearbyRelaysCard.jsx", error: String((e && e.message) || e) }); }

// ui_kits/android/AppChrome.jsx
try { (() => {
// Shared chrome for the ImageSync Android UI kit — screen internals from
// main.dart (private widgets: _AppBarAction, _StatusHero, _SetupBanner,
// _ShareStatusCard, _StepDots, _ChecklistRow, _SummaryChip).
const DS = window.ImageSyncDesignSystem_5c35fc;
const {
  MorphingBlob,
  PulsingDot,
  PressableScale,
  IconButton
} = DS;
function PhoneFrame({
  children
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: 390,
      height: 844,
      background: "var(--ground)",
      borderRadius: 28,
      border: "1px solid var(--hairline)",
      overflow: "hidden",
      display: "flex",
      flexDirection: "column",
      fontFamily: "var(--font-sans)",
      color: "var(--ink)",
      position: "relative",
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      height: 34,
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      padding: "0 22px",
      fontSize: 13,
      fontWeight: 600,
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("span", null, "9:41"), /*#__PURE__*/React.createElement("span", {
    style: {
      display: "flex",
      gap: 4,
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-icons",
    style: {
      fontSize: 15
    }
  }, "signal_cellular_alt"), /*#__PURE__*/React.createElement("span", {
    className: "material-icons",
    style: {
      fontSize: 15
    }
  }, "wifi"), /*#__PURE__*/React.createElement("span", {
    className: "material-icons",
    style: {
      fontSize: 15
    }
  }, "battery_full"))), children);
}
function AppBar({
  title,
  actions,
  onBack
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 8,
      padding: "10px 16px",
      flexShrink: 0
    }
  }, onBack ? /*#__PURE__*/React.createElement("button", {
    onClick: onBack,
    style: {
      background: "none",
      border: "none",
      cursor: "pointer",
      padding: 6,
      display: "grid",
      placeItems: "center",
      color: "var(--ink)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-icons",
    style: {
      fontSize: 22
    }
  }, "arrow_back")) : null, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      fontSize: 20,
      fontWeight: 800,
      letterSpacing: "-0.6px"
    }
  }, title), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 8
    }
  }, actions));
}
function StatusHero({
  label,
  description,
  icon,
  searching
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      paddingTop: 16
    }
  }, /*#__PURE__*/React.createElement(MorphingBlob, {
    size: 180
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 72,
      height: 72,
      background: "#fff",
      borderRadius: "50%",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-icons",
    style: {
      fontSize: 32,
      color: "var(--raspberry)"
    }
  }, icon))), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 22
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 6
    }
  }, searching ? /*#__PURE__*/React.createElement(PulsingDot, null) : null, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 26,
      fontWeight: 800,
      letterSpacing: "-0.78px"
    }
  }, label)), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 8
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "0 24px",
      textAlign: "center",
      fontSize: 14,
      fontWeight: 500,
      color: "var(--muted)",
      lineHeight: 1.3
    }
  }, description));
}
function SetupBanner({
  label,
  onClick
}) {
  return /*#__PURE__*/React.createElement(PressableScale, null, /*#__PURE__*/React.createElement("div", {
    onClick: onClick,
    style: {
      background: "var(--petal)",
      borderRadius: 20,
      padding: "14px 16px",
      display: "flex",
      alignItems: "center",
      gap: 10,
      cursor: "pointer"
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-icons",
    style: {
      fontSize: 20,
      color: "var(--raspberry)"
    }
  }, "tune"), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      fontSize: 14,
      fontWeight: 600
    }
  }, label), /*#__PURE__*/React.createElement("span", {
    className: "material-icons",
    style: {
      fontSize: 20,
      color: "var(--raspberry)"
    }
  }, "chevron_right")));
}
function ShareStatusCard({
  message
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--mist)",
      borderRadius: 20,
      padding: 14,
      display: "flex",
      alignItems: "center",
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 38,
      height: 38,
      background: "var(--petal)",
      borderRadius: "50%",
      display: "grid",
      placeItems: "center",
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-icons",
    style: {
      fontSize: 18,
      color: "var(--raspberry)"
    }
  }, "ios_share")), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      fontSize: 14,
      fontWeight: 500,
      lineHeight: 1.3
    }
  }, message));
}
function StepDots({
  count,
  index
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "center",
      gap: 8
    }
  }, Array.from({
    length: count
  }, (_, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      width: i === index ? 22 : 8,
      height: 8,
      borderRadius: 999,
      background: i === index ? "var(--raspberry)" : "var(--petal)",
      transition: "width 250ms var(--ease-out-cubic, ease-out)"
    }
  })));
}
function ChecklistRow({
  ok,
  title,
  detail,
  actionLabel,
  onAction,
  index
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--mist)",
      borderRadius: 20,
      padding: "14px 16px",
      display: "flex",
      gap: 12,
      alignItems: "flex-start",
      marginBottom: 12
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-icons",
    style: {
      fontSize: 22,
      color: ok ? "var(--raspberry)" : "var(--error)",
      flexShrink: 0
    }
  }, ok ? "check_circle" : "warning_amber"), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      fontWeight: 600
    }
  }, title), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      fontWeight: 500,
      color: "var(--muted)",
      marginTop: 2,
      lineHeight: 1.3
    }
  }, detail), actionLabel ? /*#__PURE__*/React.createElement("button", {
    onClick: onAction,
    style: {
      background: "none",
      border: "none",
      padding: "8px 0 0",
      fontFamily: "var(--font-sans)",
      fontSize: 14,
      fontWeight: 600,
      color: "var(--raspberry)",
      cursor: "pointer"
    }
  }, actionLabel) : null));
}
Object.assign(window, {
  PhoneFrame,
  AppBar,
  StatusHero,
  SetupBanner,
  ShareStatusCard,
  StepDots,
  ChecklistRow
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/android/AppChrome.jsx", error: String((e && e.message) || e) }); }

// ui_kits/android/AppScreens.jsx
try { (() => {
// Home / Settings / Setup status / Send clipboard / Debug log screens.
// Recreations of main.dart, settings_screen.dart, setup_checklist_screen.dart,
// send_clipboard_screen.dart, debug_log_screen.dart.
const DS3 = window.ImageSyncDesignSystem_5c35fc;
function HomeScreen({
  paired,
  onPair,
  onReset,
  onOpenSettings,
  onOpenDebug,
  onOpenChecklist,
  shareStatus
}) {
  const {
    IconButton,
    PressableScale,
    Button,
    Entrance,
    NearbyRelaysCard,
    ManualPairingForm
  } = DS3;
  const [host, setHost] = React.useState("");
  const [port, setPort] = React.useState("17321");
  const [secret, setSecret] = React.useState("");
  const [selected, setSelected] = React.useState(null);
  const relays = [{
    name: "imagesync-relay",
    host: "192.168.1.4",
    port: 17321
  }];
  return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(window.AppBar, {
    title: "ImageSync",
    actions: /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(PressableScale, null, /*#__PURE__*/React.createElement(IconButton, {
      icon: "bug_report",
      title: "Debug log",
      onClick: onOpenDebug
    })), /*#__PURE__*/React.createElement(PressableScale, null, /*#__PURE__*/React.createElement(IconButton, {
      icon: "settings",
      title: "Settings",
      onClick: onOpenSettings
    })), paired ? /*#__PURE__*/React.createElement(PressableScale, null, /*#__PURE__*/React.createElement(IconButton, {
      icon: "link_off",
      title: "Reset pairing",
      onClick: onReset
    })) : null)
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: "auto",
      padding: 20,
      minHeight: 0
    }
  }, /*#__PURE__*/React.createElement(Entrance, {
    index: 0
  }, /*#__PURE__*/React.createElement(window.StatusHero, {
    label: paired ? "Connected" : "Unpaired",
    icon: paired ? "link" : "qr_code_scanner",
    searching: false,
    description: paired ? "Paired with 192.168.1.4:17321." : "Pair with the laptop relay to join the clipboard pool."
  })), !paired ? /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", {
    style: {
      height: 16
    }
  }), /*#__PURE__*/React.createElement(Entrance, {
    index: 1
  }, /*#__PURE__*/React.createElement(window.SetupBanner, {
    label: "Finish setup",
    onClick: onOpenChecklist
  }))) : null, shareStatus ? /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", {
    style: {
      height: 12
    }
  }), /*#__PURE__*/React.createElement(Entrance, {
    index: 1
  }, /*#__PURE__*/React.createElement(window.ShareStatusCard, {
    message: shareStatus
  }))) : null, /*#__PURE__*/React.createElement("div", {
    style: {
      height: 28
    }
  }), paired ? /*#__PURE__*/React.createElement(Entrance, {
    index: 2
  }, /*#__PURE__*/React.createElement(PressableScale, null, /*#__PURE__*/React.createElement(Button, {
    icon: "link_off",
    onClick: onReset
  }, "Reset pairing"))) : /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Entrance, {
    index: 2
  }, /*#__PURE__*/React.createElement(NearbyRelaysCard, {
    relays: relays,
    selected: selected,
    discovering: false,
    onRefresh: () => {},
    onSelect: r => {
      setSelected(r);
      setHost(r.host);
      setPort(String(r.port));
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 28
    }
  }), /*#__PURE__*/React.createElement(Entrance, {
    index: 3
  }, /*#__PURE__*/React.createElement(ManualPairingForm, {
    host: host,
    port: port,
    secret: secret,
    onHostChange: setHost,
    onPortChange: setPort,
    onSecretChange: setSecret,
    error: null,
    onPair: onPair,
    onScanQr: onPair
  })))));
}
function SettingsScreen({
  onBack,
  onOpenChecklist,
  issueCount
}) {
  const {
    Card,
    Switch,
    Entrance
  } = DS3;
  const [autoSend, setAutoSend] = React.useState(true);
  const [notify, setNotify] = React.useState(true);
  const [background, setBackground] = React.useState(true);
  const SwitchCard = ({
    title,
    subtitle,
    checked,
    onChange,
    index
  }) => /*#__PURE__*/React.createElement(Entrance, {
    index: index
  }, /*#__PURE__*/React.createElement(Card, {
    padding: "12px 12px 12px 20px",
    style: {
      display: "flex",
      alignItems: "center",
      gap: 12,
      marginBottom: 14
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 16,
      fontWeight: 500
    }
  }, title), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      fontWeight: 500,
      color: "var(--muted)",
      marginTop: 4,
      lineHeight: 1.3
    }
  }, subtitle)), /*#__PURE__*/React.createElement(Switch, {
    checked: checked,
    onChange: onChange
  })));
  return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(window.AppBar, {
    title: "Settings",
    onBack: onBack
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: "auto",
      padding: 20,
      minHeight: 0
    }
  }, /*#__PURE__*/React.createElement(SwitchCard, {
    index: 0,
    title: "Auto-send screenshots",
    subtitle: "Push new screenshots to the laptop as you take them. Needs full photos access.",
    checked: autoSend,
    onChange: setAutoSend
  }), /*#__PURE__*/React.createElement(Entrance, {
    index: 1
  }, /*#__PURE__*/React.createElement(Card, {
    padding: "14px 16px 14px 20px",
    onClick: onOpenChecklist,
    style: {
      display: "flex",
      alignItems: "center",
      gap: 12,
      marginBottom: 14
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 16,
      fontWeight: 500
    }
  }, "Setup status"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      fontWeight: 500,
      color: "var(--muted)",
      marginTop: 4
    }
  }, "Permissions, battery, and Xiaomi switches.")), issueCount === 0 ? /*#__PURE__*/React.createElement("span", {
    className: "material-icons",
    style: {
      color: "var(--raspberry)",
      fontSize: 24
    }
  }, "check_circle") : /*#__PURE__*/React.createElement("span", {
    style: {
      background: "var(--petal)",
      borderRadius: 999,
      padding: "4px 10px",
      fontSize: 12,
      fontWeight: 600,
      color: "var(--raspberry)"
    }
  }, issueCount === 1 ? "1 issue" : `${issueCount} issues`))), /*#__PURE__*/React.createElement(SwitchCard, {
    index: 2,
    title: "Notify when laptop payloads arrive",
    subtitle: "Show a receipt when something arrives from the laptop. Delivery-failure notices always show.",
    checked: notify,
    onChange: setNotify
  }), /*#__PURE__*/React.createElement(SwitchCard, {
    index: 3,
    title: "Background sync",
    subtitle: "Keeps the laptop link alive for clipboard, screenshots, and receive \u2014 shows a persistent notification. Off stops all syncing.",
    checked: background,
    onChange: setBackground
  }), /*#__PURE__*/React.createElement(Entrance, {
    index: 4
  }, /*#__PURE__*/React.createElement(Card, {
    padding: "14px 16px 14px 20px",
    style: {
      display: "flex",
      alignItems: "center",
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 16,
      fontWeight: 500
    }
  }, "Advanced"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      fontWeight: 500,
      color: "var(--muted)",
      marginTop: 4,
      lineHeight: 1.3
    }
  }, "Clipboard auto-send for text \u2014 one-time computer setup, not for every phone.")), /*#__PURE__*/React.createElement("span", {
    className: "material-icons",
    style: {
      color: "var(--muted)",
      fontSize: 22
    }
  }, "chevron_right")))));
}
function SetupChecklistScreen({
  onBack,
  allOk
}) {
  const {
    Entrance
  } = DS3;
  return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(window.AppBar, {
    title: "Setup status",
    onBack: onBack
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: "auto",
      padding: 20,
      minHeight: 0
    }
  }, /*#__PURE__*/React.createElement(Entrance, {
    index: 0
  }, /*#__PURE__*/React.createElement(window.ChecklistRow, {
    ok: true,
    title: "Notifications",
    detail: "Receipts and the sync notification can show."
  })), /*#__PURE__*/React.createElement(Entrance, {
    index: 1
  }, /*#__PURE__*/React.createElement(window.ChecklistRow, {
    ok: allOk,
    title: "Photos access",
    detail: allOk ? "Full access — screenshots send themselves." : "Only selected photos — switch to 'Allow all' so new screenshots are visible.",
    actionLabel: allOk ? null : "Open settings"
  })), /*#__PURE__*/React.createElement(Entrance, {
    index: 2
  }, /*#__PURE__*/React.createElement(window.ChecklistRow, {
    ok: true,
    title: "Battery exemption",
    detail: "ImageSync stays connected while the phone sleeps."
  })), /*#__PURE__*/React.createElement(Entrance, {
    index: 3
  }, /*#__PURE__*/React.createElement(window.ChecklistRow, {
    ok: allOk,
    title: "Paired with laptop",
    detail: allOk ? "Pairing saved." : "Pair from the home screen to start syncing."
  }))));
}
function SendClipboardScreen({
  onBack
}) {
  const {
    MorphingBlob,
    RippleRings,
    Entrance
  } = DS3;
  const [state, setState] = React.useState("working");
  React.useEffect(() => {
    const t = setTimeout(() => setState("sent"), 1400);
    return () => clearTimeout(t);
  }, []);
  return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(window.AppBar, {
    title: "Send clipboard",
    onBack: onBack
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: "grid",
      placeItems: "center",
      padding: 24
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      justifyItems: "center",
      gap: 24
    }
  }, state === "working" ? /*#__PURE__*/React.createElement("div", {
    style: {
      width: 160,
      height: 160,
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 44,
      height: 44,
      borderRadius: "50%",
      border: "4px solid var(--petal)",
      borderTopColor: "var(--raspberry)",
      animation: "is-spin 1s linear infinite"
    }
  }), /*#__PURE__*/React.createElement("style", null, `@keyframes is-spin { to { transform: rotate(360deg); } }`)) : /*#__PURE__*/React.createElement(RippleRings, {
    size: 160
  }, /*#__PURE__*/React.createElement(MorphingBlob, {
    size: 104
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 44,
      height: 44,
      background: "#fff",
      borderRadius: "50%",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-icons",
    style: {
      fontSize: 24,
      color: "var(--raspberry)"
    }
  }, "check")))), /*#__PURE__*/React.createElement(Entrance, {
    index: 0,
    key: state
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 16,
      fontWeight: 600,
      textAlign: "center"
    }
  }, state === "working" ? "Reading clipboard..." : "Clipboard sent to laptop.")))));
}
const debugEntries = [{
  time: "12:04:31",
  category: "connection",
  message: "Status: connected",
  error: false
}, {
  time: "12:04:28",
  category: "send",
  message: "Clipboard text (214 chars) sent to laptop.",
  error: false
}, {
  time: "12:03:52",
  category: "receive",
  message: "image (1.2 MB) from laptop — Copied to clipboard.",
  error: false
}, {
  time: "12:01:10",
  category: "connection",
  message: "Status: offline",
  error: true
}, {
  time: "12:01:02",
  category: "service",
  message: "Foreground service started.",
  error: false
}];
function DebugLogScreen({
  onBack
}) {
  const {
    IconButton,
    PressableScale
  } = DS3;
  return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(window.AppBar, {
    title: "Debug log",
    onBack: onBack,
    actions: /*#__PURE__*/React.createElement(PressableScale, null, /*#__PURE__*/React.createElement(IconButton, {
      icon: "delete_sweep",
      title: "Clear log"
    }))
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: "auto",
      padding: "8px 0",
      minHeight: 0
    }
  }, debugEntries.map((e, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      display: "flex",
      gap: 10,
      padding: "6px 16px",
      alignItems: "flex-start"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 12,
      fontWeight: 600,
      color: "var(--muted)",
      fontVariantNumeric: "tabular-nums"
    }
  }, e.time), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      fontWeight: 600,
      color: e.error ? "var(--error)" : "var(--raspberry)"
    }
  }, e.category), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      fontWeight: 500,
      lineHeight: 1.3,
      color: e.error ? "var(--error)" : "var(--ink)"
    }
  }, e.message))))));
}
Object.assign(window, {
  HomeScreen,
  SettingsScreen,
  SetupChecklistScreen,
  SendClipboardScreen,
  DebugLogScreen
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/android/AppScreens.jsx", error: String((e && e.message) || e) }); }

// ui_kits/android/OnboardingScreens.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
// Onboarding wizard screens — from onboarding_wizard.dart (copy verbatim, D7).
const DS2 = window.ImageSyncDesignSystem_5c35fc;
function StepScaffold({
  icon,
  title,
  body,
  consequence,
  primaryLabel,
  onPrimary,
  onSkip,
  stepIndex,
  stepCount
}) {
  const {
    MorphingBlob,
    PressableScale,
    Button,
    Entrance
  } = DS2;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: "flex",
      flexDirection: "column",
      padding: "16px 24px 24px",
      minHeight: 0
    }
  }, /*#__PURE__*/React.createElement(window.StepDots, {
    count: stepCount,
    index: stepIndex
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement(Entrance, {
    index: 0
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement(MorphingBlob, {
    size: 150
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 64,
      height: 64,
      background: "#fff",
      borderRadius: "50%",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-icons-outlined",
    style: {
      fontSize: 28,
      color: "var(--raspberry)"
    }
  }, icon))))), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 28
    }
  }), /*#__PURE__*/React.createElement(Entrance, {
    index: 1
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: "center",
      fontSize: 26,
      fontWeight: 800,
      letterSpacing: "-0.78px"
    }
  }, title)), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 12
    }
  }), /*#__PURE__*/React.createElement(Entrance, {
    index: 2
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: "center",
      fontSize: 14,
      fontWeight: 500,
      color: "var(--muted)",
      lineHeight: 1.3
    }
  }, body)), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement(Entrance, {
    index: 3
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: "center",
      fontSize: 12,
      fontWeight: 500,
      color: "var(--muted)",
      lineHeight: 1.3
    }
  }, "If you skip: ", consequence)), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 14
    }
  }), /*#__PURE__*/React.createElement(Entrance, {
    index: 4
  }, /*#__PURE__*/React.createElement(PressableScale, null, /*#__PURE__*/React.createElement(Button, {
    onClick: onPrimary
  }, primaryLabel))), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 6
    }
  }), /*#__PURE__*/React.createElement(Entrance, {
    index: 5
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "text",
    muted: true,
    fullWidth: false,
    onClick: onSkip
  }, "Skip"))));
}
const wizardSteps = [{
  icon: "notifications_active",
  title: "Stay in the loop",
  body: "ImageSync shows a small ongoing notification while sync runs, and a quiet receipt when something arrives from your laptop.",
  consequence: "You won't see receipts when the laptop sends you things.",
  primaryLabel: "Allow"
}, {
  icon: "photo_library",
  title: "Spot your screenshots",
  body: "To send screenshots automatically, ImageSync needs access to all photos. Pick Allow all — with 'Select photos' it can't see new screenshots.",
  consequence: "Screenshots won't send themselves — you can still share manually.",
  primaryLabel: "Allow access"
}, {
  icon: "battery_charging_full",
  title: "Keep the link alive",
  body: "Android puts idle apps to sleep, which drops the connection to your laptop. Allow ImageSync to ignore battery optimizations so payloads arrive even when the screen is off.",
  consequence: "Sync may pause when the phone sleeps.",
  primaryLabel: "Allow"
}];
function PairingFinale({
  paired,
  connected,
  onPair,
  onDone,
  stepCount
}) {
  const {
    MorphingBlob,
    RippleRings,
    PressableScale,
    Button,
    Entrance,
    NearbyRelaysCard,
    ManualPairingForm
  } = DS2;
  const [host, setHost] = React.useState("");
  const [port, setPort] = React.useState("17321");
  const [secret, setSecret] = React.useState("");
  const [selected, setSelected] = React.useState(null);
  const relays = [{
    name: "imagesync-relay",
    host: "192.168.1.4",
    port: 17321
  }];
  if (paired) {
    return /*#__PURE__*/React.createElement("div", {
      style: {
        flex: 1,
        display: "flex",
        flexDirection: "column",
        justifyContent: "center",
        padding: "16px 24px 24px"
      }
    }, /*#__PURE__*/React.createElement(Entrance, {
      index: 0
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        display: "grid",
        placeItems: "center"
      }
    }, /*#__PURE__*/React.createElement(RippleRings, {
      size: 160
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        width: 72,
        height: 72,
        background: "var(--raspberry)",
        borderRadius: "50%",
        display: "grid",
        placeItems: "center"
      }
    }, /*#__PURE__*/React.createElement("span", {
      className: "material-icons",
      style: {
        fontSize: 32,
        color: "#fff"
      }
    }, connected ? "link" : "wifi_find"))))), /*#__PURE__*/React.createElement("div", {
      style: {
        height: 24
      }
    }), /*#__PURE__*/React.createElement(Entrance, {
      index: 1
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        textAlign: "center",
        fontSize: 26,
        fontWeight: 800,
        letterSpacing: "-0.78px"
      }
    }, connected ? "Connected" : "Connecting…")), /*#__PURE__*/React.createElement("div", {
      style: {
        height: 8
      }
    }), /*#__PURE__*/React.createElement(Entrance, {
      index: 2
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        textAlign: "center",
        fontSize: 14,
        fontWeight: 500,
        color: "var(--muted)"
      }
    }, connected ? "Your laptop and phone are in sync." : "Paired — waiting for the relay.")), /*#__PURE__*/React.createElement("div", {
      style: {
        height: 32
      }
    }), /*#__PURE__*/React.createElement(Entrance, {
      index: 3
    }, /*#__PURE__*/React.createElement(PressableScale, null, /*#__PURE__*/React.createElement(Button, {
      onClick: onDone
    }, "Done"))));
  }
  return /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: "auto",
      padding: "16px 24px 24px",
      minHeight: 0
    }
  }, /*#__PURE__*/React.createElement(window.StepDots, {
    count: stepCount,
    index: stepCount - 1
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 24
    }
  }), /*#__PURE__*/React.createElement(Entrance, {
    index: 0
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 26,
      fontWeight: 800,
      letterSpacing: "-0.78px"
    }
  }, "Connect to your laptop")), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 10
    }
  }), /*#__PURE__*/React.createElement(Entrance, {
    index: 1
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      fontWeight: 500,
      color: "var(--muted)",
      lineHeight: 1.3
    }
  }, "Run the relay on your laptop, then pick it below or scan its QR code.")), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 20
    }
  }), /*#__PURE__*/React.createElement(Entrance, {
    index: 2
  }, /*#__PURE__*/React.createElement(NearbyRelaysCard, {
    relays: relays,
    selected: selected,
    discovering: false,
    onRefresh: () => {},
    onSelect: r => {
      setSelected(r);
      setHost(r.host);
      setPort(String(r.port));
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 24
    }
  }), /*#__PURE__*/React.createElement(Entrance, {
    index: 3
  }, /*#__PURE__*/React.createElement(ManualPairingForm, {
    host: host,
    port: port,
    secret: secret,
    onHostChange: setHost,
    onPortChange: setPort,
    onSecretChange: setSecret,
    error: null,
    onPair: onPair,
    onScanQr: onPair
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 12
    }
  }), /*#__PURE__*/React.createElement(Entrance, {
    index: 4
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "text",
    fullWidth: false,
    onClick: onDone
  }, "Skip for now"))));
}
function OnboardingFlow({
  onFinish
}) {
  const [step, setStep] = React.useState(0);
  const [paired, setPaired] = React.useState(false);
  const stepCount = 4;
  const next = () => setStep(s => s + 1);
  if (step < 3) {
    const s = wizardSteps[step];
    return /*#__PURE__*/React.createElement(StepScaffold, _extends({
      key: step
    }, s, {
      stepIndex: step,
      stepCount: stepCount,
      onPrimary: next,
      onSkip: next
    }));
  }
  return /*#__PURE__*/React.createElement(PairingFinale, {
    paired: paired,
    connected: true,
    stepCount: stepCount,
    onPair: () => setPaired(true),
    onDone: onFinish
  });
}
Object.assign(window, {
  OnboardingFlow
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/android/OnboardingScreens.jsx", error: String((e && e.message) || e) }); }

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.IconButton = __ds_scope.IconButton;

__ds_ns.MIcon = __ds_scope.MIcon;

__ds_ns.Snackbar = __ds_scope.Snackbar;

__ds_ns.Switch = __ds_scope.Switch;

__ds_ns.TextField = __ds_scope.TextField;

__ds_ns.Entrance = __ds_scope.Entrance;

__ds_ns.MorphingBlob = __ds_scope.MorphingBlob;

__ds_ns.PressableScale = __ds_scope.PressableScale;

__ds_ns.PulsingDot = __ds_scope.PulsingDot;

__ds_ns.RippleRings = __ds_scope.RippleRings;

__ds_ns.ManualPairingForm = __ds_scope.ManualPairingForm;

__ds_ns.NearbyRelaysCard = __ds_scope.NearbyRelaysCard;

})();
