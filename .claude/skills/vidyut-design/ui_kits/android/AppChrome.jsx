// Shared chrome for the Vidyut Android UI kit — screen internals from
// main.dart (private widgets: _AppBarAction, _StatusHero, _SetupBanner,
// _ShareStatusCard, _StepDots, _ChecklistRow, _SummaryChip).
const DS = window.VidyutDesignSystem_5c35fc;
const { MorphingBlob, PulsingDot, PressableScale, IconButton } = DS;

function PhoneFrame({ children }) {
  return (
    <div
      style={{
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
        flexShrink: 0,
      }}
    >
      <div
        style={{
          height: 34,
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          padding: "0 22px",
          fontSize: 13,
          fontWeight: 600,
          flexShrink: 0,
        }}
      >
        <span>9:41</span>
        <span style={{ display: "flex", gap: 4, alignItems: "center" }}>
          <span className="material-icons" style={{ fontSize: 15 }}>signal_cellular_alt</span>
          <span className="material-icons" style={{ fontSize: 15 }}>wifi</span>
          <span className="material-icons" style={{ fontSize: 15 }}>battery_full</span>
        </span>
      </div>
      {children}
    </div>
  );
}

function AppBar({ title, actions, onBack }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "10px 16px", flexShrink: 0 }}>
      {onBack ? (
        <button
          onClick={onBack}
          style={{ background: "none", border: "none", cursor: "pointer", padding: 6, display: "grid", placeItems: "center", color: "var(--ink)" }}
        >
          <span className="material-icons" style={{ fontSize: 22 }}>arrow_back</span>
        </button>
      ) : null}
      <div style={{ flex: 1, fontSize: 20, fontWeight: 800, letterSpacing: "-0.6px" }}>{title}</div>
      <div style={{ display: "flex", gap: 8 }}>{actions}</div>
    </div>
  );
}

function StatusHero({ label, description, icon, searching }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", paddingTop: 16 }}>
      <MorphingBlob size={180}>
        <div style={{ width: 72, height: 72, background: "#fff", borderRadius: "50%", display: "grid", placeItems: "center" }}>
          <span className="material-icons" style={{ fontSize: 32, color: "var(--raspberry)" }}>{icon}</span>
        </div>
      </MorphingBlob>
      <div style={{ height: 22 }}></div>
      <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
        {searching ? <PulsingDot /> : null}
        <span style={{ fontSize: 26, fontWeight: 800, letterSpacing: "-0.78px" }}>{label}</span>
      </div>
      <div style={{ height: 8 }}></div>
      <div style={{ padding: "0 24px", textAlign: "center", fontSize: 14, fontWeight: 500, color: "var(--muted)", lineHeight: 1.3 }}>
        {description}
      </div>
    </div>
  );
}

function SetupBanner({ label, onClick }) {
  return (
    <PressableScale>
      <div
        onClick={onClick}
        style={{
          background: "var(--petal)",
          borderRadius: 20,
          padding: "14px 16px",
          display: "flex",
          alignItems: "center",
          gap: 10,
          cursor: "pointer",
        }}
      >
        <span className="material-icons" style={{ fontSize: 20, color: "var(--raspberry)" }}>tune</span>
        <div style={{ flex: 1, fontSize: 14, fontWeight: 600 }}>{label}</div>
        <span className="material-icons" style={{ fontSize: 20, color: "var(--raspberry)" }}>chevron_right</span>
      </div>
    </PressableScale>
  );
}

function ShareStatusCard({ message }) {
  return (
    <div style={{ background: "var(--mist)", borderRadius: 20, padding: 14, display: "flex", alignItems: "center", gap: 12 }}>
      <div style={{ width: 38, height: 38, background: "var(--petal)", borderRadius: "50%", display: "grid", placeItems: "center", flexShrink: 0 }}>
        <span className="material-icons" style={{ fontSize: 18, color: "var(--raspberry)" }}>ios_share</span>
      </div>
      <div style={{ flex: 1, fontSize: 14, fontWeight: 500, lineHeight: 1.3 }}>{message}</div>
    </div>
  );
}

function StepDots({ count, index }) {
  return (
    <div style={{ display: "flex", justifyContent: "center", gap: 8 }}>
      {Array.from({ length: count }, (_, i) => (
        <div
          key={i}
          style={{
            width: i === index ? 22 : 8,
            height: 8,
            borderRadius: 999,
            background: i === index ? "var(--raspberry)" : "var(--petal)",
            transition: "width 250ms var(--ease-out-cubic, ease-out)",
          }}
        ></div>
      ))}
    </div>
  );
}

function ChecklistRow({ ok, title, detail, actionLabel, onAction, index }) {
  return (
    <div style={{ background: "var(--mist)", borderRadius: 20, padding: "14px 16px", display: "flex", gap: 12, alignItems: "flex-start", marginBottom: 12 }}>
      <span
        className="material-icons"
        style={{ fontSize: 22, color: ok ? "var(--raspberry)" : "var(--error)", flexShrink: 0 }}
      >
        {ok ? "check_circle" : "warning_amber"}
      </span>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 14, fontWeight: 600 }}>{title}</div>
        <div style={{ fontSize: 12, fontWeight: 500, color: "var(--muted)", marginTop: 2, lineHeight: 1.3 }}>{detail}</div>
        {actionLabel ? (
          <button
            onClick={onAction}
            style={{
              background: "none",
              border: "none",
              padding: "8px 0 0",
              fontFamily: "var(--font-sans)",
              fontSize: 14,
              fontWeight: 600,
              color: "var(--raspberry)",
              cursor: "pointer",
            }}
          >
            {actionLabel}
          </button>
        ) : null}
      </div>
    </div>
  );
}

Object.assign(window, { PhoneFrame, AppBar, StatusHero, SetupBanner, ShareStatusCard, StepDots, ChecklistRow });
