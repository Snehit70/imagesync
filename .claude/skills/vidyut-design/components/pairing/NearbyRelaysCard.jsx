// Discovery results card — shared by home pairing and the wizard finale.
// Recreation of NearbyRelaysCard in pairing_widgets.dart.
import { PulsingDot } from "../motion/PulsingDot.jsx";

export function NearbyRelaysCard({ relays = [], selected, discovering = false, onRefresh, onSelect }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
      <div style={{ display: "flex", alignItems: "center", gap: 4 }}>
        {discovering ? <PulsingDot size={8} /> : null}
        <div style={{ flex: 1, fontSize: 16, fontWeight: 600, fontFamily: "var(--font-sans)", color: "var(--ink)" }}>
          Nearby relays
        </div>
        {!discovering ? (
          <button
            title="Search again"
            onClick={onRefresh}
            style={{
              width: 40,
              height: 40,
              display: "grid",
              placeItems: "center",
              background: "var(--mist)",
              color: "var(--raspberry)",
              border: "none",
              borderRadius: 12,
              cursor: "pointer",
            }}
          >
            <span className="material-icons" style={{ fontSize: 20 }}>refresh</span>
          </button>
        ) : null}
      </div>
      {relays.length === 0 ? (
        <div style={{ fontSize: 14, fontWeight: 500, color: "var(--muted)", fontFamily: "var(--font-sans)", lineHeight: 1.3 }}>
          {discovering
            ? "Searching for relays on this network…"
            : "No relays found. Make sure the laptop relay is running, or pair manually below."}
        </div>
      ) : (
        relays.map((relay) => (
          <div
            key={`${relay.host}:${relay.port}`}
            onClick={() => onSelect && onSelect(relay)}
            style={{
              background: "var(--mist)",
              borderRadius: 20,
              padding: "10px 16px",
              display: "flex",
              alignItems: "center",
              gap: 14,
              cursor: "pointer",
            }}
          >
            <div
              style={{
                width: 40,
                height: 40,
                background: "var(--petal)",
                borderRadius: 13,
                display: "grid",
                placeItems: "center",
                flexShrink: 0,
              }}
            >
              <span className="material-icons" style={{ fontSize: 20, color: "var(--raspberry)" }}>dns</span>
            </div>
            <div style={{ flex: 1, fontFamily: "var(--font-sans)", lineHeight: 1.3 }}>
              <div style={{ fontSize: 14, fontWeight: 600, color: "var(--ink)" }}>{relay.name}</div>
              <div style={{ fontSize: 12, fontWeight: 500, color: "var(--muted)" }}>
                {relay.host}:{relay.port}
              </div>
            </div>
            {selected && selected.host === relay.host && selected.port === relay.port ? (
              <span className="material-icons" style={{ fontSize: 24, color: "var(--raspberry)" }}>check_circle</span>
            ) : null}
          </div>
        ))
      )}
      {selected ? (
        <div style={{ fontSize: 14, fontWeight: 500, color: "var(--muted)", fontFamily: "var(--font-sans)" }}>
          Enter the pairing secret below and tap Pair manually.
        </div>
      ) : null}
    </div>
  );
}
