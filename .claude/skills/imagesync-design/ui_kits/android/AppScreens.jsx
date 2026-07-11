// Home / Settings / Setup status / Send clipboard / Debug log screens.
// Recreations of main.dart, settings_screen.dart, setup_checklist_screen.dart,
// send_clipboard_screen.dart, debug_log_screen.dart.
const DS3 = window.ImageSyncDesignSystem_5c35fc;

function HomeScreen({ paired, onPair, onReset, onOpenSettings, onOpenDebug, onOpenChecklist, shareStatus }) {
  const { IconButton, PressableScale, Button, Entrance, NearbyRelaysCard, ManualPairingForm } = DS3;
  const [host, setHost] = React.useState("");
  const [port, setPort] = React.useState("17321");
  const [secret, setSecret] = React.useState("");
  const [selected, setSelected] = React.useState(null);
  const relays = [{ name: "imagesync-relay", host: "192.168.1.4", port: 17321 }];

  return (
    <React.Fragment>
      <window.AppBar
        title="ImageSync"
        actions={
          <React.Fragment>
            <PressableScale><IconButton icon="bug_report" title="Debug log" onClick={onOpenDebug} /></PressableScale>
            <PressableScale><IconButton icon="settings" title="Settings" onClick={onOpenSettings} /></PressableScale>
            {paired ? <PressableScale><IconButton icon="link_off" title="Reset pairing" onClick={onReset} /></PressableScale> : null}
          </React.Fragment>
        }
      />
      <div style={{ flex: 1, overflowY: "auto", padding: 20, minHeight: 0 }}>
        <Entrance index={0}>
          <window.StatusHero
            label={paired ? "Connected" : "Unpaired"}
            icon={paired ? "link" : "qr_code_scanner"}
            searching={false}
            description={
              paired
                ? "Paired with 192.168.1.4:17321."
                : "Pair with the laptop relay to join the clipboard pool."
            }
          />
        </Entrance>
        {!paired ? (
          <React.Fragment>
            <div style={{ height: 16 }}></div>
            <Entrance index={1}>
              <window.SetupBanner label="Finish setup" onClick={onOpenChecklist} />
            </Entrance>
          </React.Fragment>
        ) : null}
        {shareStatus ? (
          <React.Fragment>
            <div style={{ height: 12 }}></div>
            <Entrance index={1}><window.ShareStatusCard message={shareStatus} /></Entrance>
          </React.Fragment>
        ) : null}
        <div style={{ height: 28 }}></div>
        {paired ? (
          <Entrance index={2}>
            <PressableScale><Button icon="link_off" onClick={onReset}>Reset pairing</Button></PressableScale>
          </Entrance>
        ) : (
          <React.Fragment>
            <Entrance index={2}>
              <NearbyRelaysCard
                relays={relays}
                selected={selected}
                discovering={false}
                onRefresh={() => {}}
                onSelect={(r) => { setSelected(r); setHost(r.host); setPort(String(r.port)); }}
              />
            </Entrance>
            <div style={{ height: 28 }}></div>
            <Entrance index={3}>
              <ManualPairingForm
                host={host} port={port} secret={secret}
                onHostChange={setHost} onPortChange={setPort} onSecretChange={setSecret}
                error={null} onPair={onPair} onScanQr={onPair}
              />
            </Entrance>
          </React.Fragment>
        )}
      </div>
    </React.Fragment>
  );
}

function SettingsScreen({ onBack, onOpenChecklist, issueCount }) {
  const { Card, Switch, Entrance } = DS3;
  const [autoSend, setAutoSend] = React.useState(true);
  const [notify, setNotify] = React.useState(true);
  const [background, setBackground] = React.useState(true);

  const SwitchCard = ({ title, subtitle, checked, onChange, index }) => (
    <Entrance index={index}>
      <Card padding="12px 12px 12px 20px" style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 14 }}>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 16, fontWeight: 500 }}>{title}</div>
          <div style={{ fontSize: 14, fontWeight: 500, color: "var(--muted)", marginTop: 4, lineHeight: 1.3 }}>{subtitle}</div>
        </div>
        <Switch checked={checked} onChange={onChange} />
      </Card>
    </Entrance>
  );

  return (
    <React.Fragment>
      <window.AppBar title="Settings" onBack={onBack} />
      <div style={{ flex: 1, overflowY: "auto", padding: 20, minHeight: 0 }}>
        <SwitchCard
          index={0}
          title="Auto-send screenshots"
          subtitle="Push new screenshots to the laptop as you take them. Needs full photos access."
          checked={autoSend} onChange={setAutoSend}
        />
        <Entrance index={1}>
          <Card padding="14px 16px 14px 20px" onClick={onOpenChecklist} style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 14 }}>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 16, fontWeight: 500 }}>Setup status</div>
              <div style={{ fontSize: 14, fontWeight: 500, color: "var(--muted)", marginTop: 4 }}>Permissions, battery, and Xiaomi switches.</div>
            </div>
            {issueCount === 0 ? (
              <span className="material-icons" style={{ color: "var(--raspberry)", fontSize: 24 }}>check_circle</span>
            ) : (
              <span style={{ background: "var(--petal)", borderRadius: 999, padding: "4px 10px", fontSize: 12, fontWeight: 600, color: "var(--raspberry)" }}>
                {issueCount === 1 ? "1 issue" : `${issueCount} issues`}
              </span>
            )}
          </Card>
        </Entrance>
        <SwitchCard
          index={2}
          title="Notify when laptop payloads arrive"
          subtitle="Show a receipt when something arrives from the laptop. Delivery-failure notices always show."
          checked={notify} onChange={setNotify}
        />
        <SwitchCard
          index={3}
          title="Background sync"
          subtitle="Keeps the laptop link alive for clipboard, screenshots, and receive — shows a persistent notification. Off stops all syncing."
          checked={background} onChange={setBackground}
        />
        <Entrance index={4}>
          <Card padding="14px 16px 14px 20px" style={{ display: "flex", alignItems: "center", gap: 12 }}>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 16, fontWeight: 500 }}>Advanced</div>
              <div style={{ fontSize: 14, fontWeight: 500, color: "var(--muted)", marginTop: 4, lineHeight: 1.3 }}>
                Clipboard auto-send for text — one-time computer setup, not for every phone.
              </div>
            </div>
            <span className="material-icons" style={{ color: "var(--muted)", fontSize: 22 }}>chevron_right</span>
          </Card>
        </Entrance>
      </div>
    </React.Fragment>
  );
}

function SetupChecklistScreen({ onBack, allOk }) {
  const { Entrance } = DS3;
  return (
    <React.Fragment>
      <window.AppBar title="Setup status" onBack={onBack} />
      <div style={{ flex: 1, overflowY: "auto", padding: 20, minHeight: 0 }}>
        <Entrance index={0}>
          <window.ChecklistRow ok title="Notifications" detail="Receipts and the sync notification can show." />
        </Entrance>
        <Entrance index={1}>
          <window.ChecklistRow
            ok={allOk}
            title="Photos access"
            detail={allOk ? "Full access — screenshots send themselves." : "Only selected photos — switch to 'Allow all' so new screenshots are visible."}
            actionLabel={allOk ? null : "Open settings"}
          />
        </Entrance>
        <Entrance index={2}>
          <window.ChecklistRow ok title="Battery exemption" detail="ImageSync stays connected while the phone sleeps." />
        </Entrance>
        <Entrance index={3}>
          <window.ChecklistRow
            ok={allOk}
            title="Paired with laptop"
            detail={allOk ? "Pairing saved." : "Pair from the home screen to start syncing."}
          />
        </Entrance>
      </div>
    </React.Fragment>
  );
}

function SendClipboardScreen({ onBack }) {
  const { MorphingBlob, RippleRings, Entrance } = DS3;
  const [state, setState] = React.useState("working");
  React.useEffect(() => {
    const t = setTimeout(() => setState("sent"), 1400);
    return () => clearTimeout(t);
  }, []);
  return (
    <React.Fragment>
      <window.AppBar title="Send clipboard" onBack={onBack} />
      <div style={{ flex: 1, display: "grid", placeItems: "center", padding: 24 }}>
        <div style={{ display: "grid", justifyItems: "center", gap: 24 }}>
          {state === "working" ? (
            <div style={{ width: 160, height: 160, display: "grid", placeItems: "center" }}>
              <div
                style={{
                  width: 44, height: 44, borderRadius: "50%",
                  border: "4px solid var(--petal)", borderTopColor: "var(--raspberry)",
                  animation: "is-spin 1s linear infinite",
                }}
              ></div>
              <style>{`@keyframes is-spin { to { transform: rotate(360deg); } }`}</style>
            </div>
          ) : (
            <RippleRings size={160}>
              <MorphingBlob size={104}>
                <div style={{ width: 44, height: 44, background: "#fff", borderRadius: "50%", display: "grid", placeItems: "center" }}>
                  <span className="material-icons" style={{ fontSize: 24, color: "var(--raspberry)" }}>check</span>
                </div>
              </MorphingBlob>
            </RippleRings>
          )}
          <Entrance index={0} key={state}>
            <div style={{ fontSize: 16, fontWeight: 600, textAlign: "center" }}>
              {state === "working" ? "Reading clipboard..." : "Clipboard sent to laptop."}
            </div>
          </Entrance>
        </div>
      </div>
    </React.Fragment>
  );
}

const debugEntries = [
  { time: "12:04:31", category: "connection", message: "Status: connected", error: false },
  { time: "12:04:28", category: "send", message: "Clipboard text (214 chars) sent to laptop.", error: false },
  { time: "12:03:52", category: "receive", message: "image (1.2 MB) from laptop — Copied to clipboard.", error: false },
  { time: "12:01:10", category: "connection", message: "Status: offline", error: true },
  { time: "12:01:02", category: "service", message: "Foreground service started.", error: false },
];

function DebugLogScreen({ onBack }) {
  const { IconButton, PressableScale } = DS3;
  return (
    <React.Fragment>
      <window.AppBar
        title="Debug log"
        onBack={onBack}
        actions={<PressableScale><IconButton icon="delete_sweep" title="Clear log" /></PressableScale>}
      />
      <div style={{ flex: 1, overflowY: "auto", padding: "8px 0", minHeight: 0 }}>
        {debugEntries.map((e, i) => (
          <div key={i} style={{ display: "flex", gap: 10, padding: "6px 16px", alignItems: "flex-start" }}>
            <span style={{ fontSize: 12, fontWeight: 600, color: "var(--muted)", fontVariantNumeric: "tabular-nums" }}>{e.time}</span>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 12, fontWeight: 600, color: e.error ? "var(--error)" : "var(--raspberry)" }}>{e.category}</div>
              <div style={{ fontSize: 12, fontWeight: 500, lineHeight: 1.3, color: e.error ? "var(--error)" : "var(--ink)" }}>{e.message}</div>
            </div>
          </div>
        ))}
      </div>
    </React.Fragment>
  );
}

Object.assign(window, { HomeScreen, SettingsScreen, SetupChecklistScreen, SendClipboardScreen, DebugLogScreen });
