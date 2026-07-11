// Manual host/port/secret entry form. Recreation of ManualPairingForm.
import { TextField } from "../core/TextField.jsx";
import { Button } from "../core/Button.jsx";
import { PressableScale } from "../motion/PressableScale.jsx";

export function ManualPairingForm({
  host = "",
  port = "17321",
  secret = "",
  onHostChange,
  onPortChange,
  onSecretChange,
  error,
  onScanQr,
  onPair,
}) {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 12, fontFamily: "var(--font-sans)" }}>
      <div style={{ fontSize: 16, fontWeight: 600, color: "var(--ink)" }}>Manual pairing</div>
      <TextField label="Relay IP" icon="router" value={host} onChange={onHostChange} />
      <TextField label="Port" icon="settings_ethernet" value={port} onChange={onPortChange} />
      <TextField label="Pairing secret" icon="key" type="password" value={secret} onChange={onSecretChange} />
      {error ? (
        <div
          style={{
            background: "var(--mist)",
            borderRadius: 16,
            padding: 12,
            display: "flex",
            alignItems: "center",
            gap: 8,
          }}
        >
          <span className="material-icons-outlined" style={{ fontSize: 18, color: "var(--error)" }}>error_outline</span>
          <div style={{ fontSize: 14, fontWeight: 500, color: "var(--error)", lineHeight: 1.3 }}>{error}</div>
        </div>
      ) : null}
      <div style={{ height: 8 }}></div>
      <PressableScale>
        <Button icon="link" onClick={onPair}>Pair manually</Button>
      </PressableScale>
      <PressableScale>
        <Button variant="outlined" icon="qr_code_scanner" onClick={onScanQr}>Scan QR</Button>
      </PressableScale>
    </div>
  );
}
